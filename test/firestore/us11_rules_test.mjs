// US-11: real rules, local demo project only, no npm dependencies.
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


const signature='[[[0.1,0.2],[0.7,0.6],[0.8,0.3]]]';
const saveSignature=(uid='tenant', drawing=signature, auth=token(uid)) =>
  commit([write('userSignatures',uid,{drawing},['updatedAt'])],auth);
const bind=(id,uid='tenant',auth=token(uid)) => commit([write('uploadedDocuments',id,
  {status:'signed',signatureId:uid},['signedAt'],['status','signatureId'])],auth);
test('US-11 reusable signature rules',async t=>{
  await status(await request('/uploadedDocuments','owner'),200);
  await status(await commit([write('users','tenant',{roles:['renter']}),write('apartments','apt',{availability:'available'})],'owner'),200);
  await t.test('one private signature can be created and replaced under the same UID',async()=>{
    await status(await saveSignature(),200);
    const original=await (await request('/userSignatures/tenant',token())).json();
    await status(await saveSignature('tenant','[[[0.2,0.3],[0.5,0.7],[0.9,0.4]]]'),200);
    const replacement=await (await request('/userSignatures/tenant',token())).json();
    assert.equal(original.name,replacement.name);
    assert.notEqual(original.fields.drawing.stringValue,replacement.fields.drawing.stringValue);
    await status(await request('/userSignatures/tenant',token('other')),403);
    await status(await request('/userSignatures/tenant',token(),'DELETE'),403);
    await status(await saveSignature('other',signature,token()),403);
    await status(await saveSignature('tenant','[]'),403);
    await status(await saveSignature('tenant',signature,token('tenant',false)),403);
  });
  await t.test('a saved signature is required; signed bytes and first signing time are immutable',async()=>{
    const missing=prefix+'-no-signature';
    await status(await commit([write('users','nosig',{roles:['renter']})],'owner'),200);
    await status(await upload(missing,file({userId:'nosig'}),token('nosig')),200);
    await status(await bind(missing,'nosig'),403);
    const id=prefix+'-signed'; await status(await upload(id),200);
    const original=await (await request('/uploadedDocuments/'+id,token())).json();
    await status(await bind(id),200);
    const signed=await (await request('/uploadedDocuments/'+id,token())).json();
    assert.equal(signed.fields.fileBytes.bytesValue,original.fields.fileBytes.bytesValue);
    assert.equal(signed.fields.signatureId.stringValue,'tenant');
    assert.ok(signed.fields.signedAt.timestampValue);
    assert.equal(Object.keys(signed.fields).length,Object.keys(original.fields).length);
    await status(await bind(id),403);
    await status(await request('/uploadedDocuments/'+id,token(),'DELETE'),403);
    await status(await commit([write('uploadedDocuments',id,{status:'unsigned',signatureId:null,signedAt:null},
      [],['status','signatureId','signedAt'])]),403);
    await status(await saveSignature(),200);
    assert.deepEqual(await (await request('/uploadedDocuments/'+id,token())).json(),signed);
  });
  await t.test('signature identity, source bytes and server timestamp cannot be forged',async()=>{
    const id=prefix+'-forgery'; await status(await upload(id),200);
    await status(await bind(id,'other',token()),403);
    await status(await commit([write('uploadedDocuments',id,{status:'signed',signatureId:'tenant',
      signedAt:{$time:'2026-01-01T00:00:00Z'}},[],['status','signatureId','signedAt'])]),403);
    await status(await commit([write('uploadedDocuments',id,{status:'signed',signatureId:'tenant',fileBytes:Buffer.from([0])},
      ['signedAt'],['status','signatureId','fileBytes'])]),403);
    await status(await bind(id,'tenant',null),403);
    await status(await bind(id,'tenant',token('tenant',false)),403);
  });
  await t.test('signed files can still be attached and reused without altering the binding',async()=>{
    const id=prefix+'-signed-attach', app=prefix+'-app'; await status(await upload(id),200);
    await status(await bind(id),200);
    const original=await (await request('/uploadedDocuments/'+id,token())).json();
    await status(await commit([appWrite(app,[id]),firstUse(id,app)]),200);
    const linked=await (await request('/uploadedDocuments/'+id,token())).json();
    assert.deepEqual(linked.fields.signedAt,original.fields.signedAt);
    assert.deepEqual(linked.fields.signatureId,original.fields.signatureId);
  });
});
