// US-24 representative fixtures. Only writes to a local demo emulator.
import {readFile} from 'node:fs/promises';
const host=process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Set a local FIRESTORE_EMULATOR_HOST.');
const database='projects/demo-homeflow-us24/databases/(default)';
function value(v) {
  if (Array.isArray(v)) return {arrayValue:{values:v.map(value)}};
  if (typeof v==='string') return {stringValue:v};
  return Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v};
}
const fixtures=JSON.parse(await readFile(new URL('../fixtures/us24_apartments.json',import.meta.url),'utf8'));
const rows=[['users','sample-homeowner',{roles:['homeowner']}],...fixtures.map(({id,...data})=>['apartments',id,data])];
const writes=rows.map(([collection,id,data])=>({update:{name:`${database}/documents/${collection}/${id}`,
  fields:Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]))},
  ...(collection==='apartments'?{updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]}:{})}));
const response=await fetch(`http://${host}/v1/${database}/documents:commit`,{method:'POST',
  headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify({writes})});
if (!response.ok) throw Error(await response.text());
console.log(`Prepared ${fixtures.length} synthetic listings in demo-homeflow-us24.`);
