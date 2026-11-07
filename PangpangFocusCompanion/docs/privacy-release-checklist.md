# 隐私发布检查

2026-11-05 v1.2.10/build44：在线反馈已部署到Cloudflare Workers＋D1并接入安装版；公开支持`/support`和政策`/privacy`已可访问。政策现说明Cloudflare处理、APAC数据库位置及可能跨境、D1 Free 7天自动恢复副本、散列计数最迟约25小时清理、管理会话8小时和反馈180天。未启用Worker observability，无邮件通知。真实Swift提交、后台授权读取、状态及合成数据清理通过；178条记录与全部应用持久键安装前后摘要一致。下方未发布阶段记录为历史状态。

2026-11-05未发布源码：反馈已改为HTTPS接口＋SQLite持久存储，不再打开邮件草稿或包含个人收件邮箱。服务端仅开发者登录查看，保留180天，支持人工核验后的查阅/删除；App失败保留草稿。隐私清单继续保守声明用户主动填写的联系方式、客服内容和可选版本信息。当前尚无线上托管地址；开放前必须确认托管方、代理日志、备份保留期和公开支持/政策URL。安装版仍为下述v1.2.9，本次未替换。

2026-11-04历史更新：v1.2.9当时增加主动邮件反馈，后由v1.2.10的应用内接口替代。隐私清单声明邮件地址、其他联系方式、客服反馈内容和可选版本诊断信息，仅用于AppFunctionality、不追踪；此前空收集列表及“不收集”的结论已被该实现取代。当时反馈由用户在邮件应用确认发送。当前公开政策和服务状态见本页顶部及会话交接，不再使用个人收件邮箱。

2026-11-04，v1.2.6/build40。

## 当前实现

应用内“设置 → 隐私与数据”提供完整离线政策。政策源文为`Resources/PrivacyPolicy.txt`；没有伪造公开网址、联系邮箱或开发者主体。

分类删除包含专注记录及笔记、心情及文字、冥想完成日期、保存的任务与选择、守护名单及文件访问书签。按钮先打开确认弹窗，取消不执行删除，确认后无法在应用内恢复。有正在进行的计时或冥想时禁用，并在确认回调再次检查。不同类型的数据不会相互清空；时长设置与冥想提醒时间保留。

已经取消心情100条、冥想365次及专注完成日期365次的数量截断。此前版本已经丢弃的数据不能恢复。系统通知、系统日志、系统备份不受应用内删除控制，政策已说明。

## 隐私清单

`Resources/PrivacyInfo.xcprivacy`由命令行构建和Xcode资源阶段打包至macOS应用的Contents/Resources。

- UserDefaults，CA92.1：保存本应用记录与设置，不访问其他应用偏好。
- SystemBootTime，35F9.1：ProcessInfo.systemUptime用于长按和窗口事件间隔，不上传设备计时信息。
- NSPrivacyTracking为false，不声明追踪域；NSPrivacyCollectedDataTypes为空。该声明以当前无上传代码、无第三方分析SDK的实现为依据，不替代最终提交包核对。

理由依据：[Apple required reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)；[Apple清单校验说明](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest)。

## 验证结果与边界

- PrivacyChecks及全部既有回归通过；使用独立随机数据域，不读取或清空正式偏好。
- 原生预览编译通过，Tests菜单Cmd+P可进入示例隐私页；没有在真实应用上测试删除。
- Xcode独立SandboxPreview构建和签名检查通过；政策和清单与源码逐字节一致，plist格式及声明结构检查通过。
- 本轮无原生UI操作工具，实际按钮点击、取消、键盘焦点、滚动和政策弹窗布局尚需实机验收，未以编译通过替代这些检查。
- 没有覆盖正式安装。独立测试包为`build/Pang Sandbox Preview.app`。正式签名、上传及旧数据迁入沙盒仍按此前约定暂缓/待处理。

## 正式发布前待补

1. 确认开发者对外主体和有效联系渠道，补入政策。
2. 将政策发布到稳定公开地址，填写App Store Connect，并按最终网址增加应用内在线访问入口。离线政策继续保留。
3. 根据最终提交包核对隐私标签；当前实现支持“不收集数据”的方向，增加任何联网、诊断上传或第三方SDK后必须重新评估。
4. 在独立测试数据中逐项完成政策阅读、删除确认/取消、活动计时保护和重启后的验收。
5. 对正式用户记录做迁移备份和数量/摘要核对；不得用正式数据执行删除测试。
