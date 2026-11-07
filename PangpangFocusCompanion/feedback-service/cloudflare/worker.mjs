const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const fail = (status, message) => Object.assign(new Error(message), {status});
const encoder = new TextEncoder();
const hex = buffer => Array.from(new Uint8Array(buffer), x=>x.toString(16).padStart(2,'0')).join('');
const hash = async text => hex(await crypto.subtle.digest('SHA-256',encoder.encode(text)));
const json = (status,value,headers={}) => new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json; charset=utf-8',...headers}});
const cookie = (token,age) => `pang_session=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${age}`;
const validText = (value,max) => typeof value==='string' && Array.from(value).length<=max && !value.includes('\0');
async function body(request) {
  if (!request.headers.get('Content-Type')?.toLowerCase().startsWith('application/json')) throw fail(415,'需要JSON格式');
  if (Number(request.headers.get('Content-Length'))>16384) throw fail(413,'内容过长');
  const reader=request.body?.getReader();
  if (!reader) throw fail(400,'无效的JSON');
  const chunks=[]; let length=0;
  for (;;) {
    const {done,value}=await reader.read(); if(done) break;
    length+=value.length;
    if(length>16384) { await reader.cancel(); throw fail(413,'内容过长'); }
    chunks.push(value);
  }
  const data=new Uint8Array(length); let offset=0;
  for(const chunk of chunks){data.set(chunk,offset);offset+=chunk.length;}
  try {return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(data));} catch {throw fail(400,'无效的JSON');}
}
async function rate(request,env,scope,max,window) {
  const now=Date.now(), bucket=Math.floor(now/window);
  // The platform supplies CF-Connecting-IP. Never trust a client-supplied X-Forwarded-For.
  // Daily rotating HMAC key prevents retaining a stable address identifier.
  const signingKey=await crypto.subtle.importKey('raw',encoder.encode(env.ADMIN_PASSWORD),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const key=hex(await crypto.subtle.sign('HMAC',signingKey,encoder.encode(`${scope}:${bucket}:${request.headers.get('CF-Connecting-IP')||'unknown'}`)));
  const row=await env.DB.prepare('INSERT INTO rate_limits(key,count,expires_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1 RETURNING count').bind(key,(bucket+1)*window).first();
  if(row.count>max) throw fail(429,'提交过于频繁，请稍后重试');
}
function sameOrigin(request) {
  if(request.headers.get('Origin')!==new URL(request.url).origin) throw fail(403,'请求来源不允许');
}
async function admin(request,env) {
  const token=request.headers.get('Cookie')?.split(';').map(x=>x.trim()).find(x=>x.startsWith('pang_session='))?.slice(13);
  if(!token || !/^[0-9a-f]{64}$/.test(token)) throw fail(401,'请先登录');
  // Password rotation invalidates existing sessions even when database is retained.
  const tokenHash=await hash(env.ADMIN_PASSWORD+token);
  const row=await env.DB.prepare('SELECT expires_at FROM sessions WHERE token_hash=?').bind(tokenHash).first();
  if(!row || row.expires_at<=Date.now()) throw fail(401,'请先登录');
  return tokenHash;
}
export async function cleanup(env) {
  const now=Date.now();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM feedback WHERE created_at<?').bind(now-180*86400000),
    env.DB.prepare('DELETE FROM sessions WHERE expires_at<=?').bind(now),
    env.DB.prepare('DELETE FROM rate_limits WHERE expires_at<=?').bind(now)
  ]);
}
async function route(request,env) {
  const url=new URL(request.url), path=url.pathname;
  if(request.method==='GET' && ['/','/admin','/admin.html','/admin.css','/admin.js','/support','/privacy'].includes(path)) {
    if(path==='/'||path==='/admin') url.pathname='/admin.html';
    if(path==='/support') url.pathname='/support.html';
    if(path==='/privacy') url.pathname='/privacy.txt';
    return env.ASSETS.fetch(new Request(url,request));
  }
  if(request.method==='GET' && path==='/health') return json(200,{ok:true});
  if(typeof env.ADMIN_PASSWORD!=='string'||env.ADMIN_PASSWORD.length<32||!env.DB) throw fail(503,'反馈服务正在准备中');
  if(request.method==='POST' && path==='/api/feedback') {
    if(request.headers.has('Origin')) sameOrigin(request);
    await rate(request,env,'requests',60,3600000);
    const data=await body(request);
    if(!data||typeof data!=='object'||Array.isArray(data)) throw fail(400,'无效的反馈');
    const {id,category,content,contact='',appVersion=null,systemVersion=null}=data;
    if(typeof id!=='string'||!uuid.test(id)||!['使用问题','功能建议','其他'].includes(category)||!validText(content,2000)||!content.trim()||!validText(contact,200)||(appVersion!==null&&!validText(appVersion,100))||(systemVersion!==null&&!validText(systemVersion,100))||Object.keys(data).some(k=>!['id','category','content','contact','appVersion','systemVersion'].includes(k))) throw fail(400,'请检查反馈类型、内容及字数');
    const normalized=[category,content.trim(),contact.trim(),appVersion,systemVersion],payloadHash=await hash(JSON.stringify(normalized));
    const prior=await env.DB.prepare('SELECT payload_hash FROM feedback WHERE id=?').bind(id).first();
    if(prior) {if(prior.payload_hash!==payloadHash) throw fail(409,'提交编号冲突，请修改后重试');return json(200,{id,accepted:true});}
    await rate(request,env,'new-feedback',10,3600000);
    const result=await env.DB.prepare('INSERT INTO feedback(id,payload_hash,category,content,contact,app_version,system_version,created_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING').bind(id,payloadHash,...normalized,Date.now()).run();
    if(!result.meta.changes) {
      const inserted=await env.DB.prepare('SELECT payload_hash FROM feedback WHERE id=?').bind(id).first();
      if(inserted?.payload_hash!==payloadHash) throw fail(409,'提交编号冲突，请修改后重试');
    }
    return json(result.meta.changes?201:200,{id,accepted:true});
  }
  if(request.method==='POST' && path==='/api/admin/login') {
    sameOrigin(request); await rate(request,env,'login',5,900000);
    const data=await body(request), supplied=await hash(typeof data?.password==='string'?data.password:''),expected=await hash(env.ADMIN_PASSWORD);
    let difference=0;for(let i=0;i<expected.length;i++) difference|=expected.charCodeAt(i)^supplied.charCodeAt(i);
    if(difference!==0) throw fail(401,'密码不正确');
    const token=hex(crypto.getRandomValues(new Uint8Array(32)));
    await env.DB.prepare('INSERT INTO sessions(token_hash,expires_at) VALUES(?,?)').bind(await hash(env.ADMIN_PASSWORD+token),Date.now()+8*3600000).run();
    return json(200,{ok:true},{'Set-Cookie':cookie(token,8*3600)});
  }
  if(path.startsWith('/api/admin/')) {
    const tokenHash=await admin(request,env);
    if(request.method!=='GET') sameOrigin(request);
    if(request.method==='POST'&&path==='/api/admin/logout') {
      await env.DB.prepare('DELETE FROM sessions WHERE token_hash=?').bind(tokenHash).run();
      return json(200,{ok:true},{'Set-Cookie':cookie('',0)});
    }
    if(request.method==='GET'&&path==='/api/admin/feedback') {
      const offset=Number(url.searchParams.get('offset')||0);
      if(!Number.isSafeInteger(offset)||offset<0||offset>100000) throw fail(400,'无效页码');
      const {results}=await env.DB.prepare('SELECT id,category,content,contact,app_version AS appVersion,system_version AS systemVersion,created_at AS createdAt,status FROM feedback WHERE created_at>=? ORDER BY created_at DESC,id LIMIT 51 OFFSET ?').bind(Date.now()-180*86400000,offset).all();
      return json(200,{rows:results.slice(0,50),hasMore:results.length>50});
    }
    const match=path.match(/^\/api\/admin\/feedback\/([0-9a-f-]{36})$/);
    if(match&&['PATCH','DELETE'].includes(request.method)) {
      let result;
      if(request.method==='PATCH') {
        const data=await body(request);if(!['new','done'].includes(data?.status)) throw fail(400,'无效状态');
        result=await env.DB.prepare('UPDATE feedback SET status=? WHERE id=?').bind(data.status,match[1]).run();
      } else result=await env.DB.prepare('DELETE FROM feedback WHERE id=?').bind(match[1]).run();
      if(!result.meta.changes) throw fail(404,'反馈不存在');
      return json(200,{ok:true});
    }
  }
  throw fail(404,'页面不存在');
}
export default {
  async fetch(request,env) {
    let response;
    try {response=await route(request,env);} catch(error) {response=json(error.status||500,{error:error.status?error.message:'服务暂时不可用，请稍后重试'},error.status===429?{'Retry-After':'900'}:{});}
    const headers=new Headers(response.headers);
    for(const [key,value] of Object.entries({'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY','Strict-Transport-Security':'max-age=31536000','Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"})) headers.set(key,value);
    return new Response(response.body,{status:response.status,headers});
  },
  async scheduled(event,env) {await cleanup(env);}
};
