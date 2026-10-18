// US-15: real rules, local demo project only, no npm dependencies.
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
    moveInDate:{$time:new Date(Date.now()+86400000*30).toISOString()},occupants:1,message:'',status:'submitted',applicationType:'normal',documentIds:ids};
}
const appWrite = (id, ids) => write('applications',id,application(ids),['submittedAt','updatedAt']);
const firstUse = (id, appId) => write('uploadedDocuments',id,{firstApplicationId:appId},[],['firstApplicationId']);

test('US-15 Firestore rules',async t=>{
  // Fail once with a useful connection error if the emulator has not started.
  await status(await request('/uploadedDocuments','owner'),200);
  await status(await commit([write('users','tenant',{roles:['renter']}),write('apartments','apt',{availability:'available'})],'owner'),200);
  await t.test('verified owners upload, read and delete unused files',async()=>{
    const id=`${prefix}-valid`;
    await status(await upload(id),200);
    await status(await request(`/uploadedDocuments/${id}`,token()),200);
    await status(await request(`/uploadedDocuments/${id}`,token(),'DELETE'),200);
  });
  await t.test('signed-out, unverified and different accounts cannot access files',async()=>{
    const id=`${prefix}-private`; await status(await upload(id),200);
    for (const auth of [null,token('tenant',false),token('other')]) {
      await status(await request(`/uploadedDocuments/${id}`,auth),403);
      await status(await upload(`${id}-${auth===null?'out':auth.length}`,file(),auth),403);
      await status(await request(`/uploadedDocuments/${id}`,auth,'DELETE'),403);
    }
  });
  await t.test('size, MIME, metadata, timestamp and immutable originals are enforced',async()=>{
    for (const [index, change] of [{byteSize:0},{byteSize:716801},{mimeType:'image/png'},
      {name:'photo.txt'},{userId:'other'},{status:'signed'},{signatureId:'tenant'},
      {firstApplicationId:'fake'},{extraField:true}].entries()) {
      await status(await upload(`${prefix}-invalid-${index}`,file(change)),403);
    }
    const id=`${prefix}-original`; await status(await upload(id),200);
    await status(await commit([write('uploadedDocuments',id,{name:'replacement.jpg'},[],['name'])]),403);
    await status(await commit([write('uploadedDocuments',`${prefix}-time`,{
      ...file(),createdAt:{$time:'2026-01-01T00:00:00Z'}})]),403);
  });
  await t.test('attachment linking is atomic, reusable and protects deletion',async()=>{
    const id=`${prefix}-attach`, app=`${prefix}-app1`;
    await status(await upload(id),200);
    await status(await commit([appWrite(app,[id])]),403);
    await status(await commit([firstUse(id,'missing-app')]),403);
    await status(await commit([appWrite(app,[id]),firstUse(id,app)]),200);
    await status(await request(`/uploadedDocuments/${id}`,token(),'DELETE'),403);
    await status(await commit([appWrite(`${prefix}-app2`,[id])]),200);
    await status(await commit([write('uploadedDocuments',id,{firstApplicationId:null},[],['firstApplicationId'])]),403);
    await status(await commit([write('applications',app,{documentIds:[]},['updatedAt'],['documentIds'])]),403);
  });
  await t.test('up to five unique owned attachments; old applications remain valid',async()=>{
    const ids=Array.from({length:5},(_,i)=>`${prefix}-five-${i}`), app=`${prefix}-five-app`;
    for (const id of ids) await status(await upload(id),200);
    await status(await commit([appWrite(app,ids),...ids.map(id=>firstUse(id,app))]),200);
    await status(await commit([appWrite(`${prefix}-six`,[...ids,'sixth'])]),403);
    await status(await commit([appWrite(`${prefix}-duplicate`,[ids[0],ids[0]])]),403);
    await status(await commit([appWrite(`${prefix}-missing`,['missing'])]),403);
    const legacy=application(); delete legacy.documentIds;
    await status(await commit([write('applications',`${prefix}-legacy`,legacy,['submittedAt','updatedAt'])]),200);
  });
  await t.test('queries require an owner filter; unrelated data stays protected',async()=>{
    const structuredQuery={from:[{collectionId:'uploadedDocuments'}],where:{fieldFilter:{
      field:{fieldPath:'userId'},op:'EQUAL',value:{stringValue:'tenant'}}}};
    await status(await request(':runQuery',token(),'POST',{structuredQuery}),200);
    await status(await request(':runQuery',token(),'POST',{structuredQuery:{from:[{collectionId:'uploadedDocuments'}]}}),403);
    await status(await commit([write('unrelated',`${prefix}-no`,{value:'test'})]),403);
  });
});
