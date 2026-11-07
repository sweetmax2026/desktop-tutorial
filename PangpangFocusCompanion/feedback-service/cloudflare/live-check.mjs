import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const origin='https://pang-feedback.maxwithcoconut.workers.dev';
const password=readFileSync(new URL('./.admin.env',import.meta.url),'utf8').trim().replace(/^ADMIN_PASSWORD=/,'');
let cookie='';
async function request(path,method='GET',data,authenticated=false) {
  return fetch(origin+path,{method,redirect:'error',headers:{...(data===undefined?{}:{'Content-Type':'application/json'}),...(authenticated?{Cookie:cookie,Origin:origin}:{})},body:data===undefined?undefined:JSON.stringify(data)});
}
for (const path of ['/admin','/support','/privacy','/admin.js','/admin.css']) {
  const page=await request(path);
  assert.equal(page.status,200,`Static page failed: ${path}`);
  assert.equal(page.headers.get('Cache-Control'),'no-store');
}
console.log('PASS: admin, support, policy and assets serve directly without redirect loops');
assert.equal((await request('/api/admin/feedback')).status,401);
const login=await request('/api/admin/login','POST',{password},true);
assert.equal(login.status,200);
cookie=login.headers.get('set-cookie').split(';')[0];
const child=spawnSync(fileURLToPath(new URL('../../build/FeedbackLiveCheck',import.meta.url)),[],{env:{...process.env,PANG_FEEDBACK_LIVE_URL:origin+'/api/feedback'},encoding:'utf8'});
if(child.status!==0) throw Error('Swift live submission failed: '+child.stderr);
const id=child.stdout.trim();
assert.match(id,/^[0-9a-f-]{36}$/);
try {
  const list=await (await request('/api/admin/feedback','GET',undefined,true)).json();
  const row=list.rows.find(row=>row.id===id);
  assert.ok(row && row.content.startsWith('【自动联调测试】'));
  assert.equal(row.contact,'');assert.equal(row.appVersion,null);assert.equal(row.systemVersion,null);
  assert.equal(list.rows.filter(row=>row.id===id).length,1);
  assert.equal((await request('/api/admin/feedback/'+id,'PATCH',{status:'done'},true)).status,200);
  assert.equal((await request('/api/admin/feedback/'+id,'PATCH',{status:'new'})).status,401);
  console.log('PASS: live Swift HTTPS submit, retry deduplication, authenticated list and status, anonymous denial, version opt-out');
} finally {
  assert.equal((await request('/api/admin/feedback/'+id,'DELETE',undefined,true)).status,200);
  assert.equal((await request('/api/admin/logout','POST',undefined,true)).status,200);
  console.log('PASS: synthetic feedback removed; session revoked; no formal app data accessed');
}
