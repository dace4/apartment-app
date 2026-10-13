// US-11: actual security rules on a local demo emulator, no npm dependencies.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHash } from 'node:crypto';

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Set FIRESTORE_EMULATOR_HOST to a local emulator, e.g. 127.0.0.1:8187.');
}
const project = 'demo-homeflow-us11';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const consent = 'I have reviewed this document and consent to sign it electronically. I understand that my signature and this document will be saved together and cannot be edited after signing.';
const signature = JSON.stringify([[[.1, .2], [.5, .6], [.9, .3]]]);
const runId = `us11-${Date.now()}`;
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
function token(uid = 'tenant', verified = true) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({
    iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid,
    user_id: uid, email: `${uid}@example.test`, email_verified: verified,
    auth_time: now, iat: now, exp: now + 3600,
    firebase: {sign_in_provider: 'custom'},
  })}.`;
}
function field(value) {
  if (value && typeof value === 'object' && '$time' in value) return {timestampValue: value.$time};
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (Number.isInteger(value)) return {integerValue: String(value)};
  return {mapValue: {fields: fields(value)}};
}
const fields = value => Object.fromEntries(Object.entries(value).map(([k, v]) => [k, field(v)]));
async function request(path, auth, method = 'GET', body) {
  return fetch(`${base}${path}`, {method, headers: {
    'Content-Type': 'application/json', ...(auth ? {Authorization: `Bearer ${auth}`} : {}),
  }, ...(body ? {body: JSON.stringify(body)} : {})});
}
async function expectStatus(response, status) {
  const text = await response.text();
  assert.equal(response.status, status, text);
}
function source(overrides = {}) {
  return {userId: 'tenant', title: 'Test rental agreement', body: 'These are the exact reviewed terms.',
    version: 1, issuedAt: {$time: '2026-10-13T10:00:00.123456789Z'}, state: 'ready', ...overrides};
}
function signed(id, original) {
  const documentHash = hash(['US-11-document-v1', id, original.userId,
    original.title, original.body, original.version, 1791885600, 123456789, original.state]);
  return {document: original, signerId: 'tenant', signerEmail: 'tenant@example.test',
    signerName: 'Tenant Name', signature, documentHash,
    recordHash: hash(['US-11-record-v1', documentHash, 'tenant', 'tenant@example.test',
      'Tenant Name', signature, 'US-11-v1', consent]),
    consentVersion: 'US-11-v1', consentText: consent, consented: true};
}
async function assign(id, original = source()) {
  await expectStatus(await request(`/signingDocuments/${id}`, 'owner', 'PATCH',
    {fields: fields(original)}), 200);
  return original;
}
async function commit(id, record, auth = token(), serverTime = true) {
  return request(':commit', auth, 'POST', {writes: [{
    update: {name: `projects/${project}/databases/(default)/documents/signedDocuments/${id}`,
      fields: fields(serverTime ? record : {...record, signedAt: {$time: '2026-01-01T00:00:00Z'}})},
    ...(serverTime ? {updateTransforms: [{fieldPath: 'signedAt', setToServerValue: 'REQUEST_TIME'}]} : {}),
  }]});
}

test('US-11 actual Firestore rules', async t => {
  await t.test('verified assignee can read and sign; snapshot and server time persist', async () => {
    const id = `${runId}-valid`; const original = await assign(id);
    await expectStatus(await request(`/signingDocuments/${id}`, token()), 200);
    await expectStatus(await commit(id, signed(id, original)), 200);
    const response = await request(`/signedDocuments/${id}`, token());
    assert.equal(response.status, 200);
    const record = await response.json();
    assert.equal(record.fields.document.mapValue.fields.body.stringValue, original.body);
    assert.ok(record.fields.signedAt.timestampValue);
    await expectStatus(await commit(id, signed(id, original)), 403);
    await expectStatus(await request(`/signedDocuments/${id}`, token(), 'DELETE'), 403);
  });
  await t.test('signed-out, unverified and other users cannot read or sign', async () => {
    const id = `${runId}-auth`; const original = await assign(id);
    for (const auth of [null, token('tenant', false), token('other')]) {
      await expectStatus(await request(`/signingDocuments/${id}`, auth), 403);
      await expectStatus(await commit(id, signed(id, original), auth), 403);
    }
    await expectStatus(await commit(id, signed(id, original)), 200);
    for (const auth of [null, token('tenant', false), token('other')]) {
      await expectStatus(await request(`/signedDocuments/${id}`, auth), 403);
    }
  });
  await t.test('clients cannot provision, edit or delete assignments', async () => {
    const id = `${runId}-source`; await assign(id);
    await expectStatus(await request(`/signingDocuments/${id}`, token(), 'PATCH',
      {fields: fields(source({body: 'Client changes'}))}), 403);
    await expectStatus(await request(`/signingDocuments/${id}`, token(), 'DELETE'), 403);
    await expectStatus(await request(`/signingDocuments/${id}-new`, token(), 'PATCH',
      {fields: fields(source())}), 403);
  });
  await t.test('consent, identity, signature bounds and audit schema are enforced', async () => {
    const changes = [{consented: false}, {consentText: 'Different wording'},
      {consentVersion: 'v0'}, {signerId: 'other'}, {signerEmail: 'other@example.test'},
      {signerName: '   '}, {signature: '[]'}, {signature: 'x'.repeat(100001)},
      {documentHash: 'invalid'}, {recordHash: 'invalid'}, {extraField: true}];
    for (const [index, change] of changes.entries()) {
      const id = `${runId}-audit-${index}`; const original = await assign(id);
      await expectStatus(await commit(id, {...signed(id, original), ...change}), 403);
    }
    const id = `${runId}-timestamp`; const original = await assign(id);
    await expectStatus(await commit(id, signed(id, original), token(), false), 403);
  });
  await t.test('changed content, version, timestamp and wrong assignment cannot be bound', async () => {
    const id = `${runId}-integrity`; const original = await assign(id);
    for (const change of [{body: 'Other terms'}, {version: 2},
      {issuedAt: {$time: '2026-10-13T10:00:00Z'}}, {userId: 'other'}]) {
      await expectStatus(await commit(id, signed(id, {...original, ...change})), 403);
    }
    await expectStatus(await commit(`${runId}-missing`, signed(id, original)), 403);
  });
  await t.test('withdrawn documents cannot be signed', async () => {
    const id = `${runId}-withdrawn`; const original = await assign(id, source({state: 'withdrawn'}));
    await expectStatus(await commit(id, signed(id, original)), 403);
  });
  await t.test('queries require owner filters; unrelated collections stay denied', async () => {
    for (const [collection, ownerField] of [['signingDocuments', 'userId'], ['signedDocuments', 'signerId']]) {
      const structuredQuery = {from: [{collectionId: collection}], where: {fieldFilter: {
        field: {fieldPath: ownerField}, op: 'EQUAL', value: {stringValue: 'tenant'},
      }}};
      await expectStatus(await request(':runQuery', token(), 'POST', {structuredQuery}), 200);
      await expectStatus(await request(':runQuery', token(), 'POST', {
        structuredQuery: {from: [{collectionId: collection}]},
      }), 403);
    }
    await expectStatus(await request(`/unrelated/${runId}`, token(), 'PATCH',
      {fields: fields({value: 'test'})}), 403);
  });
});
