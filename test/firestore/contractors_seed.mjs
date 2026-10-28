import {readFile} from 'node:fs/promises';
const args = process.argv.slice(2);
const project = args.find(a => a.startsWith('--project='))?.slice(10);
if (!project || !/^[a-z][a-z0-9-]+$/.test(project)) throw Error('Specify --project=PROJECT_ID.');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (host && !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Only local emulators are supported.');
if (host && !project.startsWith('demo-')) throw Error('Emulator project must start with demo-.');
const rows = JSON.parse(await readFile(new URL('../fixtures/contractors.json', import.meta.url), 'utf8'));
const database = `projects/${project}/databases/(default)`;
function value(v) {
  return typeof v === 'string' ? {stringValue: v} : {integerValue: String(v)};
}
const writes = rows.map(({id, ...data}) => ({
  update: {name: `${database}/documents/contractors/${id}`,
    fields: Object.fromEntries(Object.entries(data).map(([key,v]) => [key,value(v)]))},
  currentDocument: {exists: false},
}));
if (!args.includes('--apply')) {
  console.log(`Dry run: create ${writes.length} demo documents in ${project}/contractors. No data written.`);
} else {
  const token = host ? 'owner' : process.env.FIRESTORE_ACCESS_TOKEN;
  if (!token) throw Error('Set FIRESTORE_ACCESS_TOKEN to a short-lived operator OAuth token. Never commit it.');
  const origin = host ? `http://${host}` : 'https://firestore.googleapis.com';
  const response = await fetch(`${origin}/v1/${database}/documents:commit`, {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${token}`},
    body: JSON.stringify({writes}),
  });
  if (!response.ok) throw Error(`Seed failed (${response.status}). No existing entries are overwritten.`);
  console.log(`Created ${writes.length} demo documents in ${project}/contractors.`);
}
