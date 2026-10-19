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
function maintenance(uid, apartmentId='managed') {
  return {userId:uid,apartmentId,apartmentTitle:'Apartment',category:'plumbing',description:'Repair the sink',
    slotStart:{$time:new Date(Date.now()+86400000*5).toISOString()},reminders:['oneDay'],status:'scheduled'};
}
const book = (id, uid, apt='managed') => commit([write('maintenanceRequests',id,maintenance(uid,apt),['createdAt','updatedAt'])],token(uid));

test('US-06/07 roles and property access', async t => {
  await status(await admin([
    write('apartments','managed',{ownerId:'home',managerIds:['manager'],availability:'available'}),
    write('apartments','other',{ownerId:'someone',managerIds:[],availability:'available'}),
    write('apartments','legacy',{availability:'available'}),
    write('apartments','apt',{availability:'available'}),
  ]),200);
  for (const [uid,roles] of [['tenant',['renter']],['home',['homeowner']],['manager',['propertyManager']],
    ['stranger',['homeowner','propertyManager']],['buyer',['buyer']]]) {
    await status(await profile(uid,roles),200);
  }
  await t.test('all 15 valid combinations; only self-editable personas',async()=>{
    const names=['buyer','renter','homeowner','propertyManager'];
    for(let mask=1;mask<16;mask++) {
      await status(await profile('combo',names.filter((_,i)=>mask&(1<<i))),200);
      await status(await request('/apartments/managed',token('combo')),200);
    }
    for(const roles of [[],['admin'],['buyer','admin'],['buyer','buyer']]) {
      await status(await profile('combo',roles),403);
    }
    await status(await profile('home',['renter'],token('tenant')),403);
    await status(await commit([write('users','tenant',{roles:['renter'],ownerId:'tenant'})]),403);
    await status(await request('/users/home',token('tenant')),403);
    await status(await request('/users',token()),403);
    await status(await request('/users/tenant',token(),'DELETE'),403);
  });
  await t.test('signed-out, unverified and legacy accounts never enter protected data',async()=>{
    await status(await profile('unverified',['buyer'],token('unverified',false)),200);
    for(const auth of [null,token('unverified',false),token('legacy-user')]) {
      await status(await request('/apartments/managed',auth),403);
      await status(await request('/notifications',auth),403);
    }
    await status(await request('/users/unverified',token('unverified',false)),200);
    await status(await admin([write('users','invalid',{roles:['admin']})]),200);
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
  await t.test('owner and assigned manager can book; roles alone never assign properties',async()=>{
    await status(await book(`${prefix}-home`,'home'),200);
    await status(await book(`${prefix}-manager`,'manager'),200);
    for(const uid of ['tenant','buyer','stranger']) await status(await book(`${prefix}-${uid}`,uid),403);
    for(const apt of ['other','legacy']) {
      await status(await book(`${prefix}-${apt}`,'home',apt),403);
      await status(await book(`${prefix}-manager-${apt}`,'manager',apt),403);
    }
    await status(await commit([write('apartments','managed',{ownerId:'tenant'},[],['ownerId'])]),403);
    await status(await commit([write('apartments','managed',{managerIds:['tenant']},[],['managerIds'])]),403);
  });
  await t.test('maintenance reads and changes require creator plus current assignment',async()=>{
    const path=`/maintenanceRequests/${prefix}-manager`;
    await status(await request(path,token('manager')),200);
    await status(await request(path,token('home')),403);
    const filters=[['userId','EQUAL','manager'],['apartmentId','IN',['managed']]];
    await status(await query('maintenanceRequests',filters,token('manager')),200);
    await status(await query('maintenanceRequests',[['userId','EQUAL','manager']],token('manager')),403);
    await status(await commit([write('maintenanceRequests',`${prefix}-manager`,{
      slotStart:{$time:new Date(Date.now()+86400000*6).toISOString()},reminders:['oneHour']},['updatedAt'],['slotStart','reminders'])],token('manager')),200);
    await status(await admin([write('apartments','managed',{managerIds:[]},[],['managerIds'])]),200);
    await status(await request(path,token('manager')),403);
    await status(await query('maintenanceRequests',filters,token('manager')),403);
    await status(await commit([write('maintenanceRequests',`${prefix}-manager`,{status:'cancelled'},['updatedAt'],['status'])],token('manager')),403);
    await status(await profile('home',['buyer']),200);
    await status(await request(`/maintenanceRequests/${prefix}-home`,token('home')),403);
    await status(await profile('home',['homeowner']),200);
    await status(await commit([write('maintenanceRequests',`${prefix}-home`,{status:'cancelled'},['updatedAt'],['status'])],token('home')),200);
  });
  // US 10: an immediate application is only submitted and never reserves.
  await t.test('buyer cannot submit a renter-only immediate application',async()=>{
    const data={...application(),userId:'buyer',applicationType:'immediate',status:'submitted'};
    await status(await commit([write('applications',`${prefix}-buyer-immediate`,data,['submittedAt','updatedAt'])],token('buyer')),403);
  });
  await t.test('no client can reserve an apartment',async()=>{
    await status(await commit([write('apartments','apt',{availability:'reserved'},[],['availability'])],token('tenant')),403);
  });
});
