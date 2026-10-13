import AppKit
import SwiftUI
import Carbon
@preconcurrency import UserNotifications

@main
@MainActor
enum PangpangDesktopPetApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        // Panels host SwiftUI directly. A Settings-only SwiftUI App would create
        // an unwanted blank Settings window now that the app is visible in Dock.
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let pomodoro = PomodoroStore()
    private let wellbeing = WellbeingStore()
    private let appBlocker = AppBlockerStore()
    private var petWindow: NSPanel?
    private var toolboxWindow: NSPanel?
    private var bubbleWindow: NSPanel?
    private var focusWindow: NSPanel?
    private var statisticsReturnsToFocus = false
    private var miniWindow: NSPanel?
    private var miniMoveObserver: NSObjectProtocol?
    private var miniTemporarilyHidden = false
    private var miniVisibilityOverride: Bool?
    private var presentedSessionID: UUID?
    private var statusItem: NSStatusItem?
    private var moveObserver: NSObjectProtocol?
    private var lastTool: ToolboxTool = .home
    private var lastSurface: ToolboxSurface = .toolbox(.home)
    private var isPetToggleScheduled = false
    private var lastMeditationReminderShownAt: Date?
    private var shortcut: ToolboxShortcut?
    private var shortcutObserver: NSObjectProtocol?
    private var bubbleDismissal: DispatchWorkItem?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var toolboxPresentedAt: TimeInterval = 0
    private let floatingEntryKey = "pangpang.floatingEntry.enabled"
    private var floatingEntryEnabled: Bool { UserDefaults.standard.bool(forKey: floatingEntryKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        configureNotifications()
        configurePetWindow()
        configureShortcut()
        configureOutsideClickDismissal()
        configureStatusItem()
        pomodoro.onBubble = { [weak self] bubble in self?.showBubble(bubble) }
        pomodoro.onStateChange = { [weak self] in
            guard let self else { return }
            self.appBlocker.setFocusActive(self.pomodoro.phase == .focus)
            self.configureStatusItem()
            self.updatePetPresentation()
            if self.presentedSessionID != self.pomodoro.activeSessionID, self.pomodoro.activeSessionID != nil {
                self.presentedSessionID = self.pomodoro.activeSessionID
                self.miniTemporarilyHidden = false
                self.miniVisibilityOverride = nil
            }
            self.updateMiniCard()
        }
        pomodoro.onPresentationChange = { [weak self] in
            self?.miniTemporarilyHidden = false
            self?.miniVisibilityOverride = nil
            self?.updateMiniCard()
            self?.configureStatusItem()
        }
        pomodoro.onFocusFinished = { [weak self] record in self?.showFocusCompletion(record) }
        wellbeing.onMeditationScheduleChanged = { [weak self] times in self?.scheduleMeditationReminders(times) }
        wellbeing.onStateChange = { [weak self] in self?.configureStatusItem() }
        wellbeing.onMeditationReminderDue = { [weak self] in
            self?.showMeditationReminder()
        }
        appBlocker.onBlockedApplication = { [weak self] application in
            self?.showBubble(BubbleMessage(text: "现在不许打开 \(application.name)。", actionTitle: "知道了", action: .dismiss))
        }
        appBlocker.onStateChange = { [weak self] in
            self?.configureStatusItem()
            self?.updatePetPresentation()
        }
        wellbeing.refreshMeditationReminders()
        pomodoro.refreshForCurrentTime()
        appBlocker.setFocusActive(pomodoro.phase == .focus)
        updatePetPresentation()
        updateMiniCard()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pomodoro.persist()
        shortcut?.unregister()
        if let shortcutObserver { NotificationCenter.default.removeObserver(shortcutObserver) }
        bubbleDismissal?.cancel()
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let miniMoveObserver { NotificationCenter.default.removeObserver(miniMoveObserver) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func configureOutsideClickDismissal() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let point = NSEvent.mouseLocation
            let existingPanel = self?.toolboxWindow.flatMap { $0.isVisible ? $0 : nil }
            if let existingPanel, existingPanel.frame.contains(point) { return }
            Task { @MainActor [weak self] in self?.dismissToolboxForOutsideClick(at: point, eventWindow: nil, existingPanel: existingPanel, timestamp: event.timestamp) }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let point = NSEvent.mouseLocation
            // Capture visibility before the click action navigates. Otherwise a click
            // opening a new panel can be misread as an outside click on that new panel.
            let existingPanel = self?.toolboxWindow.flatMap { $0.isVisible ? $0 : nil }
            // Returning from statistics can resize/reposition the same panel. Judge
            // whether the click began inside it before that navigation changes its frame.
            if let existingPanel, event.window === existingPanel || existingPanel.frame.contains(point) {
                return event
            }
            Task { @MainActor [weak self] in self?.dismissToolboxForOutsideClick(at: point, eventWindow: event.window, existingPanel: existingPanel, timestamp: event.timestamp) }
            return event
        }
    }

    private func dismissToolboxForOutsideClick(at point: NSPoint, eventWindow: NSWindow?, existingPanel: NSPanel?, timestamp: TimeInterval) {
        guard let panel = toolboxWindow, panel === existingPanel, panel.isVisible else { return }
        // A delayed observer must not dismiss the destination of the click that
        // presented it. Event timestamps and systemUptime share the boot-time clock.
        guard timestamp > toolboxPresentedAt else { return }
        // A picker, popover, or sheet launched by the toolbox is part of its flow.
        guard NSApp.modalWindow == nil, panel.attachedSheet == nil else { return }
        var ancestor = eventWindow
        while let window = ancestor {
            if window === panel { return }
            ancestor = window.sheetParent ?? window.parent
        }
        if panel.frame.contains(point) { return }
        if let miniWindow, miniWindow.isVisible, miniWindow.frame.contains(point) { return }
        // Let the avatar's own click/drag handler toggle or move the panel.
        if let petWindow, petWindow.isVisible, petWindow.frame.contains(point) { return }
        toolboxWindow?.orderOut(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLastSurface()
        return true
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "pangpang")
        let open = applicationMenu.addItem(withTitle: "打开工具箱", action: #selector(toggleToolbox), keyEquivalent: "")
        open.target = self
        applicationMenu.addItem(.separator())
        let quit = applicationMenu.addItem(withTitle: "退出 pangpang", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func configurePetWindow() {
        let width = petWindowWidth
        let content = PetContentView(
            frame: NSRect(x: 0, y: 0, width: width, height: 86),
            activity: petActivity,
            onTap: { [weak self] in self?.handlePetTap() },
            onDragChanged: { [weak self] in self?.repositionAttachedPanels() },
            onDragEnded: { [weak self] in self?.constrainAndSavePetPosition() }
        )
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 86),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = content
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // The custom AppKit overlay owns movement and click handling.
        window.isMovableByWindowBackground = false
        restorePetPosition(window)
        if floatingEntryEnabled { window.orderFrontRegardless() }
        petWindow = window
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.constrainAndSavePetPosition()
                self?.repositionAttachedPanels()
            }
        }
    }

    private var petActivity: PetActivity? {
        if appBlocker.isBlockingNow { return .guarding }
        switch pomodoro.phase {
        case .focus: return .focus
        case .shortBreak, .longBreak: return .rest
        case .paused: return .paused
        default: return nil
        }
    }

    private var petWindowWidth: CGFloat { petActivity == nil ? 86 : 154 }

    private func updatePetPresentation() {
        guard let petWindow else { return }
        let origin = petWindow.frame.origin
        let width = petWindowWidth
        petWindow.contentView = PetContentView(
            frame: NSRect(x: 0, y: 0, width: width, height: 86),
            activity: petActivity,
            onTap: { [weak self] in self?.handlePetTap() },
            onDragChanged: { [weak self] in self?.repositionAttachedPanels() },
            onDragEnded: { [weak self] in self?.constrainAndSavePetPosition() }
        )
        petWindow.setContentSize(NSSize(width: width, height: 86))
        petWindow.setFrameOrigin(origin)
        constrainAndSavePetPosition()
        repositionAttachedPanels()
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let nextFocus = UNNotificationAction(
            identifier: "START_NEXT_FOCUS",
            title: "开始下一轮",
            options: [.foreground]
        )
        let startMeditation = UNNotificationAction(
            identifier: "START_MEDITATION",
            title: "开始 1 分钟冥想",
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "PANGPANG_POMODORO", actions: [nextFocus], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "PANGPANG_MEDITATION", actions: [startMeditation], intentIdentifiers: [], options: [])
        ])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor [weak self] in
                self?.wellbeing.refreshMeditationReminders()
            }
        }
        pomodoro.onNotification = { title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "PANGPANG_POMODORO"
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "START_NEXT_FOCUS" {
            Task { @MainActor [weak self] in
                self?.startFocus()
            }
        } else if response.actionIdentifier == "START_MEDITATION" {
            Task { @MainActor [weak self] in
                self?.startMeditation()
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == "PANGPANG_MEDITATION" {
            Task { @MainActor [weak self] in self?.showMeditationReminder() }
        }
        completionHandler([.banner, .sound])
    }

    private func configureStatusItem() {
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.length = NSStatusItem.variableLength
        item.button?.image = makeMenuBarCatIcon()
        item.button?.image?.isTemplate = true
        item.button?.imagePosition = .imageLeading
        item.button?.title = menuBarActivity.isEmpty ? "" : " \(menuBarActivity)"
        item.button?.toolTip = "pangpang · \(menuBarActivity.isEmpty ? "工具箱" : menuBarActivity) · ⌃⌥P 打开／收起"
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "打开／收起工具箱", action: #selector(toggleToolbox), keyEquivalent: shortcut?.isRegistered == true ? "p" : "")
        open.keyEquivalentModifierMask = [.control, .option]
        open.target = self
        if shortcut?.isRegistered != true {
            let unavailable = menu.addItem(withTitle: "⌃⌥P 未注册成功，请使用菜单打开", action: nil, keyEquivalent: "")
            unavailable.isEnabled = false
        }
        menu.addItem(.separator())
        let status = menu.addItem(withTitle: menuBarActivity.isEmpty ? "pangpang · 未开始" : "pangpang · \(menuBarActivity)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(.separator())
        let primary = menu.addItem(withTitle: pomodoro.primaryActionTitle, action: #selector(primaryAction), keyEquivalent: "")
        primary.target = self
        if pomodoro.canPause {
            let pause = menu.addItem(withTitle: pomodoro.isPaused ? "继续计时" : "暂停计时", action: #selector(togglePause), keyEquivalent: "")
            pause.target = self
        }
        if pomodoro.canEnd {
            let end = menu.addItem(withTitle: "结束本轮", action: #selector(endCurrent), keyEquivalent: "")
            end.target = self
        }
        menu.addItem(.separator())
        let focus = menu.addItem(withTitle: "打开专注页面", action: #selector(openFocusPage), keyEquivalent: "")
        focus.target = self
        let mini = menu.addItem(withTitle: "专注／休息时自动显示小卡片", action: #selector(toggleMiniCardSetting), keyEquivalent: "")
        mini.target = self
        mini.state = pomodoro.showsMiniCard ? .on : .off
        if pomodoro.canPause || pomodoro.phase == .readyForFocus {
            let temporary = menu.addItem(withTitle: miniWindow?.isVisible == true ? "本轮收起小卡片" : "本轮显示小卡片", action: #selector(toggleTemporaryMiniCard), keyEquivalent: "")
            temporary.target = self
        }
        menu.addItem(.separator())
        let blocker = menu.addItem(
            withTitle: appBlocker.isEnabled ? "暂停 App 管控" : "开启 App 管控",
            action: #selector(toggleAppBlocker),
            keyEquivalent: ""
        )
        blocker.target = self
        menu.addItem(.separator())
        let floating = menu.addItem(withTitle: "显示悬浮圆形入口", action: #selector(toggleFloatingEntry), keyEquivalent: "")
        floating.target = self
        floating.state = floatingEntryEnabled ? .on : .off
        let quit = menu.addItem(withTitle: "退出 pangpang", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        item.menu = menu
        statusItem = item
    }

    private var statusSymbol: String {
        if wellbeing.isMeditating { return "wind" }
        switch pomodoro.phase {
        case .focus: return "timer"
        case .shortBreak, .longBreak: return "cup.and.saucer.fill"
        case .readyForFocus: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        default: return "pawprint.fill"
        }
    }

    private func makeMenuBarCatIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 3.0, y: 10.5))
            head.curve(to: NSPoint(x: 3.3, y: 17), controlPoint1: NSPoint(x: 2.2, y: 14), controlPoint2: NSPoint(x: 2.7, y: 17.8))
            head.curve(to: NSPoint(x: 6.6, y: 14.1), controlPoint1: NSPoint(x: 4.1, y: 17.5), controlPoint2: NSPoint(x: 5.8, y: 15))
            head.curve(to: NSPoint(x: 11.4, y: 14.1), controlPoint1: NSPoint(x: 8, y: 14.6), controlPoint2: NSPoint(x: 10, y: 14.6))
            head.curve(to: NSPoint(x: 14.7, y: 17), controlPoint1: NSPoint(x: 12.2, y: 15), controlPoint2: NSPoint(x: 14, y: 17.5))
            head.curve(to: NSPoint(x: 15, y: 10.5), controlPoint1: NSPoint(x: 15.3, y: 17.8), controlPoint2: NSPoint(x: 15.8, y: 14))
            head.curve(to: NSPoint(x: 9, y: 1), controlPoint1: NSPoint(x: 19, y: 4), controlPoint2: NSPoint(x: 13, y: 1))
            head.curve(to: NSPoint(x: 3, y: 10.5), controlPoint1: NSPoint(x: 5, y: 1), controlPoint2: NSPoint(x: -1, y: 4))
            head.close()
            // Eye and nose cutouts stay legible in a template image at 18 points.
            let leftEye = NSBezierPath()
            leftEye.move(to: NSPoint(x: 4.2, y: 8.1))
            leftEye.curve(to: NSPoint(x: 7.5, y: 6.2), controlPoint1: NSPoint(x: 5.9, y: 8.6), controlPoint2: NSPoint(x: 7.1, y: 7.7))
            leftEye.curve(to: NSPoint(x: 4.2, y: 8.1), controlPoint1: NSPoint(x: 5.9, y: 5.7), controlPoint2: NSPoint(x: 4.8, y: 6.8))
            leftEye.close()
            head.append(leftEye)
            let rightEye = NSBezierPath()
            rightEye.move(to: NSPoint(x: 13.8, y: 8.1))
            rightEye.curve(to: NSPoint(x: 10.5, y: 6.2), controlPoint1: NSPoint(x: 12.1, y: 8.6), controlPoint2: NSPoint(x: 10.9, y: 7.7))
            rightEye.curve(to: NSPoint(x: 13.8, y: 8.1), controlPoint1: NSPoint(x: 12.1, y: 5.7), controlPoint2: NSPoint(x: 13.2, y: 6.8))
            rightEye.close()
            head.append(rightEye)
            let nose = NSBezierPath()
            nose.move(to: NSPoint(x: 8, y: 5.7))
            nose.line(to: NSPoint(x: 10, y: 5.7))
            nose.line(to: NSPoint(x: 9, y: 4.4))
            nose.close()
            head.append(nose)
            head.windingRule = .evenOdd
            head.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "pangpang 猫头"
        return image
    }

    private var menuBarActivity: String {
        let focusState: String
        switch pomodoro.phase {
        case .idle: focusState = ""
        case .focus: focusState = "专注中"
        case .shortBreak, .longBreak: focusState = "休息中"
        case .paused: focusState = "已暂停"
        case .readyForFocus: focusState = "待开始"
        }
        return [focusState, wellbeing.isMeditating ? "冥想中" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func configureShortcut() {
        shortcutObserver = NotificationCenter.default.addObserver(forName: .pangpangToolboxShortcut, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handlePetTap() }
        }
        shortcut = ToolboxShortcut()
    }

    private func showLastSurface() {
        switch lastSurface {
        case .toolbox(let tool): showToolbox(initialTool: tool)
        case .statistics: showStatistics(returnToFocus: statisticsReturnsToFocus)
        case .focus: showFocusPage()
        }
    }

    @objc private func toggleToolbox() { handlePetTap() }

    @objc private func toggleFloatingEntry() {
        let enabled = !floatingEntryEnabled
        UserDefaults.standard.set(enabled, forKey: floatingEntryKey)
        if enabled { showPet() } else { hidePet() }
        configureStatusItem()
        repositionAttachedPanels()
    }

    private func handlePetTap() {
        // Let AppKit finish the pet window's mouse-up/activation cycle before changing panels.
        // This keeps the very first click after launch from being swallowed by activation.
        guard !isPetToggleScheduled else { return }
        isPetToggleScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPetToggleScheduled = false
            if self.toolboxWindow?.isVisible == true || self.focusWindow?.isVisible == true {
                self.toolboxWindow?.orderOut(nil)
                self.focusWindow?.orderOut(nil)
            } else {
                self.showLastSurface()
            }
        }
    }

    @objc private func primaryAction() {
        if pomodoro.phase == .readyForFocus || pomodoro.phase == .idle { startFocus() } else { showToolbox() }
    }

    @objc private func togglePause() { pomodoro.togglePause() }
    @objc private func endCurrent() { pomodoro.endCurrentSession() }
    @objc private func toggleAppBlocker() { appBlocker.toggleEnabled() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func startFocus() {
        bubbleWindow?.orderOut(nil)
        pomodoro.startFocus()
        if floatingEntryEnabled { showPet() }
    }

    private func startMeditation() {
        bubbleWindow?.orderOut(nil)
        wellbeing.startMeditation()
        showToolbox(initialTool: .meditation)
    }

    private func showMeditationReminder() {
        let now = Date()
        if let lastMeditationReminderShownAt,
           now.timeIntervalSince(lastMeditationReminderShownAt) < 30 {
            return
        }
        lastMeditationReminderShownAt = now
        showBubble(BubbleMessage(text: "一分钟，回来呼吸一下？", actionTitle: "开始冥想", action: .startMeditation))
    }

    @objc private func showPet() {
        petWindow?.orderFrontRegardless()
        constrainAndSavePetPosition()
    }

    @objc private func hidePet() {
        UserDefaults.standard.set(false, forKey: floatingEntryKey)
        petWindow?.orderOut(nil)
        configureStatusItem()
        repositionAttachedPanels()
    }

    private func showToolbox(initialTool: ToolboxTool? = nil) {
        if initialTool == .pomodoro { showFocusPage(); return }
        let sourceFocusOrigin = focusWindow?.isVisible == true ? focusWindow?.frame.origin : nil
        focusWindow?.orderOut(nil)
        // The toolbox is a detail view; don't leave an actionable reminder on top of it.
        bubbleWindow?.orderOut(nil)
        let tool = initialTool ?? lastTool
        lastTool = tool
        lastSurface = .toolbox(tool)
        if tool == .home || tool == .mood || tool == .meditation || tool == .appBlocker {
            let panel = toolboxWindow ?? makeFocusPanel()
            panel.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.title = "pangpang · 工具箱"
            panel.level = .normal
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.hasShadow = true
            if tool == .appBlocker {
                panel.title = "pangpang · App 管控"
                install(AppGuardPage(store: appBlocker,
                    onBack: { [weak self] in self?.showToolbox(initialTool: .home) }), in: panel)
            } else if tool == .mood {
                panel.title = "pangpang · 心情记录"
                install(MoodJournalPage(wellbeing: wellbeing,
                    onBack: { [weak self] in self?.showToolbox(initialTool: .home) },
                    onHistory: { [weak self] in self?.showStatistics() }), in: panel)
            } else if tool == .meditation {
                panel.title = "pangpang · 1 分钟冥想"
                install(MeditationPage(wellbeing: wellbeing,
                    onBack: { [weak self] in self?.showToolbox(initialTool: .home) },
                    onHistory: { [weak self] in self?.showStatistics() }), in: panel)
            } else {
                install(BlueToolboxHome(store: pomodoro, wellbeing: wellbeing, appBlocker: appBlocker,
                    onTool: { [weak self] tool in self?.showToolbox(initialTool: tool) },
                    onHistory: { [weak self] in self?.showStatistics() }), in: panel)
            }
            panel.setFrame(NSRect(origin: sourceFocusOrigin ?? panel.frame.origin,
                size: NSSize(width: 800, height: 600)), display: true)
            panel.isMovableByWindowBackground = true
            if toolboxWindow == nil && focusWindow == nil { panel.center() }
            constrain(panel)
            toolboxWindow = panel
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            toolboxPresentedAt = ProcessInfo.processInfo.systemUptime
            return
        }
        let content = ToolboxView(
            pomodoro: pomodoro,
            wellbeing: wellbeing,
            appBlocker: appBlocker,
            initialTool: tool,
            onToolChanged: { [weak self] tool in
                if tool == .pomodoro { self?.showFocusPage(); return }
                if tool == .home { self?.showToolbox(initialTool: .home); return }
                self?.lastTool = tool
                self?.lastSurface = .toolbox(tool)
            },
            onShowStatistics: { [weak self] in self?.showStatistics() },
            onClose: { [weak self] in self?.toolboxWindow?.orderOut(nil) }
        )
        let panel = toolboxWindow ?? makePanel(size: NSSize(width: 390, height: 510))
        panel.styleMask = [.borderless]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .floating
        panel.title = "pangpang · 工具箱"
        panel.setContentSize(NSSize(width: 390, height: 510))
        panel.hasShadow = false
        install(content, in: panel)
        place(panel, above: petWindow, preferredWidth: 390)
        toolboxWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        toolboxPresentedAt = ProcessInfo.processInfo.systemUptime
    }

    private func showStatistics(returnToFocus: Bool = false) {
        let returnTool = lastTool
        if returnToFocus { toolboxWindow?.orderOut(nil) }
        else { focusWindow?.orderOut(nil) }
        statisticsReturnsToFocus = returnToFocus
        lastSurface = .statistics
        let content = StatisticsView(
            pomodoro: pomodoro,
            wellbeing: wellbeing,
            onBack: { [weak self] in
                if returnToFocus { self?.showFocusPage() }
                else { self?.showToolbox(initialTool: returnTool) }
            },
            onClose: { [weak self] in
                if returnToFocus { self?.focusWindow?.orderOut(nil) }
                else { self?.toolboxWindow?.orderOut(nil) }
            },
            returnTitle: returnToFocus ? "返回专注" : (returnTool == .mood ? "返回心情记录" : returnTool == .meditation ? "返回冥想" : "返回工具箱"),
            initialMetric: returnToFocus ? .focus : (returnTool == .mood ? .mood : returnTool == .meditation ? .meditation : .focus)
        )
        let panel = (returnToFocus ? focusWindow : toolboxWindow) ?? makeFocusPanel()
        let wasVisible = panel.isVisible
        let originalOrigin = panel.frame.origin
        panel.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .normal
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.title = "pangpang · 数据统计"
        panel.hasShadow = true
        install(content, in: panel)
        panel.setFrame(NSRect(origin: originalOrigin, size: NSSize(width: 800, height: 600)), display: true)
        if !wasVisible { constrain(panel) }
        if returnToFocus { focusWindow = panel } else { toolboxWindow = panel }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        toolboxPresentedAt = ProcessInfo.processInfo.systemUptime
    }

    private func showBubble(_ bubble: BubbleMessage) {
        bubbleDismissal?.cancel()
        // At the end of a break, the reminder is the single next action. Hiding the
        // detail view prevents the two messages from competing for attention.
        if bubble.action == .startNextFocus || bubble.action == .startMeditation {
            toolboxWindow?.orderOut(nil)
        }
        let content = BubbleView(message: bubble, onAction: { [weak self] in
            if bubble.action == .startNextFocus { self?.startFocus() }
            if bubble.action == .startMeditation { self?.startMeditation() }
            self?.bubbleWindow?.orderOut(nil)
        }, onDismiss: { [weak self] in self?.bubbleWindow?.orderOut(nil) })
        let panel = bubbleWindow ?? makePanel(size: NSSize(width: 244, height: 108))
        panel.setContentSize(NSSize(width: 244, height: 108))
        install(content, in: panel)
        place(panel, above: petWindow, preferredWidth: 244)
        panel.orderFrontRegardless()
        bubbleWindow = panel
        let dismissal = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        bubbleDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: dismissal)
    }

    @objc private func openFocusPage() { showFocusPage() }
    @objc private func toggleMiniCardSetting() { pomodoro.showsMiniCard.toggle() }
    @objc private func toggleTemporaryMiniCard() {
        miniTemporarilyHidden = miniWindow?.isVisible == true
        miniVisibilityOverride = !miniTemporarilyHidden
        updateMiniCard()
        configureStatusItem()
    }

    private func showFocusPage(editLatestNote: Bool = false) {
        toolboxWindow?.orderOut(nil)
        bubbleWindow?.orderOut(nil)
        lastSurface = .focus
        let content = FocusExperienceView(store: pomodoro,
            onBack: { [weak self] in self?.showToolbox(initialTool: .home) },
            onClose: { [weak self] in self?.focusWindow?.orderOut(nil) },
            onHistory: { [weak self] in self?.showStatistics(returnToFocus: true) },
            editLatestNote: editLatestNote)
        let panel = focusWindow ?? makeFocusPanel()
        panel.title = "pangpang · 专注时刻"
        panel.isMovableByWindowBackground = true
        install(content, in: panel)
        panel.setFrame(NSRect(origin: panel.frame.origin, size: NSSize(width: 800, height: 600)), display: true)
        if focusWindow == nil { panel.center() }
        constrain(panel)
        focusWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func updateMiniCard() {
        guard pomodoro.canPause || pomodoro.phase == .readyForFocus,
              (miniVisibilityOverride ?? pomodoro.showsMiniCard) && !miniTemporarilyHidden else {
            miniWindow?.orderOut(nil)
            return
        }
        let panel = miniWindow ?? makePanel(size: NSSize(width: 264, height: 92))
        panel.title = "pangpang · 专注小卡片"
        panel.isMovableByWindowBackground = true
        install(CompactFocusCard(store: pomodoro,
            onOpen: { [weak self] in self?.showFocusPage() },
            onHide: { [weak self] in
                self?.miniTemporarilyHidden = true
                self?.miniWindow?.orderOut(nil)
                self?.configureStatusItem()
            }), in: panel)
        if miniWindow == nil {
            if let saved = UserDefaults.standard.string(forKey: "pangpang.focus.mini.origin") {
                panel.setFrameOrigin(NSPointFromString(saved))
            } else if let screen = NSScreen.main {
                panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 270, y: screen.visibleFrame.maxY - 116))
            }
            constrain(panel)
            miniMoveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak panel] _ in
                Task { @MainActor [weak panel] in
                    if let panel { UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: "pangpang.focus.mini.origin") }
                }
            }
        }
        miniWindow = panel
        panel.orderFrontRegardless()
    }

    private func showFocusCompletion(_ record: FocusRecord) {
        bubbleDismissal?.cancel()
        let panel = bubbleWindow ?? makePanel(size: NSSize(width: 356, height: 172))
        panel.setContentSize(NSSize(width: 356, height: 172))
        install(FocusCompletionView(store: pomodoro, record: record, onNote: { [weak self] in self?.showFocusPage(editLatestNote: true) }), in: panel)
        place(panel, above: petWindow, preferredWidth: 356)
        bubbleWindow = panel
        panel.orderFrontRegardless()
        let dismissal = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        bubbleDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: dismissal)
    }

    private func repositionAttachedPanels() {
        if let toolboxWindow, toolboxWindow.isVisible {
            place(toolboxWindow, above: petWindow, preferredWidth: toolboxWindow.frame.width)
        }
        if let bubbleWindow, bubbleWindow.isVisible {
            place(bubbleWindow, above: petWindow, preferredWidth: bubbleWindow.frame.width)
        }
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = InputCapablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .aqua)
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        return panel
    }

    private func makeFocusPanel() -> NSPanel {
        let panel = InputCapablePanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.title = "pangpang · 专注时刻"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        // fullSizeContentView includes the title bar. Match the complete visual frame
        // rather than leaving an extra title-bar-height strip below the fixed view.
        panel.setFrame(NSRect(x: 0, y: 0, width: 800, height: 600), display: false)
        panel.backgroundColor = NSColor(red: 1, green: 0.986, blue: 0.968, alpha: 1)
        panel.appearance = NSAppearance(named: .aqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        // The large focus surface is a regular app window, not an always-on-top overlay.
        panel.level = .normal
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        return panel
    }

    private func install<Content: View>(_ content: Content, in panel: NSPanel) {
        let lightContent = content.environment(\.colorScheme, .light)
        let host = ClearHostingView(rootView: lightContent)
        panel.contentView = host
        panel.appearance = NSAppearance(named: .aqua)
        panel.invalidateShadow()
        DispatchQueue.main.async { [weak panel] in panel?.invalidateShadow() }
    }

    private func scheduleMeditationReminders(_ times: [MeditationTime]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: times.map { "pangpang.meditation.\($0.id)" })
        center.getPendingNotificationRequests { requests in
            let staleIDs = requests.map(\.identifier).filter { $0.hasPrefix("pangpang.meditation.") }
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            for time in times {
                let content = UNMutableNotificationContent()
                content.title = "pangpang"
                content.body = "一分钟，回来呼吸一下？"
                content.sound = .default
                content.categoryIdentifier = "PANGPANG_MEDITATION"
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: time.hour, minute: time.minute), repeats: true)
                let request = UNNotificationRequest(identifier: "pangpang.meditation.\(time.id)", content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    private func place(_ panel: NSPanel, above anchor: NSWindow?, preferredWidth: CGFloat) {
        if !floatingEntryEnabled {
            // Anchor to the menu bar when the desktop entry is hidden.
            let button = statusItem?.button
            let buttonRect = button.flatMap { button in button.window?.convertToScreen(button.convert(button.bounds, to: nil)) }
            let pointer = NSEvent.mouseLocation
            let screen = button?.window?.screen ?? NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
            guard let visible = screen?.visibleFrame else { panel.center(); return }
            let centerX = buttonRect?.midX ?? visible.midX
            let x = min(max(centerX - panel.frame.width / 2, visible.minX + 10), visible.maxX - panel.frame.width - 10)
            let y = max(visible.minY + 10, visible.maxY - panel.frame.height - 12)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }
        guard let anchor else { panel.center(); return }
        let visible = anchor.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(anchor.frame.midX - preferredWidth / 2, visible.minX + 10), visible.maxX - panel.frame.width - 10)
        let gap: CGFloat = 24
        let aboveY = anchor.frame.maxY + gap
        let belowY = anchor.frame.minY - panel.frame.height - gap
        let y: CGFloat
        if aboveY + panel.frame.height <= visible.maxY - 10 {
            y = aboveY
        } else if belowY >= visible.minY + 10 {
            y = belowY
        } else {
            y = min(max(aboveY, visible.minY + 10), visible.maxY - panel.frame.height - 10)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func restorePetPosition(_ window: NSWindow) {
        if let saved = UserDefaults.standard.string(forKey: "pangpang.pet.origin") {
            window.setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 92, y: screen.visibleFrame.minY + 88))
        }
        constrain(window)
    }

    private func constrainAndSavePetPosition() {
        guard let petWindow else { return }
        constrain(petWindow)
        UserDefaults.standard.set(NSStringFromPoint(petWindow.frame.origin), forKey: "pangpang.pet.origin")
    }

    private func constrain(_ window: NSWindow) {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(window.frame.origin.x, visible.minX + 8), visible.maxX - window.frame.width - 8)
        let y = min(max(window.frame.origin.y, visible.minY + 8), visible.maxY - window.frame.height - 8)
        if window.frame.origin != NSPoint(x: x, y: y) { window.setFrameOrigin(NSPoint(x: x, y: y)) }
    }
}

private extension Notification.Name {
    static let pangpangToolboxShortcut = Notification.Name("pangpang.toolbox.shortcut")
}

// Register a system hotkey rather than monitoring all keyboard input.
// Control–Option–P works while another app has focus, without accessibility access.
private final class ToolboxShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var isRegistered: Bool { hotKey != nil }

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                  identifier.signature == 0x50414E47, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            NotificationCenter.default.post(name: .pangpangToolboxShortcut, object: nil)
            return noErr
        }, 1, &eventType, nil, &handler)
        guard result == noErr else { return }
        let identifier = EventHotKeyID(signature: 0x50414E47, id: 1)
        if RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), identifier, GetApplicationEventTarget(), 0, &hotKey) != noErr {
            unregister()
        }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }

    deinit { unregister() }
}

private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }
}

private enum ToolboxSurface {
    case toolbox(ToolboxTool)
    case statistics
    case focus
}

private final class InputCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
