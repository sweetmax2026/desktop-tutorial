// The password is generated locally, kept in an ignored owner-readable file,
// and sent to Wrangler over stdin. Never emit it or pass it in process arguments.
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const file=new URL('./.admin.env',import.meta.url);
try {writeFileSync(file,`ADMIN_PASSWORD=${randomBytes(32).toString('base64url')}\n`,{mode:0o600,flag:'wx'});} catch(error) {if(error.code!=='EEXIST')throw error;}
const value=readFileSync(file,'utf8').trim().replace(/^ADMIN_PASSWORD=/,'');
if(!/^[A-Za-z0-9_-]{43}$/.test(value)) throw Error('Unexpected admin password format; no change sent');
const result=spawnSync(process.execPath,['../node_modules/wrangler/bin/wrangler.js','secret','put','ADMIN_PASSWORD'],{cwd:new URL('.',import.meta.url),env:{...process.env,WRANGLER_SEND_METRICS:'false'},input:value+'\n',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
process.exitCode=result.status??1;
