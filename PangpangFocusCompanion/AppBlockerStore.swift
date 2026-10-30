import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import OSLog

@MainActor
protocol GuardApplication: AnyObject {
    var bundleIdentifier: String? { get }
    var processIdentifier: pid_t { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }
    func guardHide() -> Bool
    func guardActivate() -> Bool
}

extension NSRunningApplication: GuardApplication {
    func guardHide() -> Bool { hide() }
    func guardActivate() -> Bool { activate(options: [.activateAllWindows]) }
}

@MainActor
struct GuardEnvironment {
    var frontmost: () -> (any GuardApplication)?
    var running: () -> [any GuardApplication]
    var fallback: () -> (any GuardApplication)?
    var now: () -> Date = Date.init
    static var live: Self {
        Self(frontmost: { NSWorkspace.shared.frontmostApplication },
             running: { NSWorkspace.shared.runningApplications }, fallback: { NSRunningApplication.current })
    }
}

struct BlockedApplication: Codable, Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String
    let path: String

    var id: String { bundleIdentifier }
}

@MainActor
final class AppBlockerStore: ObservableObject {
    @Published private(set) var blockedApplications: [BlockedApplication] = []
    @Published private(set) var isEnabled = false
    @Published private(set) var isFocusActive = false

    var onBlockedApplication: ((BlockedApplication) -> Void)?
    var onBlockFailed: ((BlockedApplication) -> Void)?
    var onStateChange: (() -> Void)?

    var headerStatusText: String {
        if !isEnabled { return "守护未开启" }
        if blockedApplications.isEmpty { return "守护待配置" }
        return isBlockingNow ? "正在守护" : "守护已开启"
    }

