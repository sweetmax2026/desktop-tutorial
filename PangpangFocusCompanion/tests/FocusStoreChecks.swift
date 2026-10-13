import Foundation

@main
@MainActor
enum FocusStoreChecks {
    static func main() throws {
        let suite = "pangpang.test.focus.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var clock = Date()
        let store = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        store.showsMiniCard = false
        assert(!PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false).showsMiniCard)
        store.draftCategory = "阅读"; store.draftTask = "测试任务"
        store.startFocus()
        let originalID = store.activeSessionID
        store.startFocus()
        assert(store.activeSessionID == originalID, "Repeated start must not reset active focus")
        clock = clock.addingTimeInterval(100)
        store.togglePause()
        assert(store.pausedRemaining == 1400)
        clock = clock.addingTimeInterval(300)
        store.togglePause()
        clock = clock.addingTimeInterval(1400)
        store.refreshForCurrentTime()
        assert(store.records.count == 1 && store.records[0].seconds == 1500)
        assert(store.records[0].category == "阅读" && store.phase == .shortBreak)
        assert(store.isRestSession)
        store.togglePause()
        assert(store.isRestSession, "Paused break must retain its rest presentation")
        store.togglePause()
        store.refreshForCurrentTime()
        assert(store.records.count == 1, "Completion must not duplicate")
        clock = clock.addingTimeInterval(300)
        store.refreshForCurrentTime()
        assert(store.phase == .readyForFocus, "Break must not auto-start focus")
        assert(!store.isRestSession)
        store.updateNote(id: store.records[0].id, note: "成果")
        let restored = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        assert(restored.records[0].note == "成果" && restored.completedFocuses == 1)
        restored.startFocus()
        clock = clock.addingTimeInterval(90)
        restored.togglePause()
        clock = clock.addingTimeInterval(500)
        restored.endCurrentSession()
        assert(restored.records.last!.seconds == 90 && !restored.records.last!.completed)
        assert(restored.completedFocuses == 1, "Interrupted focus must not earn a paw")
        let date = clock.timeIntervalSinceReferenceDate
        let legacy: [String: Any] = ["phase": "idle", "completedFocuses": 2, "focusCompletionDates": [date - 3000, date]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "pangpang.pomodoro.snapshot")
        let migrated = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        assert(migrated.records.count == 2 && migrated.records.allSatisfy { $0.estimated })
        assert(migrated.focusCompletionDates.count == 2)
        defaults.removeObject(forKey: "pangpang.pomodoro.snapshot")
        let configurable = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        configurable.updateSettings(FocusSettings(focusMinutes: 10, shortBreakMinutes: 2, longBreakMinutes: 3, longBreakInterval: 2))
        configurable.startFocus()
        let deadline = configurable.endDate
        clock = clock.addingTimeInterval(60)
        configurable.refreshForCurrentTime()
        let originalProgress = configurable.progress
        configurable.updateSettings(FocusSettings(focusMinutes: 20, shortBreakMinutes: 1, longBreakMinutes: 4, longBreakInterval: 2))
        assert(configurable.endDate == deadline && configurable.progress == originalProgress)
        configurable.togglePause()
        configurable.updateSettings(FocusSettings(focusMinutes: 15, shortBreakMinutes: 1, longBreakMinutes: 4, longBreakInterval: 2))
        let resumed = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        assert(resumed.settings.focusMinutes == 15 && resumed.pausedRemaining == 540)
        resumed.togglePause()
        clock = clock.addingTimeInterval(540)
        resumed.refreshForCurrentTime()
        assert(resumed.records.last!.seconds == 600 && resumed.remainingText() == "01:00")
        clock = clock.addingTimeInterval(60)
        resumed.refreshForCurrentTime()
        resumed.startFocus()
        clock = clock.addingTimeInterval(900)
        resumed.refreshForCurrentTime()
        assert(resumed.records.last!.seconds == 900 && resumed.phase == .longBreak && resumed.remainingText() == "04:00")
        let activeBreakDeadline = resumed.endDate
        resumed.updateSettings(FocusSettings())
        assert(resumed.endDate == activeBreakDeadline && resumed.phaseTitle == "4 分钟长休息中")
        resumed.updateSettings(FocusSettings(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 10, longBreakInterval: 3))
        clock = clock.addingTimeInterval(240)
        resumed.refreshForCurrentTime()
        resumed.startFocus()
        clock = clock.addingTimeInterval(1500)
        resumed.refreshForCurrentTime()
        assert(resumed.phase == .shortBreak, "Changing interval must count since the last long break, not modulo lifetime totals")
        print("PASS: custom times, live/paused settings edits preserve duration, reload, phase stats, configurable long break")
        print("PASS: persistent card setting, pause timing, single completion, manual next round, notes, interrupted time, legacy migration")
    }
}
