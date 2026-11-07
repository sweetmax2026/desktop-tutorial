import http from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { randomBytes, createHash, timingSafeEqual } from 'node:crypto';
import { mkdirSync, chmodSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const categories = new Set(['使用问题', '功能建议', '其他']);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const digest = value => createHash('sha256').update(value).digest('hex');
const fail = (status, message) => Object.assign(new Error(message), { status });
const length = value => Array.from(value).length;

export function createFeedbackService({ password, origin, dbPath, trustProxy = false, now = Date.now }) {
  if (typeof password !== 'string' || password.length < 32) throw new Error('ADMIN_PASSWORD must have at least 32 characters');
  const publicURL = new URL(origin);
  const local = ['127.0.0.1', 'localhost', '[::1]'].includes(publicURL.hostname);
  if (publicURL.origin !== origin || (publicURL.protocol !== 'https:' && !(local && publicURL.protocol === 'http:'))) throw new Error('PUBLIC_ORIGIN must be an HTTPS origin (HTTP allowed on localhost only)');
  if (dbPath !== ':memory:') { mkdirSync(dirname(resolve(dbPath)), { recursive: true, mode: 0o700 }); }
  const db = new DatabaseSync(dbPath);
  if (dbPath !== ':memory:') chmodSync(dbPath, 0o600);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS feedback (
      id TEXT PRIMARY KEY, payload_hash TEXT NOT NULL, category TEXT NOT NULL,
      content TEXT NOT NULL, contact TEXT NOT NULL, app_version TEXT,
      system_version TEXT, created_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'new'
    ); CREATE INDEX IF NOT EXISTS feedback_created ON feedback(created_at DESC);`);
  const adminHash = digest(password), salt = randomBytes(32).toString('hex');
  const sessions = new Map(), limits = new Map();
  let lastPrune = -Infinity;
  function prune() {
    if (now() - lastPrune < 60_000) return;
    lastPrune = now();
    db.prepare('DELETE FROM feedback WHERE created_at < ?').run(now() - 180 * 86400_000);
    for (const [key, value] of sessions) if (value < now()) sessions.delete(key);
    for (const [key, value] of limits) if (value.until <= now()) limits.delete(key);
  }
  function rate(req, scope, max, windowMs) {
    const address = trustProxy ? String(req.headers['x-forwarded-for'] || req.socket.remoteAddress).split(',')[0].trim() : req.socket.remoteAddress;
    const key = digest(salt + scope + address), previous = limits.get(key);
    const value = previous && previous.until > now() ? previous : { count: 0, until: now() + windowMs };
    // Bound memory even if many different addresses attack the service.
    if (!previous && limits.size >= 10000) throw fail(429, '服务繁忙，请稍后重试');
    limits.set(key, value);
    if (++value.count > max) throw fail(429, '提交过于频繁，请稍后重试');
  }
  async function body(req) {
    if (!String(req.headers['content-type'] || '').toLowerCase().startsWith('application/json')) throw fail(415, '需要JSON格式');
    if (Number(req.headers['content-length']) > 16384) throw fail(413, '内容过长');
    let size = 0, chunks = [];
    for await (const chunk of req) { size += chunk.length; if (size > 16384) throw fail(413, '内容过长'); chunks.push(chunk); }
    try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw fail(400, '无效的JSON'); }
  }
  function sameOrigin(req) {
    if (req.headers.origin !== origin) throw fail(403, '请求来源不允许');
  }
  function admin(req) {
    const token = String(req.headers.cookie || '').split(';').map(x => x.trim()).find(x => x.startsWith('pang_session='))?.slice(13);
    if (!token || (sessions.get(digest(token)) || 0) <= now()) throw fail(401, '请先登录');
    return digest(token);
  }
  const cookie = (token, age) => `pang_session=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${age}${publicURL.protocol === 'https:' ? '; Secure' : ''}`;
  const html = readFileSync(new URL('./admin.html', import.meta.url), 'utf8');
  const script = readFileSync(new URL('./admin.js', import.meta.url), 'utf8');
  const style = readFileSync(new URL('./admin.css', import.meta.url), 'utf8');
  const server = http.createServer(async (req, res) => {
    const reply = (status, value, headers = {}) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', ...headers });
      res.end(JSON.stringify(value));
    };
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
    if (publicURL.protocol === 'https:') res.setHeader('Strict-Transport-Security', 'max-age=31536000');
    try {
      prune();
      const url = new URL(req.url, origin), path = url.pathname;
      if (req.method === 'GET' && path === '/health') return reply(200, { ok: true });
      if (req.method === 'GET' && ['/', '/admin', '/admin.js', '/admin.css'].includes(path)) {
        const asset = path.endsWith('.js') ? [script, 'text/javascript'] : path.endsWith('.css') ? [style, 'text/css'] : [html, 'text/html'];
        res.writeHead(200, { 'Content-Type': asset[1] + '; charset=utf-8' }); return res.end(asset[0]);
      }
      if (req.method === 'POST' && path === '/api/feedback') {
        // Native clients have no Origin; browsers may only submit from this site.
        if (req.headers.origin && req.headers.origin !== origin) throw fail(403, '请求来源不允许');
        rate(req, 'requests', 60, 3600_000);
        const data = await body(req);
        if (!data || typeof data !== 'object' || Array.isArray(data)) throw fail(400, '无效的反馈');
        const { id, category, content, contact = '', appVersion = null, systemVersion = null } = data;
        const validText = (value, max) => typeof value === 'string' && length(value) <= max && !value.includes('\u0000');
        if (typeof id !== 'string' || !uuid.test(id) || !categories.has(category) || !validText(content, 2000) || !content.trim() || !validText(contact, 200) || (appVersion !== null && !validText(appVersion, 100)) || (systemVersion !== null && !validText(systemVersion, 100))) throw fail(400, '请检查反馈类型、内容及字数');
        if (Object.keys(data).some(key => !['id','category','content','contact','appVersion','systemVersion'].includes(key))) throw fail(400, '包含不支持的字段');
        const normalized = [category, content.trim(), contact.trim(), appVersion, systemVersion];
        const hash = digest(JSON.stringify(normalized));
        const existing = db.prepare('SELECT payload_hash FROM feedback WHERE id=?').get(id);
        if (existing) {
          if (existing.payload_hash !== hash) throw fail(409, '提交编号冲突，请重新提交');
          return reply(200, { id, accepted: true });
        }
        rate(req, 'new-feedback', 10, 3600_000);
        db.prepare('INSERT INTO feedback(id,payload_hash,category,content,contact,app_version,system_version,created_at) VALUES(?,?,?,?,?,?,?,?)').run(id, hash, ...normalized, now());
        return reply(201, { id, accepted: true });
      }
      if (req.method === 'POST' && path === '/api/admin/login') {
        sameOrigin(req); rate(req, 'login', 5, 15 * 60_000);
        const data = await body(req);
        const candidate = digest(typeof data?.password === 'string' ? data.password : '');
        if (!timingSafeEqual(Buffer.from(candidate), Buffer.from(adminHash))) throw fail(401, '密码不正确');
        if (sessions.size >= 100) throw fail(429, '登录会话过多，请稍后重试');
        const token = randomBytes(32).toString('base64url');
        sessions.set(digest(token), now() + 8 * 3600_000);
        return reply(200, { ok: true }, { 'Set-Cookie': cookie(token, 8 * 3600) });
      }
      if (path.startsWith('/api/admin/')) {
        const session = admin(req);
        if (req.method !== 'GET') sameOrigin(req);
        if (req.method === 'POST' && path === '/api/admin/logout') {
          sessions.delete(session); return reply(200, { ok: true }, { 'Set-Cookie': cookie('', 0) });
        }
        if (req.method === 'GET' && path === '/api/admin/feedback') {
          const offset = Number(url.searchParams.get('offset') || 0);
          if (!Number.isSafeInteger(offset) || offset < 0) throw fail(400, '无效页码');
          const rows = db.prepare('SELECT id,category,content,contact,app_version AS appVersion,system_version AS systemVersion,created_at AS createdAt,status FROM feedback ORDER BY created_at DESC,id LIMIT 51 OFFSET ?').all(offset);
          return reply(200, { rows: rows.slice(0, 50), hasMore: rows.length > 50 });
        }
        const match = path.match(/^\/api\/admin\/feedback\/([0-9a-f-]{36})$/i);
        if (match && req.method === 'PATCH') {
          const data = await body(req);
          if (!['new','done'].includes(data?.status)) throw fail(400, '无效状态');
          const result = db.prepare('UPDATE feedback SET status=? WHERE id=?').run(data.status, match[1]);
          if (!result.changes) throw fail(404, '反馈不存在');
          return reply(200, { ok: true });
        }
        if (match && req.method === 'DELETE') {
          const result = db.prepare('DELETE FROM feedback WHERE id=?').run(match[1]);
          if (!result.changes) throw fail(404, '反馈不存在');
          return reply(200, { ok: true });
        }
      }
      throw fail(404, '页面不存在');
    } catch (error) {
      // Never log request body, contact, IP, cookies, passwords or SQLite error details.
      if (!res.headersSent) reply(error.status || 500, { error: error.status ? error.message : '服务暂时不可用，请稍后重试' }, error.status === 429 ? { 'Retry-After': '900' } : {});
      else res.end();
    }
  });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  server.keepAliveTimeout = 5000;
  server.maxHeadersCount = 40;
  const cleanupTimer = setInterval(prune, 60_000).unref();
  server.on('close', () => { clearInterval(cleanupTimer); db.close(); });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.umask(0o077);
  const server = createFeedbackService({ password: process.env.ADMIN_PASSWORD, origin: process.env.PUBLIC_ORIGIN || 'http://127.0.0.1:8787', dbPath: process.env.DB_PATH || './data/feedback.sqlite', trustProxy: process.env.TRUST_PROXY === '1' });
  server.listen(Number(process.env.PORT || 8787), process.env.HOST || '127.0.0.1', () => console.log('Feedback service ready (no request body logging)'));
  for (const signal of ['SIGTERM','SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
}
