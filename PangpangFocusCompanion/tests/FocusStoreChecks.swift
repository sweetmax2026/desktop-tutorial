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
        var completionCards = 0
        store.onBubble = { message in
            if message.action == .viewFocusResult {
                completionCards += 1
                assert(message.actionTitle == "查看收获" && message.secondaryTitle == "稍后查看")
            }
        }
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
        assert(completionCards == 1, "Completion must emit a local reminder independently of notification permission")
        assert(store.records[0].category == "阅读" && store.records[0].task == "测试任务")
        store.refreshForCurrentTime()
        assert(completionCards == 1, "Repeated refresh must not duplicate the completion reminder")
        clock = clock.addingTimeInterval(86400)
        store.refreshForCurrentTime()
        assert(store.phase == .completed && store.records.count == 1, "Waiting for rest never runs a hidden clock")
        let restored = fresh()
        assert(restored.phase == .completed && restored.completionRecord?.id == id && restored.endDate == nil)
        var replayedCards = 0
        restored.onBubble = { if $0.action == .viewFocusResult { replayedCards += 1 } }
        assert(replayedCards == 0, "Reload must not repeat an already shown completion")
        defaults.removeObject(forKey: "pangpang.focus.lastCompletionReminder")
        let pendingReminder = fresh()
        pendingReminder.onBubble = { if $0.action == .viewFocusResult { replayedCards += 1 } }
        assert(replayedCards == 1, "Completion restored before callback wiring must replay once")
        pendingReminder.onBubble = { if $0.action == .viewFocusResult { replayedCards += 1 } }
        assert(replayedCards == 1, "Rebinding presentation must not duplicate a reminder")
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
        assert(longReload.phase == .shortBreak && longReload.remainingText() == "02:00", "Yesterday's rounds must not trigger today's long break after reload")
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
        // Existing settings retain all durations, with both new switches off.
        let oldSettings = try JSONDecoder().decode(FocusSettings.self, from: Data(
            "{\"focusMinutes\":40,\"shortBreakMinutes\":7,\"longBreakMinutes\":15,\"longBreakInterval\":3}".utf8))
        assert(oldSettings.focusMinutes == 40 && oldSettings.shortBreakMinutes == 7 &&
            oldSettings.longBreakMinutes == 15 && oldSettings.longBreakInterval == 3)
        assert(!oldSettings.autoStartBreak && !oldSettings.autoStartFocus)
        for automaticRest in [false, true] {
            for automaticFocus in [false, true] {
                defaults.removePersistentDomain(forName: suite)
                let cycle = fresh()
                cycle.updateSettings(FocusSettings(focusMinutes: 1, shortBreakMinutes: 1,
                    longBreakMinutes: 2, longBreakInterval: 2,
                    autoStartBreak: automaticRest, autoStartFocus: automaticFocus))
                assert(fresh().settings == cycle.settings, "Both independent switches persist")
                var bubbles: [BubbleMessage] = []
                var guardStates: [Bool] = []
                cycle.onBubble = { bubbles.append($0) }
                cycle.onStateChange = { guardStates.append(cycle.phase == .focus) }
                cycle.draftTask = "同一个任务"; cycle.draftCategory = "阅读"
                cycle.startFocus()
                clock = clock.addingTimeInterval(60); cycle.refreshForCurrentTime()
                assert(cycle.records.count == 1 && cycle.records[0].completed)
                assert(cycle.phase == (automaticRest ? .shortBreak : .completed))
                assert(guardStates.last == false, "Guard releases on completion or automatic rest")
                assert(bubbles.count == 1 && bubbles[0].detail.contains(automaticRest ? "已自动开始休息" : "准备好了再休息"))
                cycle.refreshForCurrentTime()
                assert(bubbles.count == 1 && cycle.records.count == 1)
                if !automaticRest { cycle.startBreak() }
                clock = clock.addingTimeInterval(60); cycle.refreshForCurrentTime()
                assert(cycle.phase == (automaticFocus ? .focus : .readyForFocus))
                assert(guardStates.last == automaticFocus, "Guard reactivates only for focus")
                assert(bubbles.last!.action == (automaticFocus ? .dismiss : .startNextFocus))
                if !automaticFocus { cycle.startFocus() }
                assert(cycle.activeTask == "同一个任务" && cycle.activeCategory == "阅读")
                clock = clock.addingTimeInterval(60); cycle.refreshForCurrentTime()
                assert(cycle.records.count == 2 && cycle.completedFocuses == 2)
                if !automaticRest { cycle.startBreak() }
                assert(cycle.phase == .longBreak && cycle.remainingText() == "02:00")
                // Manual end interrupts the loop; changing switches never starts a timer.
                cycle.endCurrentSession()
                clock = clock.addingTimeInterval(500); cycle.refreshForCurrentTime()
                assert(cycle.phase == .idle && cycle.records.count == 2)
                cycle.startFocus(); clock = clock.addingTimeInterval(10)
                cycle.endCurrentSession(); clock = clock.addingTimeInterval(100)
                cycle.refreshForCurrentTime()
                assert(cycle.phase == .idle && cycle.records.count == 3 && !cycle.records.last!.completed)
            }
        }
        defaults.removePersistentDomain(forName: suite)
        let automatic = fresh()
        automatic.updateSettings(FocusSettings(focusMinutes: 1, shortBreakMinutes: 1,
            autoStartBreak: true, autoStartFocus: true))
        automatic.draftTask = "重启后继续"; automatic.draftCategory = "工作"
        automatic.startFocus()
        let originalDeadline = automatic.endDate
        automatic.updateSettings(automatic.settings)
        assert(automatic.endDate == originalDeadline)
        clock = clock.addingTimeInterval(86400)
        let afterOffline = fresh()
        assert(afterOffline.records.count == 1 && afterOffline.phase == .shortBreak)
        assert(afterOffline.endDate == clock.addingTimeInterval(60), "No offline fabricated rounds or expired new phases")
        var startupBubbles: [BubbleMessage] = []
        afterOffline.onBubble = { startupBubbles.append($0) }
        assert(startupBubbles.count == 1 && startupBubbles[0].detail.contains("已自动开始休息"))
        clock = clock.addingTimeInterval(60)
        let resumedCycle = fresh()
        assert(resumedCycle.phase == .focus && resumedCycle.activeTask == "重启后继续")
        assert(resumedCycle.records.count == 1 && resumedCycle.endDate == clock.addingTimeInterval(60))
        resumedCycle.refreshForCurrentTime()
        assert(resumedCycle.records.count == 1, "Repeated refresh cannot duplicate a completion")
        // Three rounds yesterday + today's first must not trigger a long rest.
        defaults.removePersistentDomain(forName: suite)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        clock = calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(12 * 3600)
        let daily = fresh()
        daily.updateSettings(FocusSettings(focusMinutes: 1, shortBreakMinutes: 1,
            longBreakMinutes: 2, longBreakInterval: 4, autoStartBreak: true))
        for _ in 0..<3 {
            daily.startFocus(); clock = clock.addingTimeInterval(60)
            daily.refreshForCurrentTime(); daily.endCurrentSession()
        }
        clock = today.addingTimeInterval(12 * 3600)
        let newDay = fresh()
        for round in 1...4 {
            newDay.startFocus(); clock = clock.addingTimeInterval(60)
            newDay.refreshForCurrentTime()
            assert(newDay.phase == (round == 4 ? .longBreak : .shortBreak))
            assert(newDay.remainingText() == (round == 4 ? "02:00" : "01:00"))
            newDay.endCurrentSession()
        }
        assert(newDay.records.count == 7 && newDay.completedFocuses == 7)
        // Crossing midnight belongs to the finish day. Reload keeps a running rest.
        clock = calendar.date(byAdding: .day, value: 1, to: today)!.addingTimeInterval(-30)
        newDay.startFocus()
        let overnightDeadline = newDay.endDate
        let overnight = fresh()
        assert(overnight.endDate == overnightDeadline && overnight.phase == .focus)
        clock = clock.addingTimeInterval(60); overnight.refreshForCurrentTime()
        assert(overnight.phase == .shortBreak && overnight.records.count == 8)
        let nextRest = fresh()
        assert(nextRest.phase == .shortBreak && nextRest.endDate == overnight.endDate)
        // Correct a legacy completed state, but never shorten an already-started rest.
        var legacyDaily = try JSONSerialization.jsonObject(with: defaults.data(forKey: "pangpang.pomodoro.snapshot")!) as! [String: Any]
        legacyDaily["phase"] = "completed"; legacyDaily.removeValue(forKey: "endDate")
        legacyDaily["pendingLongBreak"] = true; legacyDaily["focusesSinceLongBreak"] = 0
        defaults.set(try JSONSerialization.data(withJSONObject: legacyDaily), forKey: "pangpang.pomodoro.snapshot")
        let corrected = fresh()
        corrected.startBreak()
        assert(corrected.phase == .shortBreak && corrected.remainingText() == "01:00")
        legacyDaily["phase"] = "longBreak"; legacyDaily["activeDuration"] = 120
        legacyDaily["endDate"] = clock.addingTimeInterval(120).timeIntervalSinceReferenceDate
        defaults.set(try JSONSerialization.data(withJSONObject: legacyDaily), forKey: "pangpang.pomodoro.snapshot")
        let activeRest = fresh()
        assert(activeRest.phase == .longBreak && activeRest.remainingText() == "02:00")
        assert(activeRest.records.count == 8 && activeRest.records.allSatisfy { $0.completed })
        // The shortcut must stop the next transition, never the current timer.
        for stopDuringRest in [false, true] {
            let cycleSuite = "pangpang.test.stop-cycle.\(UUID().uuidString)"
            let cycleDefaults = UserDefaults(suiteName: cycleSuite)!
            defer { cycleDefaults.removePersistentDomain(forName: cycleSuite) }
            var cycleClock = Date()
            let cycle = PomodoroStore(defaults: cycleDefaults, now: { cycleClock }, schedulesTimer: false)
            cycle.updateSettings(FocusSettings(focusMinutes: 1, shortBreakMinutes: 1,
                longBreakMinutes: 2, autoStartBreak: true, autoStartFocus: true))
            cycle.draftTask = "保留当前任务"
            cycle.startFocus()
            if stopDuringRest {
                cycleClock = cycleClock.addingTimeInterval(60)
                cycle.refreshForCurrentTime()
                assert(cycle.isRestSession)
            }
            let deadline = cycle.endDate
            let phase = cycle.phase
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let records = try encoder.encode(cycle.records)
            cycle.stopAutomaticCycle()
            cycle.stopAutomaticCycle()
            assert(!cycle.hasAutomaticTransitions && cycle.endDate == deadline && cycle.phase == phase)
            assert(cycle.activeTask == "保留当前任务" && cycle.settings.focusMinutes == 1)
            let afterRecords = try encoder.encode(cycle.records)
            assert(afterRecords == records)
            let restored = PomodoroStore(defaults: cycleDefaults, now: { cycleClock }, schedulesTimer: false)
            assert(!restored.hasAutomaticTransitions && restored.endDate == deadline && restored.phase == phase)
            cycleClock = deadline!
            restored.refreshForCurrentTime()
            assert(restored.phase == (stopDuringRest ? .readyForFocus : .completed))
            assert(restored.endDate == nil && restored.records.count == 1 && restored.records[0].completed)
        }
        print("PASS: stop automatic cycle during focus/rest preserves deadline, task, records and durations; persists and prevents next transition")
        print("PASS: strict focus, no pause, reset guard, partial time, idempotency, explicit completion/rest/next focus")
        print("PASS: persisted completion, pending long break, notes, settings, visibility, legacy paused migration")
        print("PASS: local completion reminder, startup replay, persistent per-record deduplication")
        print("PASS: legacy settings migration, four auto-switch combinations, persistence, long breaks, guard phase signals, manual stop, reminder copy, offline recovery without fabricated rounds")
        print("PASS: daily long-break count, yesterday three plus today one, fourth daily round, midnight focus/reload, legacy pending rest repair, active rest and history preservation")
    }
}
