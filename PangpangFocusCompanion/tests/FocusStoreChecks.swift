import Foundation

@main @MainActor enum FocusStoreChecks {
    static func main() throws {
        let suite = "pangpang.test.focus.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var clock = Date()
        func fresh() -> PomodoroStore {
            PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        }
        let store = fresh()
        assert(AppBrand.name == "Pang 大师")
        assert(!store.showsFloatingEntry && store.showsMiniCard)
        store.showsFloatingEntry = true; store.showsMiniCard = false
        assert(fresh().showsFloatingEntry && !fresh().showsMiniCard)
        store.draftCategory = "阅读"; store.draftTask = "测试任务"
        store.startFocus()
        let deadline = store.endDate
        let id = store.activeSessionID
        store.startFocus(); store.resetToReady(); store.togglePause()
        assert(store.endDate == deadline && store.activeSessionID == id && store.phase == .focus)
        assert(!store.canPause && store.canEnd && store.hasActiveSession)
        clock = clock.addingTimeInterval(100)
        store.refreshForCurrentTime()
        assert(store.remainingText() == "23:20")
        store.updateSettings(FocusSettings(focusMinutes: 10, shortBreakMinutes: 2, longBreakMinutes: 3, longBreakInterval: 2))
        assert(store.endDate == deadline, "Editing settings must preserve active deadline")
        clock = clock.addingTimeInterval(1400)
        store.refreshForCurrentTime()
        assert(store.records.count == 1 && store.records[0].seconds == 1500)
        assert(store.phase == .completed && store.endDate == nil && store.completionRecord?.id == id)
        assert(store.records[0].category == "阅读" && store.records[0].task == "测试任务")
        store.refreshForCurrentTime()
        clock = clock.addingTimeInterval(86400)
        store.refreshForCurrentTime()
        assert(store.phase == .completed && store.records.count == 1, "Waiting for rest never runs a hidden clock")
        let restored = fresh()
        assert(restored.phase == .completed && restored.completionRecord?.id == id && restored.endDate == nil)
        restored.startFocus()
        assert(restored.phase == .completed, "Completion requires explicit next decision")
        restored.updateNote(id: id!, note: "成果")
        restored.startBreak()
        assert(restored.phase == .shortBreak && restored.remainingText() == "02:00")
        let restDeadline = restored.endDate
        restored.startBreak(); restored.togglePause()
        assert(restored.endDate == restDeadline && restored.phase == .shortBreak)
        clock = clock.addingTimeInterval(120); restored.refreshForCurrentTime()
        assert(restored.phase == .readyForFocus && restored.endDate == nil)
        restored.startFocus()
        clock = clock.addingTimeInterval(90); restored.refreshForCurrentTime()
        restored.endCurrentSession()
        assert(restored.phase == .idle && restored.records.last!.seconds == 90 && !restored.records.last!.completed)
        assert(restored.completedFocuses == 1 && restored.lastAbandonedRecordID == restored.records.last!.id)
        restored.endCurrentSession(); restored.resetToReady()
        assert(restored.records.count == 2 && restored.records.first!.note == "成果", "Repeated reset never erases or duplicates history")
        restored.startFocus()
        clock = clock.addingTimeInterval(600); restored.refreshForCurrentTime()
        assert(restored.phase == .completed && restored.completedFocuses == 2)
        let longReload = fresh()
        longReload.startBreak()
        assert(longReload.phase == .longBreak && longReload.remainingText() == "03:00", "Pending long break survives reload")
        longReload.resetToReady()
        assert(longReload.phase == .idle && longReload.endDate == nil && longReload.records.count == 3)
        longReload.startFocus(); clock = clock.addingTimeInterval(600); longReload.refreshForCurrentTime()
        longReload.resetToReady()
        assert(longReload.phase == .idle && longReload.records.last!.completed && longReload.completedFocuses == 3)
        // Legacy paused snapshots are not resumed or discarded on upgrade.
        let saved: [String: Any] = [
            "phase": "paused", "completedFocuses": 0, "focusCompletionDates": [],
            "pausedRemaining": 287.97857, "phaseBeforePause": "shortBreak", "activeDuration": 300.0
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: saved), forKey: "pangpang.pomodoro.snapshot")
        let pausedRest = fresh()
        assert(pausedRest.isPaused && pausedRest.isRestSession && pausedRest.remainingText() == "04:47")
        pausedRest.resetToReady()
        assert(pausedRest.phase == .idle && pausedRest.configuredFocusText == "10:00")
        let session = UUID()
        let legacyFocus: [String: Any] = [
            "phase": "paused", "completedFocuses": 0, "focusCompletionDates": [],
            "pausedRemaining": 1400.0, "phaseBeforePause": "focus", "activeDuration": 1500.0,
            "activeSessionID": session.uuidString, "startedAt": clock.timeIntervalSinceReferenceDate - 100
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: legacyFocus), forKey: "pangpang.pomodoro.snapshot")
        let pausedFocus = fresh()
        pausedFocus.resetToReady()
        assert(pausedFocus.records.count == 1 && pausedFocus.records[0].seconds == 100 && !pausedFocus.records[0].completed)
        defaults.set(try JSONSerialization.data(withJSONObject: legacyFocus), forKey: "pangpang.pomodoro.snapshot")
        let resumeLegacy = fresh()
        resumeLegacy.togglePause()
        assert(resumeLegacy.phase == .focus && resumeLegacy.remainingText() == "23:20")
        resumeLegacy.togglePause()
        assert(resumeLegacy.phase == .focus, "Resumed legacy focus cannot be paused again")
        let date = clock.timeIntervalSinceReferenceDate
        defaults.set(try JSONSerialization.data(withJSONObject: ["phase": "idle", "completedFocuses": 2,
            "focusCompletionDates": [date - 3000, date]]), forKey: "pangpang.pomodoro.snapshot")
        let migrated = fresh()
        assert(migrated.records.count == 2 && migrated.records.allSatisfy { $0.estimated })
        print("PASS: strict focus, no pause, reset guard, partial time, idempotency, explicit completion/rest/next focus")
        print("PASS: persisted completion, pending long break, notes, settings, visibility, legacy paused migration")
    }
}
