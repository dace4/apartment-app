// US-06/07: real rules, local demo project only, no npm dependencies.
import assert from 'node:assert/strict';
import {test} from 'node:test';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Set a local FIRESTORE_EMULATOR_HOST.');
const project = process.env.US_DOCUMENTS_DEMO_PROJECT ?? 'demo-homeflow-us15';
if (!['demo-homeflow-us15', 'demo-homeflow-us11'].includes(project)) throw Error('Only US-15/11 demo projects are allowed.');
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
const prefix = `test-${Date.now()}`;
function token(uid = 'tenant', verified = true) {
  const encode = data => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({alg:'none',typ:'JWT'})}.${encode({aud:project,iss:`https://securetoken.google.com/${project}`,
    sub:uid,user_id:uid,email:`${uid}@example.test`,email_verified:verified,iat:now,auth_time:now,exp:now+3600,
    firebase:{sign_in_provider:'custom'}})}.`;
}
function value(data) {
  if (data === null) return {nullValue:null};
  if (Buffer.isBuffer(data)) return {bytesValue:data.toString('base64')};
  if (Array.isArray(data)) return {arrayValue:{values:data.map(value)}};
  if (typeof data === 'object' && '$time' in data) return {timestampValue:data.$time};
  if (typeof data === 'string') return {stringValue:data};
  if (typeof data === 'boolean') return {booleanValue:data};
  return {integerValue:String(data)};
}
function write(collection, id, data, times = [], mask) {
  return {update:{name:`${database}/documents/${collection}/${id}`,
    fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]))},
    ...(times.length ? {updateTransforms:times.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {}),
    ...(mask ? {updateMask:{fieldPaths:mask}} : {})};
}
async function request(path, auth, method='GET', body) {
  return fetch(base+path,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:`Bearer ${auth}`}:{})},
    ...(body?{body:JSON.stringify(body)}:{})});
}
async function status(response, expected) {
  const text = await response.text(); assert.equal(response.status,expected,text);
}
const commit = (writes, auth=token()) => request(':commit',auth,'POST',{writes});
function file(overrides={}) {
  return {userId:'tenant',name:'photo.jpg',mimeType:'image/jpeg',fileBytes:Buffer.from([255,216,255,217]),
    byteSize:4,status:'unsigned',signatureId:null,signedAt:null,firstApplicationId:null,...overrides};
}
const upload = (id, data=file(), auth=token()) => commit([write('uploadedDocuments',id,data,['createdAt'])],auth);
function application(ids=[]) {
  return {userId:'tenant',apartmentId:'apt',apartmentTitle:'Test apartment',fullName:'Tenant',phone:'123456789',
    moveInDate:{$time:new Date(Date.now()+86400000*30).toISOString()},occupants:1,message:'',status:'submitted',documentIds:ids};
}
const appWrite = (id, ids) => write('applications',id,application(ids),['submittedAt','updatedAt']);
const firstUse = (id, appId) => write('uploadedDocuments',id,{firstApplicationId:appId},[],['firstApplicationId']);


const admin = writes => commit(writes, 'owner');
const profile = (uid, roles, auth=token(uid)) => commit([write('users',uid,{roles})],auth);
const query = (collection, filters, auth) => request(':runQuery',auth,'POST',{
  structuredQuery:{from:[{collectionId:collection}],where:{compositeFilter:{op:'AND',filters:
    filters.map(([field,op,val])=>({fieldFilter:{field:{fieldPath:field},op,value:value(val)}}))}}}});
const iso = ms => ({$time:new Date(Date.now()+ms).toISOString()});
const maintenanceWindow = (start, end, uid='manager', auth=token(uid)) =>
  commit([write('appConfig','maintenance',{start:iso(start),end:iso(end),updatedBy:uid},['updatedAt'])],auth);

test('US-06/07 roles and property access', async t => {
  await status(await admin([
    write('apartments','managed',{ownerId:'home',managerIds:['manager'],availability:'available'}),
    write('apartments','other',{ownerId:'someone',managerIds:[],availability:'available'}),
    write('apartments','legacy',{availability:'available'}),
    write('apartments','apt',{availability:'available'}),
  ]),200);
  for (const [uid,roles] of [['tenant',['renter']],['home',['homeowner']],
    ['stranger',['homeowner']],['buyer',['buyer']]]) {
    await status(await profile(uid,roles),200);
  }
  // Admin is granted in the console only (here: the emulator's admin token).
  await status(await admin([write('users','manager',{roles:['admin']})]),200);
  await t.test('all 15 valid combinations; only self-editable personas',async()=>{
    const names=['buyer','renter','homeowner'];
    for(let mask=1;mask<8;mask++) {
      await status(await profile('combo',names.filter((_,i)=>mask&(1<<i))),200);
      await status(await request('/apartments/managed',token('combo')),200);
    }
    for(const roles of [[],['admin'],['buyer','admin'],['buyer','buyer'],['propertyManager']]) {
      await status(await profile('combo',roles),403);
    }
    // An admin keeps the role while editing their other roles.
    await status(await profile('manager',['buyer','admin']),200);
    await status(await profile('manager',['admin']),200);
    await status(await profile('home',['renter'],token('tenant')),403);
    await status(await commit([write('users','tenant',{roles:['renter'],ownerId:'tenant'})]),403);
    await status(await request('/users/home',token('tenant')),403);
    await status(await request('/users',token()),403);
    await status(await request('/users/tenant',token(),'DELETE'),403);
  });
  await t.test('US-06 optional name and phone, with the application limits',async()=>{
    const contact=(uid,data,mask)=>commit([write('users',uid,data,[],mask)],token(uid));
    await status(await contact('named',{roles:['renter'],fullName:'Ada Muster',phone:'+41 79 123 45 67'}),200);
    // A profile with a name and phone is still a valid one.
    await status(await request('/apartments/managed',token('named')),200);
    // Saving only the roles keeps the name and phone.
    await status(await contact('named',{roles:['buyer']},['roles']),200);
    const saved=await (await request('/users/named',token('named'))).json();
    assert.equal(saved.fields.fullName.stringValue,'Ada Muster');
    assert.equal(saved.fields.phone.stringValue,'+41 79 123 45 67');
    for(const bad of [{fullName:'   '},{fullName:'A'.repeat(101)},{fullName:7},
      {phone:'call me'},{phone:'123'},{phone:'1'.repeat(21)},{email:'ada@example.test'}]) {
      await status(await contact('named',{roles:['buyer'],...bad}),403);
    }
    await status(await contact('named',{roles:['buyer'],fullName:'A'.repeat(100),phone:'079 123 45 67'}),200);
  });
  await t.test('signed-out, unverified and legacy accounts never enter protected data',async()=>{
    await status(await profile('unverified',['buyer'],token('unverified',false)),200);
    for(const auth of [null,token('unverified',false),token('legacy-user')]) {
      await status(await request('/apartments/managed',auth),403);
      await status(await request('/notifications',auth),403);
    }
    await status(await request('/users/unverified',token('unverified',false)),200);
    // A retired Property Manager profile is invalid until roles are chosen again.
    await status(await admin([write('users','invalid',{roles:['propertyManager']})]),200);
    await status(await request('/apartments/managed',token('invalid')),403);
  });
  await t.test('consumer records require buyer/renter as well as record ownership',async()=>{
    await status(await commit([write('favourites',`${prefix}-tenant_managed`,{
      userId:'tenant',apartmentId:'managed'},['createdAt'])]),200);
    await status(await request(`/favourites/${prefix}-tenant_managed`,token('tenant')),200);
    await status(await request(`/favourites/${prefix}-tenant_managed`,token('buyer')),403);
    await status(await request(`/favourites/${prefix}-tenant_managed`,token('home')),403);
    await status(await upload(`${prefix}-role-upload`),200);
    await status(await request(`/uploadedDocuments/${prefix}-role-upload`,token('home')),403);
    await status(await profile('tenant',['homeowner']),200);
    await status(await request(`/favourites/${prefix}-tenant_managed`,token('tenant')),403);
    await status(await request(`/uploadedDocuments/${prefix}-role-upload`,token('tenant')),403);
    await status(await profile('tenant',['renter']),200);
  });
  await t.test('roles alone never assign properties',async()=>{
    await status(await commit([write('apartments','managed',{ownerId:'tenant'},[],['ownerId'])]),403);
    await status(await commit([write('apartments','managed',{managerIds:['tenant']},[],['managerIds'])]),403);
  });
  await t.test('only admins schedule app maintenance; it locks out everyone else',async()=>{
    const hour=3600000;
    await status(await request('/appConfig/maintenance',null),404); // public, none yet
    await status(await maintenanceWindow(-60000,hour,'home'),403);
    await status(await maintenanceWindow(hour,2*hour,'manager',token('home')),403); // forged updatedBy
    await status(await maintenanceWindow(2*hour,hour),403); // ends before it starts
    await status(await maintenanceWindow(-2*hour,-hour),403); // already over
    await status(await commit([write('appConfig','maintenance',{start:iso(hour),end:iso(2*hour),
      updatedBy:'manager',note:'x'},['updatedAt'])],token('manager')),403);
    // Planned: nobody is locked out yet, and everyone can read it.
    await status(await maintenanceWindow(hour,2*hour),200);
    await status(await request('/appConfig/maintenance',null),200);
    await status(await request('/apartments/managed',token('tenant')),200);
    // In progress: only the admin gets through.
    await status(await maintenanceWindow(-60000,hour),200);
    for(const uid of ['tenant','home','buyer']) {
      await status(await request('/apartments/managed',token(uid)),403);
    }
    await status(await request('/apartments/managed',token('manager')),200);
    await status(await request('/appConfig/maintenance',token('tenant')),200);
    await status(await request('/users/tenant',token('tenant')),200); // roles still load
    await status(await request('/appConfig/maintenance',token('home'),'DELETE'),403);
    // Ended by the admin: everyone is back.
    await status(await request('/appConfig/maintenance',token('manager'),'DELETE'),200);
    await status(await request('/apartments/managed',token('tenant')),200);
  });
  // US 10: an immediate application is only submitted and never reserves.
  await t.test('buyer cannot submit a renter-only immediate application',async()=>{
    const data={...application(),userId:'buyer',applicationType:'immediate',status:'submitted'};
    await status(await commit([write('applications',`${prefix}-buyer-immediate`,data,['submittedAt','updatedAt'])],token('buyer')),403);
  });
  await t.test('no client can reserve an apartment',async()=>{
    await status(await commit([write('apartments','apt',{availability:'reserved'},[],['availability'])],token('tenant')),403);
  });
  // US 16: owners and assigned managers review applications for their apartments.
  // The apartment follows: In review → reserved, Accepted → unavailable,
  // rejected or withdrawn while reserving → available.
  const flat=async name=>{
    const id=`${prefix}-${name}`;
    await status(await admin([write('apartments',id,{ownerId:'home',managerIds:['manager'],availability:'available'})]),200);
    return id;
  };
  const apply=async(id,apartmentId,uid='tenant')=>status(await commit([write('applications',id,
    {...application(),userId:uid,apartmentId,applicationType:'normal'},['submittedAt','updatedAt'])],token(uid)),200);
  const step=(id,to)=>write('applications',id,{status:to},['updatedAt'],['status']);
  let notes=0;
  const notify=(id,uid='tenant')=>write('notifications',`${prefix}-n${++notes}`,{userId:uid,type:'applicationStatus',
    title:'Update',body:'',createdAt:{$time:new Date().toISOString()},isRead:false,applicationId:id});
  const hold=(apartmentId,availability,applicationId)=>write('apartments',apartmentId,
    applicationId?{availability,applicationId}:{availability},[],['availability','applicationId']);
  const readFlat=async id=>(await (await request(`/apartments/${id}`,token('home'))).json()).fields;

  await t.test('only the owner or manager reviews, step by step, and notifies',async()=>{
    const apt=await flat('review'), id=`${prefix}-review`;
    await apply(id,apt);
    await status(await request(`/applications/${id}`,token('home')),200);
    await status(await request(`/applications/${id}`,token('stranger')),403);
    await status(await query('applications',[['apartmentId','EQUAL',apt]],token('home')),200);
    await status(await query('applications',[['apartmentId','EQUAL','other']],token('home')),403);
    await status(await commit([step(id,'accepted')],token('home')),403); // a step cannot be skipped
    await status(await commit([step(id,'received')],token('stranger')),403);
    await status(await commit([step(id,'received')],token('tenant')),403);
    await status(await commit([step(id,'received'),notify(id)],token('home')),200);
    await status(await commit([notify(id)],token('home')),403); // only with a status change
    await status(await commit([step(id,'underReview'),hold(apt,'reserved',id),notify(id)],token('manager')),200);
    await status(await commit([step(id,'accepted'),hold(apt,'unavailable',id),notify(id)],token('home')),200);
    await status(await commit([step(id,'rejected')],token('home')),403); // decided
  });
  await t.test('In review reserves the apartment, one application at a time',async()=>{
    const apt=await flat('reserve'), a=`${prefix}-res-a`, b=`${prefix}-res-b`;
    await apply(a,apt); await apply(b,apt,'buyer');
    await status(await commit([step(a,'received'),notify(a)],token('home')),200);
    await status(await commit([step(b,'received'),notify(b,'buyer')],token('home')),200);
    // The review and the reservation go together.
    await status(await commit([step(a,'underReview'),notify(a)],token('home')),403);
    await status(await commit([hold(apt,'reserved',a)],token('home')),403);
    await status(await commit([step(a,'underReview'),hold(apt,'reserved',b),notify(a)],token('home')),403);
    await status(await commit([step(a,'underReview'),hold(apt,'reserved',a),notify(a)],token('stranger')),403);
    await status(await commit([step(a,'underReview'),hold(apt,'reserved',a),notify(a)],token('home')),200);
    assert.equal((await readFlat(apt)).availability.stringValue,'reserved');
    // Nobody else can apply, and a second review cannot start.
    await status(await commit([write('applications',`${prefix}-res-late`,{...application(),userId:'buyer',apartmentId:apt,
      applicationType:'normal'},['submittedAt','updatedAt'])],token('buyer')),403);
    await status(await commit([step(b,'underReview'),hold(apt,'reserved',b),notify(b,'buyer')],token('home')),403);
    // Only an application change frees or takes the apartment.
    await status(await commit([hold(apt,'available')],token('home')),403);
    await status(await commit([hold(apt,'available')],token('tenant')),403);
    await status(await commit([hold(apt,'unavailable',a)],token('home')),403);
  });
  await t.test('Accepted makes it unavailable and the others are rejected',async()=>{
    const apt=await flat('accept'), a=`${prefix}-acc-a`, b=`${prefix}-acc-b`;
    await apply(a,apt); await apply(b,apt,'buyer');
    await status(await commit([step(a,'received'),notify(a)],token('home')),200);
    await status(await commit([step(a,'underReview'),hold(apt,'reserved',a),notify(a)],token('home')),200);
    // Before the acceptance, an open application cannot be rejected directly.
    await status(await commit([step(b,'rejected'),notify(b,'buyer')],token('home')),403);
    await status(await commit([step(a,'accepted'),notify(a)],token('home')),403);
    await status(await commit([step(a,'accepted'),hold(apt,'unavailable',a),notify(a)],token('home')),200);
    assert.equal((await readFlat(apt)).availability.stringValue,'unavailable');
    await status(await commit([step(b,'rejected'),notify(b,'buyer')],token('home')),200);
    await status(await commit([hold(apt,'available')],token('home')),403);
  });
  await t.test('a rejected or withdrawn review frees the apartment',async()=>{
    const apt=await flat('release'), a=`${prefix}-rel-a`;
    await apply(a,apt);
    await status(await commit([step(a,'received'),notify(a)],token('home')),200);
    await status(await commit([step(a,'underReview'),hold(apt,'reserved',a),notify(a)],token('home')),200);
    await status(await commit([step(a,'rejected'),notify(a)],token('home')),403); // must free it
    await status(await commit([step(a,'rejected'),hold(apt,'available'),notify(a)],token('home')),200);
    const freed=await readFlat(apt);
    assert.equal(freed.availability.stringValue,'available');
    assert.equal(freed.applicationId,undefined);

    const apt2=await flat('withdraw'), w=`${prefix}-rel-w`;
    await apply(w,apt2);
    await status(await commit([step(w,'received'),notify(w)],token('home')),200);
    await status(await commit([step(w,'underReview'),hold(apt2,'reserved',w),notify(w)],token('home')),200);
    await status(await commit([step(w,'withdrawn')]),403); // must free it
    await status(await commit([step(w,'withdrawn'),hold(apt2,'available')],token('buyer')),403);
    await status(await commit([step(w,'withdrawn'),hold(apt2,'available')]),200);
    assert.equal((await readFlat(apt2)).availability.stringValue,'available');
  });
  // US 12: owners and assigned managers read messages about their apartments.
  await t.test('only the owner or manager reads messages in the inbox',async()=>{
    const id=`${prefix}-message`;
    await status(await admin([write('advertiserMessages',id,{apartmentId:'managed',advertiserId:'adv',senderId:'tenant',
      senderEmail:'tenant@example.test',subject:'Hi',body:'Question',status:'sent'})]),200);
    await status(await request(`/advertiserMessages/${id}`,token('manager')),200);
    await status(await request(`/advertiserMessages/${id}`,token('stranger')),403);
    await status(await query('advertiserMessages',[['apartmentId','EQUAL','managed']],token('home')),200);
    await status(await query('advertiserMessages',[['apartmentId','EQUAL','other']],token('home')),403);
  });
  // US 12: a listing without advertiser contact can be contacted through its owner.
  await t.test('a message goes to the listing owner, never to someone else',async()=>{
    const message=advertiserId=>({apartmentId:'managed',advertiserId,senderId:'tenant',
      senderEmail:'tenant@example.test',subject:'Hi',body:'Question',status:'sent'});
    await status(await commit([write('advertiserMessages',`${prefix}-to-owner`,message('home'),['createdAt'])]),200);
    await status(await commit([write('advertiserMessages',`${prefix}-to-other`,message('someone'),['createdAt'])]),403);
  });
});
