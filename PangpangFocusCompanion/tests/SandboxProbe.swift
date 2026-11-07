import AppKit
import Carbon
import Security

@main @MainActor enum SandboxProbe {
    static var guardStore: AppBlockerStore?
    static var results: [String: Bool] = [:]
    static let fixtureID = "com.tiantian.pangpang.sandbox-fixture"
    static func record(_ name: String, _ passed: Bool) {
        results[name] = passed
        print("\(passed ? "PASS" : "FAIL"): \(name)")
        fflush(stdout)
    }
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let task = SecTaskCreateFromSelf(nil)!
        record("runtime sandbox entitlement", (SecTaskCopyValueForEntitlement(task, "com.apple.security.app-sandbox" as CFString, nil) as? Bool) == true)
        record("outside-container canary denied", (try? Data(contentsOf: URL(fileURLWithPath: "/private/tmp/pang-sandbox-denial-canary"))) == nil)
        let defaults = UserDefaults.standard
        let store = PomodoroStore(defaults: defaults, schedulesTimer: false)
        if CommandLine.arguments.contains("--persistence-only") {
            record("task and duration across process relaunch", store.draftTask == "沙盒测试任务" && store.settings.focusMinutes == 40)
            record("active deadline across process relaunch", store.endDate?.timeIntervalSinceReferenceDate == defaults.double(forKey: "probe.deadline"))
            finish()
        }
        store.saveUnifiedTask(name: "沙盒测试任务", focusMinutes: 40, presets: store.taskPresets)
        store.startFocus()
        defaults.set(store.endDate!.timeIntervalSinceReferenceDate, forKey: "probe.deadline")
        record("isolated task and timer persisted", store.activeTask == "沙盒测试任务")
        var hotkey: EventHotKeyRef?
        let hotkeyStatus = RegisterEventHotKey(UInt32(kVK_F19), UInt32(controlKey | optionKey | shiftKey),
                         EventHotKeyID(signature: 0x53424F58, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        record("global hotkey registration", hotkeyStatus == noErr)
        if let hotkey { UnregisterEventHotKey(hotkey) }
        let snapshot: [String: Any] = ["isEnabled": true, "blockedApplications":
            [["bundleIdentifier": fixtureID, "name": "Sandbox Test Fixture", "path": "/sandbox-fixture.app"]]]
        defaults.set(try! JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        // Run the real store and real NSRunningApplication APIs, restricted to our fixture.
        let environment = GuardEnvironment(frontmost: {
            let front = NSWorkspace.shared.frontmostApplication
            return front?.bundleIdentifier == fixtureID ? front : nil
        }, running: { NSRunningApplication.runningApplications(withBundleIdentifier: fixtureID) }, fallback: { nil })
        guardStore = AppBlockerStore(defaults: defaults, environment: environment)
        guardStore!.setFocusActive(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            record("fixture initially hidden", fixture()?.isHidden == true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            record("fixture re-hidden after unhide", fixture()?.isHidden == true)
            guardStore!.setFocusActive(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            record("rest phase releases fixture", fixture()?.isHidden == false)
            guardStore!.setFocusActive(true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) {
            record("next focus hides fixture", fixture()?.isHidden == true)
            guardStore!.setEnabled(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            record("disabled guard releases fixture", fixture()?.isHidden == false)
            guardStore = nil
            finish()
        }
        app.run()
    }
    static func fixture() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: fixtureID).first
    }
    static func finish() -> Never {
        print("RESULT: \(results.values.allSatisfy { $0 } ? "PASS" : "FAIL")")
        fflush(stdout)
        exit(results.values.allSatisfy { $0 } ? 0 : 1)
    }
}
