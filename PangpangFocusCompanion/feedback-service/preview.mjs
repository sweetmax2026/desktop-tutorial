// Isolated UI demonstration. Synthetic content only; not for collecting real feedback.
import { createFeedbackService } from './server.mjs';
import { randomUUID } from 'node:crypto';
const server = createFeedbackService({password:'local-preview-password-for-ui-testing-only',origin:'http://127.0.0.1:8788',dbPath:':memory:'});
server.listen(8788,'127.0.0.1',async () => {
  const response = await fetch('http://127.0.0.1:8788/api/feedback',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:randomUUID(),category:'功能建议',content:'【合成演示】希望能在专注结束后快速记录本轮成果。\n这条反馈只用于管理界面检查，不来自真实用户。',contact:'',appVersion:'1.2.9 (43)',systemVersion:'演示'})});
  if (!response.ok) throw Error('Demo seed failed');
  console.log('Synthetic UI demo: http://127.0.0.1:8788/admin');
});
