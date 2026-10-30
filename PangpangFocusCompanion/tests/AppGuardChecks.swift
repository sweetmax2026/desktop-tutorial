import AppKit
import Foundation

@MainActor
private final class FakeGuardApplication: GuardApplication {
    var bundleIdentifier: String?
    var processIdentifier: pid_t
    var isHidden = false
    var isTerminated = false
    var hideCalls = 0
    var activations = 0
    var succeedsOnAttempt = 1
    var returnsAccepted = true
    init(_ id: String, pid: pid_t) { bundleIdentifier = id; processIdentifier = pid }
    func guardHide() -> Bool {
        hideCalls += 1
        if hideCalls >= succeedsOnAttempt { isHidden = true }
        return returnsAccepted
    }
    func guardActivate() -> Bool { activations += 1; return true }
}

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
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        let target = FakeGuardApplication(record.bundleIdentifier, pid: 11)
        target.succeedsOnAttempt = 3
        let allowed = FakeGuardApplication("test.safe", pid: 12)
        var front: (any GuardApplication)? = allowed
        var clock = Date()
        let environment = GuardEnvironment(frontmost: { front }, running: { [target, allowed] },
            fallback: { allowed }, now: { clock })
        let enforcement = AppBlockerStore(defaults: defaults, monitorsApplications: false, environment: environment)
        var successes = 0; var failures = 0
        enforcement.onBlockedApplication = { _ in successes += 1 }
        enforcement.onBlockFailed = { _ in failures += 1 }
        enforcement.setFocusActive(true)
        front = target
        enforcement.reconcileApplications()
        precondition(target.hideCalls == 1 && successes == 0 && allowed.activations == 1)
        enforcement.reconcileApplications()
        precondition(successes == 0, "Accepted hide request is not a verified hidden app")
        enforcement.reconcileApplications()
        precondition(target.isHidden && successes == 0 && failures == 0, "Initial hiding and retries must be silent")
        enforcement.reconcileApplications()
        precondition(target.hideCalls == 3 && successes == 0, "Already hidden app is not re-hidden or re-announced")
        target.isHidden = false; clock = clock.addingTimeInterval(3)
        enforcement.reconcileApplications()
        precondition(target.isHidden && successes == 1, "Watchdog catches reopen and shows the hint")
        enforcement.setFocusActive(false)
        target.isHidden = false
        let beforeBreak = target.hideCalls
        enforcement.reconcileApplications()
        precondition(!target.isHidden && target.hideCalls == beforeBreak, "Break must stop retries immediately")
        enforcement.setFocusActive(true)
        target.succeedsOnAttempt = Int.max; target.returnsAccepted = false
        for _ in 0..<4 { enforcement.reconcileApplications() }
        precondition(successes == 1 && failures == 0, "Initial hide failures must also remain silent")
        enforcement.reconcileApplications(interactionPID: target.processIdentifier)
        precondition(successes == 1 && failures == 1, "Opening a blocked app during focus enables truthful failure hints")
        enforcement.reconcileApplications()
        precondition(failures == 1, "Retries must not spam alerts")
        target.succeedsOnAttempt = 1; clock = clock.addingTimeInterval(3)
        enforcement.reconcileApplications()
        precondition(target.isHidden && successes == 2, "A user-opened app reports success only after hiding is verified")
        enforcement.setEnabled(false)
        let beforeDisable = target.hideCalls
        enforcement.reconcileApplications()
        precondition(target.hideCalls == beforeDisable)
        enforcement.setEnabled(true)
        enforcement.remove(record)
        enforcement.reconcileApplications()
        precondition(target.hideCalls == beforeDisable, "Removed app must be released immediately")
        print("PASS: focus-only gating, independent switch, persisted list/switch, empty-list state, removal; no real application monitoring")
        print("PASS: silent initial hiding/retries/failures, interaction-only hints, verified hiding, repeated reopen, throttling, immediate break/disable/removal release")
    }
}
