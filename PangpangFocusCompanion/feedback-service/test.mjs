import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createFeedbackService } from './server.mjs';

test('persistent submission, authorization, idempotency, validation, CSRF, retention and limits', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'pang-feedback-test-'));
  const password = 'synthetic-test-password-at-least-32-chars';
  const origin = 'http://127.0.0.1:8787';
  let clock = Date.now(), service, base;
  async function start() {
    service = createFeedbackService({password, origin, dbPath:join(directory,'test.sqlite'),now:()=>clock});
    await new Promise(resolve => service.listen(0,'127.0.0.1',resolve));
    base = `http://127.0.0.1:${service.address().port}`;
  }
  const stop = () => new Promise(resolve => service.close(resolve));
  async function request(path, method='GET', body, headers={}) {
    return fetch(base+path,{method,headers:{...(body!==undefined?{'Content-Type':'application/json'}:{}),...headers},body:body!==undefined?JSON.stringify(body):undefined});
  }
  const draft = {id:randomUUID(),category:'使用问题',content:'合成测试 <script>alert(1)</script> 中文 🐱',contact:'test@example.invalid'};
  try {
    await start();
    assert.equal((await request('/api/admin/feedback')).status,401);
    assert.equal((await request('/api/feedback','POST',draft)).status,201);
    assert.equal((await request('/api/feedback','POST',draft)).status,200);
    assert.equal((await request('/api/feedback','POST',{...draft,content:'different'})).status,409);
    for (const change of [{content:''},{content:'x'.repeat(2001)},{contact:'x'.repeat(201)},{category:'invalid'},{id:'abc'},{appVersion:123},{unexpected:'secret'}]) {
      assert.equal((await request('/api/feedback','POST',{...draft,...change})).status,400);
    }
    assert.equal((await request('/api/feedback','POST',{...draft,content:'x'.repeat(20000)})).status,413);
    assert.equal((await request('/api/admin/login','POST',{password})).status,403);
    assert.equal((await request('/api/admin/login','POST',{password:'bad'},{Origin:origin})).status,401);
    let login = await request('/api/admin/login','POST',{password},{Origin:origin});
    assert.equal(login.status,200);
    let cookie = login.headers.get('set-cookie').split(';')[0];
    let headers = {Cookie:cookie,Origin:origin};
    let rows = await (await request('/api/admin/feedback','GET',undefined,headers)).json();
    assert.equal(rows.rows.length,1); assert.equal(rows.rows[0].content,draft.content); assert.equal(rows.rows[0].appVersion,null);
    assert.equal((await request('/api/admin/feedback/'+draft.id,'PATCH',{status:'done'},{Cookie:cookie,Origin:'https://attacker.invalid'})).status,403);
    assert.equal((await request('/api/admin/feedback/'+draft.id,'PATCH',{status:'done'},headers)).status,200);
    await stop(); await start(); // Must survive process/repository reopen; sessions must not.
    assert.equal((await request('/api/admin/feedback','GET',undefined,headers)).status,401);
    login = await request('/api/admin/login','POST',{password},{Origin:origin}); cookie=login.headers.get('set-cookie').split(';')[0]; headers={Cookie:cookie,Origin:origin};
    rows = await (await request('/api/admin/feedback','GET',undefined,headers)).json();
    assert.equal(rows.rows.length,1); assert.equal(rows.rows[0].status,'done');
    assert.equal((await request('/api/admin/feedback/'+draft.id,'DELETE',undefined,headers)).status,200);
    assert.equal((await (await request('/api/admin/feedback','GET',undefined,headers)).json()).rows.length,0);
    for (let i=0;i<10;i++) assert.equal((await request('/api/feedback','POST',{...draft,id:randomUUID()})).status,201);
    assert.equal((await request('/api/feedback','POST',{...draft,id:randomUUID()})).status,429);
    clock += 181*86400_000;
    login = await request('/api/admin/login','POST',{password},{Origin:origin}); headers={Cookie:login.headers.get('set-cookie').split(';')[0],Origin:origin};
    assert.equal((await (await request('/api/admin/feedback','GET',undefined,headers)).json()).rows.length,0);
    assert.equal((await request('/api/admin/logout','POST',undefined,headers)).status,200);
    assert.equal((await request('/api/admin/feedback','GET',undefined,headers)).status,401);
  } finally { if (service?.listening) await stop(); rmSync(directory,{recursive:true,force:true}); }
});
