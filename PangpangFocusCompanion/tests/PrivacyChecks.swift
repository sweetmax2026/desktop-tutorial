import Foundation

@main @MainActor enum PrivacyChecks {
    static func main() throws {
        let suite = "pangpang.test.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let focus = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        focus.saveUnifiedTask(name: "隐私验证任务", focusMinutes: 1, presets: focus.taskPresets)
        focus.startFocus()
        let deadline = focus.endDate
        precondition(!focus.deleteFocusHistory() && !focus.deleteSavedTasks())
        precondition(focus.endDate == deadline && focus.activeTask == "隐私验证任务")
        for index in 0..<367 {
            if index > 0 { focus.startFocus() }
            clock = clock.addingTimeInterval(60)
            focus.refreshForCurrentTime()
            focus.resetToReady()
        }
        precondition(focus.records.count == 367 && focus.focusCompletionDates.count == 367)
        let settings = focus.settings
        let tasks = focus.taskPresets.map(\.id)
        precondition(focus.deleteFocusHistory())
        let reloaded = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        precondition(reloaded.records.isEmpty && reloaded.focusCompletionDates.isEmpty && reloaded.completedFocuses == 0)
        precondition(reloaded.taskPresets.map(\.id) == tasks && reloaded.settings.focusMinutes == settings.focusMinutes)
        reloaded.startFocus(); clock = clock.addingTimeInterval(60); reloaded.refreshForCurrentTime(); reloaded.resetToReady()
        let recordID = reloaded.records[0].id
        precondition(reloaded.deleteSavedTasks())
        let noTasks = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        precondition(noTasks.taskPresets.isEmpty && noTasks.draftTask.isEmpty && noTasks.records[0].id == recordID)

        let wellbeing = WellbeingStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        for i in 0..<105 { wellbeing.recordMood(emoji: "", name: "平静", note: "测试\(i)") }
        let savedMoods = WellbeingStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        precondition(savedMoods.moodEntries.count == 105 && savedMoods.moodEntries.last?.note == "测试0")
        let dates = (0..<366).map { clock.addingTimeInterval(Double(-$0 * 60)) }
        defaults.set(try JSONEncoder().encode(dates), forKey: "pangpang.meditation.completions")
        let meditation = WellbeingStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        let reminders = meditation.meditationTimes
        meditation.startMeditation()
        precondition(!meditation.deleteMeditationHistory())
        clock = clock.addingTimeInterval(60); meditation.refreshMeditation()
        precondition(meditation.meditationCompletionDates.count == 367)
        meditation.deleteMoodHistory()
        precondition(meditation.moodEntries.isEmpty && meditation.meditationCompletionDates.count == 367)
        precondition(meditation.deleteMeditationHistory())
        let empty = WellbeingStore(defaults: defaults, schedulesTimer: false)
        precondition(empty.moodEntries.isEmpty && empty.meditationCompletionDates.isEmpty && empty.meditationTimes == reminders)
        let snapshot: [String: Any] = ["isEnabled": true, "blockedApplications": [
            ["bundleIdentifier": "test.fixture", "name": "Fixture", "path": "/test.app"]]]
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "pangpang.app-blocker.snapshot")
        let guardStore = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        guardStore.deleteSavedApplications()
        let guardReloaded = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        precondition(guardReloaded.blockedApplications.isEmpty && !guardReloaded.isEnabled)
        precondition(PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false).records[0].id == recordID)
        print("PASS: no silent truncation beyond 100 moods and 365 focus/meditation completions")
        print("PASS: per-category deletion persists, preserves other records/settings/reminders; active focus/meditation deletion blocked")
        print("PASS: task deletion stays empty after restart; guard list/bookmark removal disables guard")
    }
}
