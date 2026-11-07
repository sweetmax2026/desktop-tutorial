import AppKit
import UserNotifications

// Real AppDelegate under a separate bundle/defaults domain. No test clocks,
// no seeded records, no real-app monitoring and no competing global shortcut.
@main @MainActor enum ReleaseAcceptanceApp {
    static func main() {
        let probe = CommandLine.arguments.contains("--fresh-launch-probe")
        let suite = probe ? "pangpang.release.probe.\(UUID().uuidString)" : "pangpang.release.acceptance.v1"
        let defaults = UserDefaults(suiteName: suite)!
        if CommandLine.arguments.contains("--reset-test-data") {
            defaults.removePersistentDomain(forName: suite)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate(defaults: defaults, registersGlobalShortcut: false, monitorsApplications: false)
        let lifecycle = AcceptanceLifecycleRecorder(defaults: defaults)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        let terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main) { _ in
            // Test host must not leave default meditation notifications behind.
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        let observer = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification,
            object: nil, queue: .main) { _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let authorization = settings.authorizationStatus.rawValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let visible = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }.count
                    let summary: [String: Any] = ["notificationAuthorization": authorization, "visibleTitledWindows": visible,
                        "freshLaunchProbe": probe, "bundle": Bundle.main.bundleIdentifier ?? ""]
                    if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]) {
                        try? data.write(to: URL(fileURLWithPath: "/private/tmp/pang-release-acceptance-status.json"), options: .atomic)
                    }
                    if Bundle.main.bundleIdentifier == "com.tiantian.pangpang.release-acceptance-sandbox" {
                        // Verify only the disposable fixture's saved permission, inside the real sandbox.
                        let blocker = AppBlockerStore(defaults: UserDefaults(suiteName: suite)!, monitorsApplications: false)
                        var checks: [[String: Any]] = []
                        for item in blocker.blockedApplications where item.bundleIdentifier == "com.tiantian.pangpang.sandbox-fixture" {
                            var check: [String: Any] = ["fixture": true, "hasBookmark": item.bookmark != nil]
                            do {
                                guard let bookmark = item.bookmark else { throw CocoaError(.fileReadNoPermission) }
                                var stale = false
                                let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                                                  relativeTo: nil, bookmarkDataIsStale: &stale)
                                let granted = url.startAccessingSecurityScopedResource()
                                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                                check["resolved"] = true; check["scopeGranted"] = granted; check["stale"] = stale
                                check["canReadFixtureInfo"] = (try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist"))) != nil
                            } catch { check["resolved"] = false; check["errorCode"] = (error as NSError).code }
                            checks.append(check)
                        }
                        if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.sortedKeys]) {
                            try? data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("pang-bookmark-check.json"), options: .atomic)
                        }
                    }
                    if probe { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite); NSApp.terminate(nil) }
                }
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        withExtendedLifetime((delegate, lifecycle)) { app.run() }
    }
}
