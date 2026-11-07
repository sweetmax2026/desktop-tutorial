# Pang 大师反馈服务

用户通过 `POST /api/feedback` 匿名提交；开发者在 `/admin` 输入管理密码后查看、标记已处理或删除。无邮件通知。线上服务已部署到 https://pang-feedback.maxwithcoconut.workers.dev ，使用Cloudflare Workers＋D1，不依赖本机持续运行。保留的本地Node版本无第三方运行时依赖，需要Node.js 24或更新版本及持久磁盘上的SQLite数据文件。

Cloudflare方案位于[cloudflare目录](cloudflare/README.md)，管理页面与Mac接口契约一致。已完成官方授权、数据库迁移、部署和真实Swift HTTPS联调；后台Secret不在App中。下面是保留的本机Node版本运行说明。

## 本机运行

在本目录执行：

```sh
node setup.mjs
npm start
```

打开 http://127.0.0.1:8787/admin 。管理密码位于本目录 `.env` 的 `ADMIN_PASSWORD`；该文件仅限本机账户读取，不提交、不打包进App。`setup.mjs` 不覆盖已有配置。停止进程用 Ctrl+C；它不是长期在线服务。

## 部署到自己的服务器

1. 安装 Node.js 24+，只复制本服务源码，不复制用户数据、`.env`、本机备份或整个项目目录。
2. 用专用非管理员系统账户运行，执行 `node setup.mjs` 生成独立管理密码。配置 `PUBLIC_ORIGIN=https://实际域名`，`DB_PATH` 指向可写持久磁盘路径。不要使用临时文件系统。
3. 在HTTPS反向代理后运行，绑定 `127.0.0.1:8787`；对外仅开放443。反向代理必须覆盖 `X-Forwarded-For`，然后设置 `TRUST_PROXY=1`。代理层限制请求体16KB、请求超时15秒；不要记录请求正文、Cookie或密码，关闭或明确限制含IP的访问日志。下面提供Caddy配置示例。
4. 用进程管理器设置自动重启和开机运行。管理密码至少32字符，建议用生成的随机密码。丢失密码可更新服务器 `.env` 并重启，所有会话随重启失效。
5. 对数据库做受限、加密的定期备份，明确备份轮换期。在线SQLite备份使用SQLite backup API或 `.backup`；不要仅复制运行中的主文件而忽略WAL。恢复后检查 `/health` 和管理登录。
6. 执行 `npm test`，然后在真实HTTPS地址提交明确的合成反馈，核对管理页可见、重复提交去重、未登录401、处理状态与删除。测试后删除合成反馈。
7. 将实际HTTPS接口地址写到Mac项目的 `PangFeedbackURL`（Info.plist、SandboxPreview-Info.plist；独立预览配置按需）。无需也不得把管理密码放入App。补齐隐私政策里的托管方、基础设施日志、备份保留期、公开支持与政策URL，再构建和更新正式App。

```caddyfile
feedback.your-domain.example {
    request_body {
        max_size 16KB
    }
    reverse_proxy 127.0.0.1:8787 {
        header_up X-Forwarded-For {remote_host}
    }
}
```

这里的域名是示例，不是已部署地址。不要把本机HTTP地址配置给正式App。Cloudflare Workers不能直接运行这个Node/SQLite进程；选择Cloudflare时使用cloudflare目录中的适配版，完成真实部署验证。

## 接口与保护

```json
{
  "id": "客户端生成的UUID v4，同一次提交重试不变",
  "category": "使用问题",
  "content": "问题或建议，最多2000个Unicode code point",
  "contact": "选填，最多200个Unicode code point",
  "appVersion": "选填",
  "systemVersion": "选填"
}
```

成功返回 `201 {"id":"...","accepted":true}`；相同编号且相同内容返回200，不产生重复记录；同编号不同内容409。类型仅允许使用问题、功能建议、其他。版本各限100字符，不接受额外字段；JSON请求体限16KB。400为参数错误，429为过频，5xx为服务错误。客户端遇到超时或失败不清空内容，用同一编号重试。

匿名提交不是身份验证，攻击者仍可通过轮换地址绕过单地址限制。当前每地址每小时最多10条新反馈及60次请求，登录每15分钟最多5次；计数为内存中的加盐地址散列，重启清空。上线后按真实流量评估代理层限流与防滥用措施，不用App内共享密钥伪装用户身份。

管理页面和静态文件可访问，但数据接口需8小时有效的HttpOnly、SameSite=Strict会话，HTTPS时加Secure；写操作还检查Origin。管理密码只存在服务器环境中。页面用textContent渲染用户输入，数据库使用绑定参数。无反馈正文、联系方式或原始IP的应用日志。180天后定时删除主数据库记录；备份需独立轮换。反馈编号不是身份凭据，查阅/删除请求需人工核验，不能凭编号泄露内容。

## 验证

`npm test` 使用独立临时数据库和合成反馈，覆盖持久化、未登录访问、CSRF、去重、字数校验、状态、删除、保留期和限流，不读取正式App数据。Mac侧 `zsh scripts/check-focus-flow.sh` 包含HTTPS端点校验、最小提交字段、错误及离线保留草稿、响应编号验证等检查。
