import { randomBytes } from 'node:crypto';
import { writeFileSync } from 'node:fs';
const password = randomBytes(32).toString('base64url');
try {
  writeFileSync(new URL('./.env', import.meta.url), `ADMIN_PASSWORD=${password}\nPUBLIC_ORIGIN=http://127.0.0.1:8787\nHOST=127.0.0.1\nPORT=8787\nDB_PATH=./data/feedback.sqlite\nTRUST_PROXY=0\n`, {mode:0o600,flag:'wx'});
  console.log('本机配置已生成。管理密码在 .env 中；未输出密码，未启动或公开服务。');
} catch(error) {
  if (error.code === 'EEXIST') console.log('已有 .env，保留原配置。');
  else throw error;
}
