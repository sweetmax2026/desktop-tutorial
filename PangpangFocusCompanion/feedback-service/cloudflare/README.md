# Cloudflare部署

此目录为Workers＋D1适配版，不依赖本机Node服务器或在线Mac。2026-11-05已上线：https://pang-feedback.maxwithcoconut.workers.dev ，管理入口`/admin`，支持`/support`，政策`/privacy`。真实SQLite的handler测试、Wrangler打包、D1迁移及Swift HTTPS提交/后台读取/去重/状态/删除联调通过；合成反馈已清理。数据库ID见wrangler.jsonc，后续更新直接复用，不重复创建。

当前管理密码在本目录被忽略的`.admin.env`，仅本机账户可读；Cloudflare中为ADMIN_PASSWORD Secret，不在客户端或公开资产中。用户登录时复制等号后的值；不要提交这个文件。恢复窗口按D1 Free为7天，来源：https://developers.cloudflare.com/d1/reference/time-travel/ 。服务保持Free方案。

1. 上层目录安装依赖，执行 `node cloudflare/prepare-assets.mjs`。公开资产仅包含管理页HTML、CSS、JS，不含配置、凭证或数据库。
2. `npx wrangler login` 发起官方OAuth授权，由账户持有人在浏览器核对并允许。不复制浏览器会话Cookie，不手动索取全局API key。
3. 在本目录执行 `npx wrangler d1 create pang-feedback`，将返回的真实绑定加入 `wrangler.jsonc` 的 `d1_databases`，binding为`DB`，migrations_dir为`migrations`。没有真实ID前不填占位值。
4. `npx wrangler d1 migrations apply pang-feedback --remote` 创建反馈、登录会话与限流表。
5. `npx wrangler secret put ADMIN_PASSWORD` 设置至少32字符管理密码，仅作为Worker Secret。不得写入普通vars、客户端或源码。账户持有人保留密码。
6. `npx wrangler deploy --dry-run` 验证打包，然后 `npx wrangler deploy`。只使用Free计划，不订阅付费服务。若创建workers.dev子域需要接受条款或出现付费提示，由用户处理。
7. 使用部署工具返回的真实HTTPS地址联调，未登录的管理API必须401，合成反馈必须能查看、修改状态并删除；重复提交不得重复存储。确认后才将接口地址写入App，构建并保留计时状态安装。

线上采用D1共享限流，跨Worker实例生效。基于平台CF-Connecting-IP的HMAC计数按小时窗口轮换；不保存原始IP，过期计数和会话由每日定时任务清理（最迟约25小时）。新反馈每地址每小时10条、请求60次；登录每15分钟5次。限流不是用户身份验证，轮换地址仍可绕过，应监控数据库配额并在需要时加平台层保护。

管理会话只存token hash，有效期8小时；更换管理密码使旧会话失效。每日UTC 03:17清理180天前反馈、过期会话及限流表。列表额外过滤180天前反馈，避免清理任务迟延时仍可查看。清理只能删除主表；D1自动恢复副本的保留期与Cloudflare基础设施日志需在正式开放前核实，写入隐私政策。Worker不记录正文、联系方式、密码、Cookie或IP；observability默认关闭。

测试：`node --test cloudflare/worker.test.mjs`。该测试验证业务逻辑与真实SQLite SQL，不等同于真实D1部署测试。最终仍需Cloudflare dry-run、D1迁移和HTTPS联调。