    private let defaultsKey = "pangpang.app-blocker.snapshot"
    private let defaults: UserDefaults
    private let monitorsApplications: Bool
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Timer?
    private let environment: GuardEnvironment
    private var lastAllowedApplication: (any GuardApplication)?
    private var lastBlockedBundleIdentifier: String?
    private var lastBlockedDate = Date.distantPast
    private var pendingAttempts: [pid_t: Int] = [:]
    private var confirmedHidden: Set<pid_t> = []
    // Apps already open when enforcement starts are hidden without a bubble,
    // including asynchronous hide confirmation and retries.
    private var silentInitialPIDs: Set<pid_t> = []
    private var lastFailureDate = Date.distantPast
    private let logger = Logger(subsystem: "com.tiantian.pangpang-desktop-pet", category: "app-guard")

    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer"
    ]

    init(defaults: UserDefaults = .standard, monitorsApplications: Bool = true, environment: GuardEnvironment? = nil) {
        let environment = environment ?? .live
        self.defaults = defaults
        self.monitorsApplications = monitorsApplications
        self.environment = environment
        restore()
        if monitorsApplications { startMonitoring() }
        if let application = environment.frontmost(), isAllowedReturnTarget(application) {
            lastAllowedApplication = application
        }
    }

    deinit {
        watchdog?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var statusText: String {
        guard isEnabled else { return "未开启 · \(blockedApplications.count) 个 App" }
        if blockedApplications.isEmpty { return "已开启 · 等待添加 App" }
        return isFocusActive ? "守护中 · \(blockedApplications.count) 个 App" : "已开启 · 等待专注"
    }

    var isBlockingNow: Bool { isEnabled && isFocusActive && !blockedApplications.isEmpty }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        persistAndNotify()
        updateEnforcement()
    }

    func toggleEnabled() { setEnabled(!isEnabled) }

    func setFocusActive(_ active: Bool) {
        guard isFocusActive != active else { return }
        isFocusActive = active
        onStateChange?()
        updateEnforcement()
    }

    func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = "选择不想在专注时打开的 App"
        panel.prompt = "加入黑名单"
        panel.message = "可一次选择多个 App，之后也可以随时移除。"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        addApplications(at: panel.urls)
    }

    func remove(_ application: BlockedApplication) {
        blockedApplications.removeAll { $0.id == application.id }
        persistAndNotify()
        updateEnforcement()
    }

    func icon(for application: BlockedApplication) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: application.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }

    private func addApplications(at urls: [URL]) {
        var applications = blockedApplications
        let ownIdentifier = Bundle.main.bundleIdentifier

        for url in urls {
            guard let bundle = Bundle(url: url),
                  let bundleIdentifier = bundle.bundleIdentifier,
                  bundleIdentifier != ownIdentifier,
                  !protectedBundleIdentifiers.contains(bundleIdentifier) else { continue }

            let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            let application = BlockedApplication(
                bundleIdentifier: bundleIdentifier,
                name: displayName,
                path: url.path
            )
            applications.removeAll { $0.id == application.id }
            applications.append(application)
        }

        blockedApplications = applications.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persistAndNotify()
        updateEnforcement()
    }

    private func startMonitoring() {
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didWakeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let interactionPID = (name == NSWorkspace.didActivateApplicationNotification ||
                    name == NSWorkspace.didUnhideApplicationNotification) ? application?.processIdentifier : nil
                Task { @MainActor [weak self] in
                    self?.reconcileApplications(interactionPID: interactionPID)
                }
            })
        }
    }

    private func updateEnforcement() {
        pendingAttempts.removeAll(); confirmedHidden.removeAll()
        silentInitialPIDs.removeAll()
        watchdog?.invalidate(); watchdog = nil
        guard isBlockingNow else { return }
        silentInitialPIDs = Set(environment.running().filter { application in
            !application.isTerminated && !application.isHidden &&
                blockedApplications.contains(where: { $0.bundleIdentifier == application.bundleIdentifier })
        }.map(\.processIdentifier))
        guard monitorsApplications else { return }
        watchdog = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reconcileApplications() }
        }
        RunLoop.main.add(watchdog!, forMode: .common)
        reconcileApplications()
    }

    private func isAllowedReturnTarget(_ application: any GuardApplication) -> Bool {
        guard let id = application.bundleIdentifier, !application.isTerminated else { return false }
        return id != Bundle.main.bundleIdentifier && !protectedBundleIdentifiers.contains(id) &&
            !blockedApplications.contains(where: { $0.bundleIdentifier == id })
    }

    // Injectable environment lets tests exercise retries without touching real apps.
    func reconcileApplications(interactionPID: pid_t? = nil) {
        if let interactionPID { silentInitialPIDs.remove(interactionPID) }
        let frontmost = environment.frontmost()
        if let frontmost, isAllowedReturnTarget(frontmost) { lastAllowedApplication = frontmost }
        guard isBlockingNow else { return }
        let running = environment.running()
        let livePIDs = Set(running.filter { !$0.isTerminated }.map(\.processIdentifier))
        pendingAttempts = pendingAttempts.filter { livePIDs.contains($0.key) }
        confirmedHidden.formIntersection(livePIDs)
        silentInitialPIDs.formIntersection(livePIDs)
        for application in running where !application.isTerminated {
            guard let id = application.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier, !protectedBundleIdentifiers.contains(id),
                  let blocked = blockedApplications.first(where: { $0.bundleIdentifier == id }) else { continue }
            let pid = application.processIdentifier
            if application.isHidden {
                if pendingAttempts[pid] != nil { reportHidden(blocked, pid: pid) }
                continue
            }
            confirmedHidden.remove(pid)
            // Activating a safe destination first avoids racing an app's reopen handler.
            if frontmost?.processIdentifier == pid {
                if let lastAllowedApplication, isAllowedReturnTarget(lastAllowedApplication) {
                    _ = lastAllowedApplication.guardActivate()
                } else if let fallback = environment.fallback(), fallback.bundleIdentifier != id {
                    _ = fallback.guardActivate()
                }
            }
            let attempts = (pendingAttempts[pid] ?? 0) + 1
            pendingAttempts[pid] = attempts
            let accepted = application.guardHide()
            if application.isHidden { reportHidden(blocked, pid: pid) }
            else if attempts >= 3, !silentInitialPIDs.contains(pid),
                    environment.now().timeIntervalSince(lastFailureDate) > 8 {
                lastFailureDate = environment.now()
                logger.error("Hide not verified: bundle=\(id, privacy: .public), accepted=\(accepted), attempts=\(attempts)")
                onBlockFailed?(blocked)
            }
        }
    }

    private func reportHidden(_ application: BlockedApplication, pid: pid_t) {
        pendingAttempts[pid] = nil
        guard confirmedHidden.insert(pid).inserted else { return }
        logger.info("Hide verified: bundle=\(application.bundleIdentifier, privacy: .public), pid=\(pid)")
        guard silentInitialPIDs.remove(pid) == nil else { return }
        let now = environment.now()
        if lastBlockedBundleIdentifier != application.bundleIdentifier || now.timeIntervalSince(lastBlockedDate) > 2.5 {
            lastBlockedBundleIdentifier = application.bundleIdentifier
            lastBlockedDate = now
            onBlockedApplication?(application)
        }
    }

    private func persistAndNotify() {
        let snapshot = Snapshot(isEnabled: isEnabled, blockedApplications: blockedApplications)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
        onStateChange?()
    }

    private func restore() {
        guard let data = defaults.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        isEnabled = snapshot.isEnabled
        blockedApplications = snapshot.blockedApplications
    }

    private struct Snapshot: Codable {
        let isEnabled: Bool
        let blockedApplications: [BlockedApplication]
    }
}
