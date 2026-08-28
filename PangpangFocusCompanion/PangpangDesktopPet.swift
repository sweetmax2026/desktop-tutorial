import AppKit
import SwiftUI
@preconcurrency import UserNotifications

@main
struct PangpangDesktopPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
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
    private var statusItem: NSStatusItem?
    private var moveObserver: NSObjectProtocol?
    private var lastTool: ToolboxTool = .home
    private var lastSurface: ToolboxSurface = .toolbox(.home)
    private var isPetToggleScheduled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureNotifications()
        configurePetWindow()
        configureStatusItem()
        pomodoro.onBubble = { [weak self] bubble in self?.showBubble(bubble) }
        pomodoro.onStateChange = { [weak self] in
            guard let self else { return }
            self.appBlocker.setFocusActive(self.pomodoro.phase == .focus)
            self.configureStatusItem()
            self.updatePetPresentation()
        }
        wellbeing.onMeditationScheduleChanged = { [weak self] times in self?.scheduleMeditationReminders(times) }
        wellbeing.onMeditationFinished = { [weak self] in
            self?.showBubble(BubbleMessage(text: "这一分钟，留给你了。", actionTitle: "好", action: .dismiss))
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        pomodoro.persist()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPet()
        return true
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
        window.orderFrontRegardless()
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
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: statusSymbol, accessibilityDescription: "pangpang")
        item.button?.toolTip = pomodoro.statusText
        let menu = NSMenu()
        let status = menu.addItem(withTitle: pomodoro.statusText, action: nil, keyEquivalent: "")
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
        let blocker = menu.addItem(
            withTitle: appBlocker.isEnabled ? "暂停 App 管控" : "开启 App 管控",
            action: #selector(toggleAppBlocker),
            keyEquivalent: ""
        )
        blocker.target = self
        menu.addItem(.separator())
        let show = menu.addItem(withTitle: "显示 pangpang", action: #selector(showPet), keyEquivalent: "")
        show.target = self
        let hide = menu.addItem(withTitle: "隐藏桌面入口", action: #selector(hidePet), keyEquivalent: "")
        hide.target = self
        let quit = menu.addItem(withTitle: "退出 pangpang", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        item.menu = menu
        statusItem = item
    }

    private var statusSymbol: String {
        switch pomodoro.phase {
        case .focus: return "timer"
        case .shortBreak, .longBreak: return "cup.and.saucer.fill"
        case .readyForFocus: return "play.circle.fill"
        default: return "pawprint.fill"
        }
    }

    private func handlePetTap() {
        // Let AppKit finish the pet window's mouse-up/activation cycle before changing panels.
        // This keeps the very first click after launch from being swallowed by activation.
        guard !isPetToggleScheduled else { return }
        isPetToggleScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPetToggleScheduled = false
            if self.toolboxWindow?.isVisible == true {
                self.toolboxWindow?.orderOut(nil)
            } else {
                switch self.lastSurface {
                case .toolbox(let tool): self.showToolbox(initialTool: tool)
                case .statistics: self.showStatistics()
                }
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
        showPet()
    }

    private func startMeditation() {
        bubbleWindow?.orderOut(nil)
        wellbeing.startMeditation()
        showToolbox(initialTool: .meditation)
    }

    private func showMeditationReminder() {
        showBubble(BubbleMessage(text: "一分钟，回来呼吸一下？", actionTitle: "开始冥想", action: .startMeditation))
    }

    @objc private func showPet() {
        petWindow?.orderFrontRegardless()
        constrainAndSavePetPosition()
    }

    @objc private func hidePet() { petWindow?.orderOut(nil) }

    private func showToolbox(initialTool: ToolboxTool? = nil) {
        // The toolbox is a detail view; don't leave an actionable reminder on top of it.
        bubbleWindow?.orderOut(nil)
        let tool = initialTool ?? lastTool
        lastTool = tool
        lastSurface = .toolbox(tool)
        let content = ToolboxView(
            pomodoro: pomodoro,
            wellbeing: wellbeing,
            appBlocker: appBlocker,
            initialTool: tool,
            onToolChanged: { [weak self] tool in
                self?.lastTool = tool
                self?.lastSurface = .toolbox(tool)
            },
            onShowStatistics: { [weak self] in self?.showStatistics() },
            onClose: { [weak self] in self?.toolboxWindow?.orderOut(nil) }
        )
        let panel = toolboxWindow ?? makePanel(size: NSSize(width: 390, height: 510))
        panel.setContentSize(NSSize(width: 390, height: 510))
        panel.hasShadow = false
        install(content, in: panel)
        place(panel, above: petWindow, preferredWidth: 390)
        toolboxWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func showStatistics() {
        lastSurface = .statistics
        let content = StatisticsView(
            pomodoro: pomodoro,
            wellbeing: wellbeing,
            onBack: { [weak self] in
                self?.showToolbox()
            },
            onClose: { [weak self] in self?.toolboxWindow?.orderOut(nil) }
        )
        let panel = toolboxWindow ?? makePanel(size: NSSize(width: 490, height: 600))
        panel.setContentSize(NSSize(width: 490, height: 600))
        panel.hasShadow = false
        install(content, in: panel)
        place(panel, above: petWindow, preferredWidth: 490)
        toolboxWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func showBubble(_ bubble: BubbleMessage) {
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
        install(content, in: panel)
        place(panel, above: petWindow, preferredWidth: 244)
        panel.orderFrontRegardless()
        bubbleWindow = panel
    }

    private func repositionAttachedPanels() {
        if let toolboxWindow, toolboxWindow.isVisible {
            place(toolboxWindow, above: petWindow, preferredWidth: toolboxWindow.frame.width)
        }
        if let bubbleWindow, bubbleWindow.isVisible {
            place(bubbleWindow, above: petWindow, preferredWidth: 244)
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
        return panel
    }

    private func install<Content: View>(_ content: Content, in panel: NSPanel) {
        let lightContent = content.environment(\.colorScheme, .light)
        panel.contentView = ClearHostingView(rootView: lightContent)
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
}

private final class InputCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
