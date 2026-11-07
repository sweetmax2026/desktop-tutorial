import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker, { cleanup } from './worker.mjs';

// Exercise the real SQL and Fetch handler; only the D1 transport is replaced.
function database() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('./migrations/0001.sql',import.meta.url),'utf8'));
  const db={prepare(sql){
    let values=[];const statement=sqlite.prepare(sql);
    return {bind(...args){values=args;return this;},async first(){return statement.get(...values)||null;},async all(){return {results:statement.all(...values)};},async run(){const result=statement.run(...values);return {meta:{changes:result.changes}};}};
  },async batch(statements){return Promise.all(statements.map(x=>x.run()));},close(){sqlite.close();}};
  return db;
}
test('Cloudflare Fetch handler with real SQLite: auth, persistence, CSRF, idempotency, limits and retention',async()=>{
  const DB=database(),env={DB,ADMIN_PASSWORD:'synthetic-cloudflare-test-password-only-32'};
  const origin='https://feedback.example.invalid';
  const send=(path,method='GET',data,headers={})=>worker.fetch(new Request(origin+path,{method,headers:{'CF-Connecting-IP':'192.0.2.1',...(data!==undefined?{'Content-Type':'application/json'}:{}),...headers},body:data===undefined?undefined:JSON.stringify(data)}),env);
  const draft={id:crypto.randomUUID(),category:'功能建议',content:'合成测试 <script>alert(1)</script>',contact:'test@example.invalid'};
  try {
    assert.equal((await send('/api/admin/feedback')).status,401);
    assert.equal((await send('/api/feedback','POST',draft)).status,201);
    assert.equal((await send('/api/feedback','POST',draft)).status,200);
    assert.equal((await send('/api/feedback','POST',{...draft,content:'changed'})).status,409);
    const concurrent={...draft,id:crypto.randomUUID()};
    const duplicateResults=await Promise.all([send('/api/feedback','POST',concurrent),send('/api/feedback','POST',concurrent)]);
    assert.deepEqual(duplicateResults.map(x=>x.status).sort(),[200,201]);
    for(const delta of [{content:''},{content:'x'.repeat(2001)},{contact:'x'.repeat(201)},{id:'x'},{category:'x'},{appVersion:123},{secret:'x'}]) assert.equal((await send('/api/feedback','POST',{...draft,...delta})).status,400);
    assert.equal((await send('/api/feedback','POST',{...draft,content:'x'.repeat(17000)})).status,413);
    assert.equal((await send('/api/feedback','POST',draft,{Origin:'https://attacker.invalid'})).status,403);
    assert.equal((await send('/api/admin/login','POST',{password:env.ADMIN_PASSWORD})).status,403);
    assert.equal((await send('/api/admin/login','POST',{password:'bad'},{Origin:origin})).status,401);
    let login=await send('/api/admin/login','POST',{password:env.ADMIN_PASSWORD},{Origin:origin});
    assert.equal(login.status,200);assert.match(login.headers.get('Set-Cookie'),/HttpOnly; Secure; SameSite=Strict/);
    const headers={Origin:origin,Cookie:login.headers.get('Set-Cookie').split(';')[0]};
    const list=await (await send('/api/admin/feedback','GET',undefined,headers)).json();
    assert.equal(list.rows.length,2);assert.equal(list.rows.find(x=>x.id===draft.id).content,draft.content);
    assert.equal(list.rows[0].appVersion,null);
    assert.equal((await send('/api/admin/feedback/'+draft.id,'PATCH',{status:'done'},headers)).status,200);
    assert.equal((await send('/api/admin/feedback/'+draft.id,'DELETE',undefined,{Cookie:headers.Cookie})).status,403);
    assert.equal((await send('/api/admin/feedback/'+draft.id,'DELETE',undefined,headers)).status,200);
    assert.equal((await send('/api/admin/feedback/'+draft.id,'DELETE',undefined,headers)).status,404);
    await DB.prepare('UPDATE feedback SET created_at=? WHERE id=?').bind(Date.now()-181*86400000,concurrent.id).run();
    await cleanup(env);
    assert.equal((await (await send('/api/admin/feedback','GET',undefined,headers)).json()).rows.length,0);
    assert.equal((await send('/api/admin/logout','POST',undefined,headers)).status,200);
    assert.equal((await send('/api/admin/feedback','GET',undefined,headers)).status,401);
    for(let i=0;i<10;i++) assert.equal((await send('/api/feedback','POST',{...draft,id:crypto.randomUUID()},{'CF-Connecting-IP':'192.0.2.99'})).status,201);
    assert.equal((await send('/api/feedback','POST',{...draft,id:crypto.randomUUID()},{'CF-Connecting-IP':'192.0.2.99'})).status,429);
    for(let i=0;i<5;i++) assert.equal((await send('/api/admin/login','POST',{password:'bad'},{Origin:origin,'CF-Connecting-IP':'192.0.2.111'})).status,401);
    assert.equal((await send('/api/admin/login','POST',{password:env.ADMIN_PASSWORD},{Origin:origin,'CF-Connecting-IP':'192.0.2.111'})).status,429);
    assert.equal((await send('/api/admin/feedback')).headers.get('Cache-Control'),'no-store');
  }finally{DB.close();}
});
