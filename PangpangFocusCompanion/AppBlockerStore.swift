import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

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
    var onStateChange: (() -> Void)?

    private let defaultsKey = "pangpang.app-blocker.snapshot"
    private var activationObserver: NSObjectProtocol?
    private var lastAllowedApplication: NSRunningApplication?
    private var lastBlockedBundleIdentifier: String?
    private var lastBlockedDate = Date.distantPast
    private var isHandlingBlockedApplication = false

    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer"
    ]

    init() {
        restore()
        startMonitoring()
        if let application = NSWorkspace.shared.frontmostApplication,
           application.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastAllowedApplication = application
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
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
        if isBlockingNow { checkFrontmostApplication() }
    }

    func toggleEnabled() { setEnabled(!isEnabled) }

    func setFocusActive(_ active: Bool) {
        guard isFocusActive != active else { return }
        isFocusActive = active
        onStateChange?()
        if isBlockingNow { checkFrontmostApplication() }
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
        if isBlockingNow { checkFrontmostApplication() }
    }

    private func startMonitoring() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in self?.handleActivatedApplication(application) }
        }
    }

    private func checkFrontmostApplication() {
        guard let application = NSWorkspace.shared.frontmostApplication else { return }
        handleActivatedApplication(application)
    }

    private func handleActivatedApplication(_ application: NSRunningApplication) {
        guard let bundleIdentifier = application.bundleIdentifier else { return }
        let ownIdentifier = Bundle.main.bundleIdentifier
        let blocked = blockedApplications.first { $0.bundleIdentifier == bundleIdentifier }

        guard isBlockingNow, let blocked else {
            if blocked == nil, bundleIdentifier != ownIdentifier, !protectedBundleIdentifiers.contains(bundleIdentifier) {
                lastAllowedApplication = application
            }
            return
        }

        guard !isHandlingBlockedApplication else { return }
        isHandlingBlockedApplication = true

        _ = application.hide()
        if let lastAllowedApplication,
           !lastAllowedApplication.isTerminated,
           lastAllowedApplication.bundleIdentifier != bundleIdentifier {
            lastAllowedApplication.activate(options: [.activateAllWindows])
        }

        let now = Date()
        if lastBlockedBundleIdentifier != bundleIdentifier || now.timeIntervalSince(lastBlockedDate) > 2.5 {
            lastBlockedBundleIdentifier = bundleIdentifier
            lastBlockedDate = now
            onBlockedApplication?(blocked)
        }

        DispatchQueue.main.async { [weak self] in self?.isHandlingBlockedApplication = false }
    }

    private func persistAndNotify() {
        let snapshot = Snapshot(isEnabled: isEnabled, blockedApplications: blockedApplications)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        onStateChange?()
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        isEnabled = snapshot.isEnabled
        blockedApplications = snapshot.blockedApplications
    }

    private struct Snapshot: Codable {
        let isEnabled: Bool
        let blockedApplications: [BlockedApplication]
    }
}
