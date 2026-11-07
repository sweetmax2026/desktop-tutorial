# Mac App Store 沙盒准备与实测

2026-11-04。当前结论：基础配置和核心守护运行验证通过，尚未完成商店分发签名、完整界面验收和旧数据迁移。不是提审完成证明。

2026-11-05发布验收更新：独立Probe/Fixture复测PASS，证据在`build/sandbox-check-lqGD2g/`。反馈服务增加的出站网络client权限已在entitlements中声明；下方“没有添加网络”是早期阶段记录。完整应用的拒绝通知、首次启动、关闭窗口与退出重开测试使用独立非沙盒验收宿主，不据此声称完整沙盒UI链路已通过。详见`release-acceptance-2026-11-05.md`。

## 独立构建

- Xcode配置：SandboxPreview，独立bundle ID为com.tiantian.pangpang.sandbox-preview，独立数据容器。Debug/Release及正式安装包保持原样。
- 命令行：`zsh scripts/build-app.sh --sandbox`，产物为`build/Pang Sandbox Preview.app`。
- Xcode：选择SandboxPreview configuration，或运行`xcodebuild -project PangpangDesktopPet.xcodeproj -target PangpangDesktopPet -configuration SandboxPreview -sdk macosx build`。
- 两条构建路径均已成功，实际产物已验证签名和沙盒entitlements。仍是本地ad hoc签名，不是App Store分发签名。
- 功能权限包含App Sandbox、用户选择文件只读、应用级security-scoped bookmarks；没有添加网络、Apple Events、辅助功能或临时例外权限。Xcode开发配置另自动附加get-task-allow调试标记，最终商店分发包需关闭；它不是商店发布配置。
- App选择器继续使用NSOpenPanel。新增可选bookmark字段，用户授权选择后保存只读书签，读取图标时解析并成对开启/关闭访问。旧列表缺少bookmark仍可解码；没有通过扩大权限来绕过文件访问限制。

## 真实沙盒运行验证

执行`zsh scripts/check-sandbox.sh`。使用独立随机bundle ID的沙盒Probe和20秒后自动退出的Fixture测试窗口，不启动真实番茄或操作用户软件。

| 项目 | 结果 |
|---|---|
| 进程实际拥有App Sandbox entitlement | PASS |
| 容器外测试文件访问被拒绝，确认限制实际生效 | PASS |
| 真实Fixture应用首次隐藏 | PASS |
| Fixture自行unhide后再次被隐藏 | PASS |
| 休息阶段停止拦截、Fixture可以重新显示 | PASS |
| 下一轮专注重新隐藏Fixture | PASS |
| 关闭守护后停止拦截 | PASS |
| RegisterEventHotKey在沙盒进程内注册成功 | PASS |
| 任务和40分钟设置跨进程重启保存 | PASS |
| 活动计时截止时间跨进程重启保持 | PASS |

守护测试调用真实AppBlockerStore和NSRunningApplication的隐藏路径。测试环境只枚举本次Fixture，避免操作用户其他应用。快捷键验证使用独立的Control+Option+Shift+F19，不抢占正式应用的Control+Option+P；这里只证明注册API可用，不等同于主界面快捷键整条交互已验收。

本次日志：`build/sandbox-check-sLBZlT/runtime.log`、`relaunch.log`，两次RESULT均为PASS，错误日志为空。日志不含用户任务或记录。

完整`scripts/check-focus-flow.sh`通过，包括计时、自动循环、任务恢复、旧列表解码路径、App守护模拟检查和统计检查；原生预览编译通过。

## 尚未验证与交付边界

1. 手动通过NSOpenPanel选择容器外App，重启后读取书签和图标、App移动后书签处理，仍需真实界面验收。本次运行测试没有模拟用户授予文件权限，不能据此声称跨容器书签授权已通过。
2. 完整沙盒主程序的通知授权、系统通知送达、菜单栏、浮窗和全局快捷键触发，仍需界面验收。当前会话没有可用的原生UI操作工具，未启动一份会与正式版争用快捷键/弹通知的新实例。
3. 旧版本UserDefaults和任务/情绪/冥想数据迁移尚未实施。独立bundle验证不代表同bundle切换沙盒后能自动继承旧数据；正式切换前必须设计备份/迁移并核对。
4. App Store正式Team、签名、provisioning、隐私清单、Archive/Validate/TestFlight尚未完成。没有将沙盒成功视为审核保证。
5. 没有替换或重启正式应用。正式安装可执行文件与原普通构建逐字节一致；没有读取、导出或修改正式偏好数据。本轮未推送远端。
