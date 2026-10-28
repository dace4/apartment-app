import assert from 'node:assert/strict';
import {test} from 'node:test';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Set a local FIRESTORE_EMULATOR_HOST.');
const project = 'demo-service-market-trends';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid, verified = true) {
  const encode = data => Buffer.from(JSON.stringify(data)).toString('base64url');
  return `${encode({alg:'none',typ:'JWT'})}.${encode({sub:uid,user_id:uid,email_verified:verified,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})}.`;
}
async function request(path, auth, method = 'GET', body) {
  return fetch(base+path, {method, headers: {'Content-Type':'application/json', ...(auth ? {Authorization:`Bearer ${auth}`} : {})}, ...(body ? {body:JSON.stringify(body)} : {})});
}
async function status(response, expected) { assert.equal(response.status, expected, await response.text()); }
const entry = {name:'Demo contractor', city:'Lausanne'};
function fields(data) { return Object.fromEntries(Object.entries(data).map(([k,v]) => [k, Array.isArray(v) ? {arrayValue:{values:v.map(stringValue=>({stringValue}))}} : {stringValue:v}])); }
test('marketTrends catalogue role rules', async t => {
  for (const role of ['buyer','renter','homeowner','propertyManager']) {
    await status(await request(`/users/${role}`, 'owner', 'PATCH', {fields:fields({roles:[role]})}), 200);
  }
  await status(await request('/marketTrends/demo', 'owner', 'PATCH', {fields:fields(entry)}), 200);
  await t.test('verified buyer can read and list', async () => {
    await status(await request('/marketTrends/demo', token('buyer')), 200);
    await status(await request('/marketTrends', token('buyer')), 200);
  });
  await t.test('other roles, unverified and signed-out reads fail', async () => {
    for (const auth of [null,token('buyer',false),token('missing'),...['buyer','renter','homeowner','propertyManager'].filter(r=>r!=='buyer').map(r=>token(r))]) {
      await status(await request('/marketTrends/demo', auth), 403);
      await status(await request('/marketTrends', auth), 403);
    }
  });
  await t.test('clients cannot create, update or delete catalogue data', async () => {
    for (const role of ['buyer','renter','homeowner','propertyManager']) {
      await status(await request('/marketTrends/new', token(role), 'PATCH', {fields:fields(entry)}), 403);
      await status(await request('/marketTrends/demo', token(role), 'PATCH', {fields:fields(entry)}), 403);
      await status(await request('/marketTrends/demo', token(role), 'DELETE'), 403);
    }
  });
});
