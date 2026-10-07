// US 12 only. Uses Node's built-in test runner against a local Firestore emulator.
// Never allow this test to point at the shared Firebase project.
import assert from 'node:assert/strict';
import { test } from 'node:test';

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^127\.0\.0\.1:\d+$/.test(host ?? '')) {
  throw new Error('Set FIRESTORE_EMULATOR_HOST to a local 127.0.0.1:<port> emulator.');
}
const project = 'demo-homeflow-us12';
const database = `projects/${project}/databases/(default)`;
const endpoint = `http://${host}/v1/${database}/documents`;

function token(uid, verified = true) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    iss: `https://securetoken.google.com/${project}`, aud: project,
    sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now,
    email: `${uid}@example.com`, email_verified: verified,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}
const sender = token('sender');
const advertiser = token('advertiser');
const outsider = token('outsider');

async function request(path, credential, method = 'GET', body) {
  return fetch(`${endpoint}${path}`, {
    method, headers: {
      ...(credential ? { Authorization: `Bearer ${credential}` } : {}),
      'Content-Type': 'application/json',
    }, body: body ? JSON.stringify(body) : undefined,
  });
}
const fields = values => Object.fromEntries(Object.entries(values).map(([key, value]) => [
  key, typeof value === 'string' ? { stringValue: value } : { integerValue: String(value) },
]));
async function contact(id, uid = 'advertiser') {
  assert.equal((await request(`/advertiserContacts/${id}`, 'owner', 'PATCH', {
    fields: fields({ advertiserId: uid, advertiserName: 'Test advertiser' }),
  })).status, 200);
}
async function send(id, credential = sender, changes = {}, apartmentId = '1') {
  return request(':commit', credential, 'POST', { writes: [{
    update: {
      name: `${database}/documents/advertiserMessages/${id}`,
      fields: fields({ apartmentId, advertiserId: 'advertiser', senderId: 'sender',
        senderEmail: 'sender@example.com', subject: 'Enquiry', body: 'Is it available?',
        status: 'sent', ...changes }),
    },
    updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  }] });
}
async function allowed(response) {
  assert.equal(response.status, 200, await response.text());
}
async function denied(response) {
  assert.equal(response.status, 403, await response.text());
}

test('verified sender stores a message; only its participants can read it', async () => {
  await contact('1');
  await allowed(await send('read-access'));
  await allowed(await request('/advertiserMessages/read-access', sender));
  await allowed(await request('/advertiserMessages/read-access', advertiser));
  await denied(await request('/advertiserMessages/read-access', outsider));
  await denied(await request('/advertiserMessages/read-access', token('sender', false)));
  await denied(await request('/advertiserMessages/read-access', null));
  assert.equal((await request('/advertiserMessages/unused-reference', sender)).status, 404);
});

test('authentication, sender and mapped recipient cannot be forged', async () => {
  await contact('1');
  await denied(await send('unverified', token('sender', false)));
  await denied(await send('signed-out', null));
  await denied(await send('forged-sender', sender, { senderId: 'outsider' }));
  await denied(await send('forged-email', sender, { senderEmail: 'outsider@example.com' }));
  await denied(await send('forged-recipient', sender, { advertiserId: 'outsider' }));
  await denied(await send('missing-contact', sender, {}, 'missing'));
});

test('only the allowed schema and bounded nonblank message text are accepted', async () => {
  await contact('1');
  for (const [id, changes] of [
    ['blank', { body: ' \n ' }], ['long-body', { body: 'x'.repeat(2001) }],
    ['long-subject', { subject: 'x'.repeat(121) }], ['blank-subject', { subject: '  ' }],
    ['wrong-type', { body: 7 }], ['extra-field', { privileged: 'true' }],
    ['wrong-status', { status: 'read' }],
  ]) await denied(await send(id, sender, changes));
  await allowed(await send('multiline', sender, { body: 'Hello\nCould I arrange a viewing?' }));
  const write = {
    name: `${database}/documents/advertiserMessages/client-time`,
    fields: { ...fields({ apartmentId: '1', advertiserId: 'advertiser', senderId: 'sender',
      senderEmail: 'sender@example.com', subject: 'Enquiry', body: 'Hello', status: 'sent' }),
      createdAt: { timestampValue: '2020-01-01T00:00:00Z' } },
  };
  await denied(await request(':commit', sender, 'POST', { writes: [{ update: write }] }));
});

test('messages are immutable and contact mappings are administered outside the app', async () => {
  await contact('1');
  await allowed(await send('immutable'));
  await denied(await send('immutable', sender, { body: 'Replacement message' }));
  await denied(await request('/advertiserMessages/immutable', sender, 'DELETE'));
  await allowed(await request('/advertiserContacts/1', sender));
  await denied(await request('/advertiserContacts/1', sender, 'PATCH', {
    fields: fields({ advertiserId: 'outsider', advertiserName: 'Other' }),
  }));
  await denied(await request('/advertiserContacts/1', null));
  // US 12 must not grant access to collections belonging to other stories.
  await allowed(await request('/otherStories/protected', 'owner', 'PATCH', {
    fields: fields({ value: 'Existing work' }),
  }));
  await denied(await request('/otherStories/protected', sender));
  await denied(await request('/otherStories/protected', sender, 'PATCH', {
    fields: fields({ value: 'Changed' }),
  }));
  await contact('reassigned', 'new-owner');
  await denied(await send('stale-recipient', sender, {}, 'reassigned'));
});

test('queries must constrain results to the current sender or advertiser', async () => {
  await contact('1');
  await allowed(await send('query-message'));
  const query = (field, uid) => ({ structuredQuery: {
    from: [{ collectionId: 'advertiserMessages' }],
    ...(field ? { where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL',
      value: { stringValue: uid } } } } : {}),
  } });
  await allowed(await request(':runQuery', sender, 'POST', query('senderId', 'sender')));
  await allowed(await request(':runQuery', advertiser, 'POST', query('advertiserId', 'advertiser')));
  await denied(await request(':runQuery', outsider, 'POST', query('senderId', 'sender')));
  await denied(await request(':runQuery', sender, 'POST', query()));
});
