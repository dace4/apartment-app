// US-24: real publication rules; local demo project only.
import assert from 'node:assert/strict';
import {test} from 'node:test';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Set a local FIRESTORE_EMULATOR_HOST.');
const project = 'demo-homeflow-us24';

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

const photos = ['data:image/jpeg;base64,/9j/AAAA', 'data:image/jpeg;base64,/9j/BBBB', 'data:image/jpeg;base64,/9j/CCCC'];
function listing(overrides={}) {
  return {title:'Sunny apartment',address:'Rue de Test 24',city:'Sion',listingType:'rent',
    price:1500,rooms:3,surface:80,imageUrl:photos[0],imageUrls:photos,
    description:'A representative apartment.',availability:'available',amenities:['balcony'],
    ownerId:'tenant',managerIds:[],...overrides};
}
const publish = (id, data=listing(), auth=token()) => commit([
  write('apartments', id, data, ['createdAt'])], auth);

test('US-24 publication rules', async t => {
  await status(await commit([
    write('users','tenant',{roles:['homeowner']}),
    write('users','renter',{roles:['renter']}),
    // A retired Property Manager profile: invalid, so it cannot publish.
    write('users','manager',{roles:['propertyManager']}),
    write('apartments',`${prefix}-legacy`,{...listing(),imageUrls:[]})
  ],'owner'),200);
  await t.test('verified homeowner publishes and reads a gallery; legacy listings remain readable',async()=>{
    await status(await publish(`${prefix}-ok`),200);
    await status(await request(`/apartments/${prefix}-ok`,token()),200);
    await status(await request(`/apartments/${prefix}-legacy`,token('renter')),200);
  });
  await t.test('signed-out, unverified, renter and manager creation is denied',async()=>{
    for (const [i, auth] of [null,token('tenant',false),token('renter'),token('manager')].entries()) {
      await status(await publish(`${prefix}-role-${i}`,listing(),auth),403);
    }
  });
  await t.test('three to six distinct bounded JPEG images are required',async()=>{
    for (const [i, imageUrls] of [[],photos.slice(0,2),[photos[0],photos[0],photos[1]],
      [...photos,...photos],['https://example.test/a.jpg',...photos.slice(1)],
      ['data:image/jpeg;base64,/9j/'+'A'.repeat(131096),...photos.slice(1)]].entries()) {
      await status(await publish(`${prefix}-photo-${i}`,listing({imageUrls,imageUrl:imageUrls[0]??''})),403);
    }
    const six=[...photos,...photos.map(p=>p+'DDDD')];
    await status(await publish(`${prefix}-six`,listing({imageUrls:six})),200);
  });
  await t.test('forged ownership, assignment, invalid fields and extra metadata fail',async()=>{
    const bad=[{ownerId:'other'},{managerIds:['manager']},{availability:'reserved'},
      {title:''},{title:'  \n '},{description:''},{price:0},{surface:-1},{rooms:0},
      {listingType:'other'},{amenities:['fake']},{imageUrl:photos[1]},
      {title:'x'.repeat(201)},{reservationApplicationId:'forged'},{extra:true}];
    for (const [i, change] of bad.entries()) {
      await status(await publish(`${prefix}-invalid-${i}`,listing(change)),403);
    }
    await status(await commit([write('apartments',`${prefix}-time`,{
      ...listing(),createdAt:{$time:'2026-01-01T00:00:00Z'}})]),403);
  });
  await t.test('creation cannot overwrite or claim an existing listing',async()=>{
    await status(await publish(`${prefix}-immutable`),200);
    await status(await publish(`${prefix}-immutable`,listing({title:'Changed'})),403);
    await status(await commit([write('apartments',`${prefix}-legacy`,{ownerId:'tenant'},[],['ownerId'])]),403);
  });
});
