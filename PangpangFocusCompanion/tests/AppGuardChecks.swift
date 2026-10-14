import AppKit
import Foundation

@main @MainActor
enum AppGuardChecks {
    static func main() throws {
        let suite = "pangpang.test.guard.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let record = BlockedApplication(bundleIdentifier: "test.example", name: "Example", path: "/Applications/Example.app")
        let snapshot: [String: Any] = ["isEnabled": true, "blockedApplications": [["bundleIdentifier": record.bundleIdentifier, "name": record.name, "path": record.path]]]
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        let store = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        precondition(store.isEnabled && !store.isBlockingNow)
        precondition(store.statusText == "已开启 · 等待专注")
        precondition(store.headerStatusText == "守护已开启")
        store.setFocusActive(true)
        precondition(store.isBlockingNow)
        precondition(store.headerStatusText == "正在守护")
        store.setFocusActive(false)
        precondition(!store.isBlockingNow) // Breaks and paused focus both pass false.
        store.setEnabled(false)
        precondition(store.headerStatusText == "守护未开启")
        store.setFocusActive(true)
        precondition(!store.isBlockingNow)
        let restored = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        precondition(!restored.isEnabled && restored.blockedApplications == [record])
        restored.setEnabled(true)
        restored.remove(record)
        precondition(restored.blockedApplications.isEmpty && !restored.isBlockingNow)
        precondition(restored.statusText == "已开启 · 等待添加 App")
        precondition(restored.headerStatusText == "守护待配置")
        let emptyRestored = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        precondition(emptyRestored.isEnabled && emptyRestored.blockedApplications.isEmpty)
        print("PASS: focus-only gating, independent switch, persisted list/switch, empty-list state, removal; no real application monitoring")
    }
}
