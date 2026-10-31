import AppKit
import SwiftUI

private final class PreviewHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = []
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

// Standalone UI test host. Each launch uses a disposable domain, never user records.
@main
@MainActor
enum FocusSurfacePreview {
    static var retainedDelegate: PreviewDelegate?
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = PreviewDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private let suite = "pangpang.test.surface.\(UUID().uuidString)"
    private var defaults: UserDefaults!
    private var clock = Date()
    private var store: PomodoroStore!
    private var window: NSWindow!
    private var wellbeing: WellbeingStore!
    private var blocker: AppBlockerStore!
    private var completionPanel: NSPanel?
    private var guardProbe: AppBlockerStore?
    private var guardProbeDefaults: UserDefaults?
    private var guardProbeSuite: String?
    private var verifiedHides = 0
    private var slowTransition = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults = UserDefaults(suiteName: suite)!
        let previewApps = [
            BlockedApplication(bundleIdentifier: "com.seagroup.seatalkmac.enterprise", name: "SeaTalk", path: "/Applications/SeaTalk.app"),
            BlockedApplication(bundleIdentifier: "com.tencent.xinWeChat", name: "WeChat", path: "/Applications/WeChat.app")
        ]
        let snapshot: [String: Any] = ["isEnabled": true,
            "blockedApplications": previewApps.map { ["bundleIdentifier": $0.bundleIdentifier, "name": $0.name, "path": $0.path] }]
        defaults.set(try! JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        blocker = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        let day = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(try! JSONEncoder().encode([Date]()), forKey: "pangpang.meditation.completions")
        UserDefaults.standard.set(try! JSONEncoder().encode([MoodEntry]()), forKey: "pangpang.mood.entries")
        wellbeing = WellbeingStore()
        clock = Calendar.current.date(byAdding: .hour, value: 10, to: day)!
        store = PomodoroStore(defaults: defaults, now: { [unowned self] in clock }, schedulesTimer: false)
        for index in 0..<2 {
            clock = Calendar.current.date(byAdding: .hour, value: 10 + index, to: day)!
            store.draftTask = index == 0 ? "阅读一章" : "整理方案"
            store.startFocus()
            clock = clock.addingTimeInterval(1500)
            store.refreshForCurrentTime()
            store.resetToReady()
        }
        store.draftTask = "阅读一章"; store.draftCategory = "工作"
        store.startFocus()
        clock = clock.addingTimeInterval(480)
        store.refreshForCurrentTime()
        store.endCurrentSession()
        store.showsMiniCard = false
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.minSize = NSSize(width: 800, height: 600)
        window.title = "Pang 大师 · 局部设计预览"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.setFrame(NSRect(x: 0, y: 0, width: 800, height: 600), display: false)
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(red: 1, green: 0.986, blue: 0.968, alpha: 1)
        showHome()
        window.setFrame(NSRect(x: 0, y: 0, width: 800, height: 600), display: false)
        let mainMenu = NSMenu()
        let item = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = submenu
        mainMenu.addItem(item)
        let tests = NSMenuItem()
        tests.submenu = NSMenu(title: "Tests")
        for (index, pair) in [("计时前进 10 秒", #selector(advance)), ("完成专注", #selector(finish)), ("完成休息", #selector(finishBreak)), ("准备页", #selector(ready)), ("开始休息", #selector(rest)), ("数据统计页", #selector(statistics)), ("预览专注中", #selector(previewFocus)), ("预览休息中", #selector(previewRest))].enumerated() {
            let (title, selector) = pair
            let command = NSMenuItem(title: title, action: selector, keyEquivalent: "\(index + 1)")
            command.target = self
            tests.submenu?.addItem(command)
        }
        for (title, action, key) in [("慢速进入专注（仅检查动画）", #selector(slowFocusEntry), "s"),
                                      ("正常进入专注", #selector(normalFocusEntry), "n")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; tests.submenu?.addItem(item)
        }
        mainMenu.addItem(tests)
        for (title, selector, key) in [("实测 SeaTalk 管控（60 秒后自动停止）", #selector(startGuardProbe), "9"),
                                        ("停止管控实测", #selector(stopGuardProbe), "0")] {
            let command = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            command.target = self; tests.submenu?.addItem(command)
        }
        appMenuEdit(mainMenu)
        NSApp.mainMenu = mainMenu
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.onBubble = { [weak self] message in
            guard let self, message.action == .viewFocusResult else { return }
            let panel = self.completionPanel ?? NSPanel(contentRect: NSRect(origin: .zero, size: BubbleView.panelSize),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "完成提示测试"
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.level = .floating; panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.contentView = NSHostingView(rootView: BubbleView(message: message,
                onAction: { [weak self, weak panel] in panel?.orderOut(nil); self?.showHome() },
                onDismiss: { [weak panel] in panel?.orderOut(nil) }).environment(\.colorScheme, .light))
            let visible = self.window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - BubbleView.panelSize.width - 20,
                y: visible.maxY - BubbleView.panelSize.height - 16))
            self.completionPanel = panel
            let previousKeyWindow = NSApp.keyWindow
            panel.orderFrontRegardless()
            assert(NSApp.keyWindow === previousKeyWindow, "Completion card must not take keyboard focus")
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak panel] in panel?.orderOut(nil) }
        }
    }

    private func showHome() {
        window.contentView = PreviewHostingView(rootView: FocusFlowScreen(store: store, appBlocker: blocker,
            onTool: { [unowned self] tool in
                if tool == .pomodoro { showFocus() }
                else if tool == .mood { showMood() }
                else if tool == .meditation { showMeditation() }
                else if tool == .appBlocker { showGuard() }
            }, onHistory: { [unowned self] in showStats(returnToFocus: false) },
            entryDuration: slowTransition ? 6 : 0.35).environment(\.colorScheme, .light))
    }
    private func showFocus() {
        window.contentView = PreviewHostingView(rootView: FocusExperienceView(store: store, appBlocker: blocker,
            onBack: { [unowned self] in showHome() }, onClose: { [unowned self] in window.orderOut(nil) },
            onHistory: { [unowned self] in showStats(returnToFocus: true) }).environment(\.colorScheme, .light))
    }

    private func showMood() {
        window.contentView = PreviewHostingView(rootView: MoodJournalPage(wellbeing: wellbeing,
            onBack: { [unowned self] in showHome() },
            onHistory: { [unowned self] in showWellbeingStats(mood: true) }).environment(\.colorScheme, .light))
    }
    private func showGuard() {
        window.contentView = PreviewHostingView(rootView: AppGuardPage(store: blocker, pomodoro: store,
            onBack: { [unowned self] in showHome() }).environment(\.colorScheme, .light))
    }
    private func showMeditation() {
        window.contentView = PreviewHostingView(rootView: MeditationPage(wellbeing: wellbeing,
            onBack: { [unowned self] in showHome() },
            onHistory: { [unowned self] in showWellbeingStats(mood: false) }).environment(\.colorScheme, .light))
    }
    private func showWellbeingStats(mood: Bool) {
        window.contentView = PreviewHostingView(rootView: StatisticsView(pomodoro: store, wellbeing: wellbeing,
            onBack: { [unowned self] in if mood { showMood() } else { showMeditation() } },
            onClose: { [unowned self] in window.orderOut(nil) }, returnTitle: mood ? "返回心情记录" : "返回冥想",
            initialMetric: mood ? .mood : .meditation).environment(\.colorScheme, .light))
    }

    private func showStats(returnToFocus: Bool) {
        window.contentView = PreviewHostingView(rootView: StatisticsView(pomodoro: store, wellbeing: wellbeing,
            onBack: { [unowned self] in if returnToFocus { showFocus() } else { showHome() } },
            onClose: { [unowned self] in window.orderOut(nil) },
            returnTitle: returnToFocus ? "返回沉浸专注" : "返回专注").environment(\.colorScheme, .light))
    }

    private func appMenuEdit(_ menu: NSMenu) {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            item.submenu?.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        menu.addItem(item)
    }

    @objc func advance() { clock = clock.addingTimeInterval(10); store.refreshForCurrentTime() }
    @objc func slowFocusEntry() { slowTransition = true; store.endCurrentSession(); showHome() }
    @objc func normalFocusEntry() { slowTransition = false; store.endCurrentSession(); showHome() }
    @objc func finish() { clock = clock.addingTimeInterval(1500); store.refreshForCurrentTime() }
    @objc func finishBreak() { clock = clock.addingTimeInterval(300); store.refreshForCurrentTime() }
    @objc func ready() { store.resetToReady(); showHome() }
    @objc func rest() { store.startBreak() }
    @objc func statistics() { showStats(returnToFocus: false) }
    @objc func previewFocus() {
        if store.phase == .focus { showHome(); return }
        store.resetToReady(); store.startFocus(); showHome()
    }
    @objc func previewRest() {
        if store.isRestSession { showHome(); return }
        if store.phase != .focus { store.resetToReady(); store.startFocus() }
        clock = clock.addingTimeInterval(TimeInterval(store.settings.focusMinutes * 60))
        store.refreshForCurrentTime(); store.startBreak(); showHome()
    }
    @objc func startGuardProbe() {
        stopGuardProbe()
        let name = "pangpang.test.guard-probe.\(UUID().uuidString)"
        let data = UserDefaults(suiteName: name)!
        let snapshot: [String: Any] = ["isEnabled": true, "blockedApplications": [[
            "bundleIdentifier": "com.seagroup.seatalkmac.enterprise", "name": "SeaTalk", "path": "/Applications/SeaTalk.app"]]]
        data.set(try! JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        guardProbeSuite = name; guardProbeDefaults = data; verifiedHides = 0
        let probe = AppBlockerStore(defaults: data)
        guardProbe = probe
        probe.onBlockedApplication = { [weak self] _ in
            guard let self else { return }
            self.verifiedHides += 1; self.renderGuardProbe("已核实 SeaTalk 隐藏 \(self.verifiedHides) 次")
        }
        probe.onBlockFailed = { [weak self] _ in self?.renderGuardProbe("隐藏未成功，正在重试") }
        renderGuardProbe("正在验证，只检测 SeaTalk；不读取聊天")
        probe.setFocusActive(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self, weak probe] in
            guard let self, self.guardProbe === probe else { return }
            self.stopGuardProbe()
        }
    }
    private func renderGuardProbe(_ text: String) {
        window.contentView = PreviewHostingView(rootView: VStack(spacing: 24) {
            Text("独立管控实测").font(.title)
            Text(text).accessibilityIdentifier("guard.probe.result")
            Text("不启动或修改正式番茄计时，60 秒后自动停止。")
            Button("结束验证") { [weak self] in self?.stopGuardProbe() }
        }.frame(maxWidth: .infinity, maxHeight: .infinity))
    }
    @objc func stopGuardProbe() {
        guardProbe?.setFocusActive(false); guardProbe = nil
        if let name = guardProbeSuite { guardProbeDefaults?.removePersistentDomain(forName: name) }
        guardProbeDefaults = nil; guardProbeSuite = nil
        showHome()
    }
    func applicationWillTerminate(_ notification: Notification) {
        stopGuardProbe(); defaults.removePersistentDomain(forName: suite)
    }
}
