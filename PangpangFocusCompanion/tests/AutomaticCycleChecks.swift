import Foundation

@main @MainActor enum AutomaticCycleChecks {
    static func main() throws {
        for (autoBreak, autoFocus) in [(true, true), (true, false), (false, true)] {
            for duringRest in [false, true] {
                let suite = "pangpang.test.cycle-toggle.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                var clock = Date()
                func load() -> PomodoroStore { PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false) }
                let store = load()
                store.updateSettings(FocusSettings(focusMinutes: 1, shortBreakMinutes: 1,
                    longBreakMinutes: 2, autoStartBreak: autoBreak, autoStartFocus: autoFocus))
                store.saveUnifiedTask(name: "保持本轮", focusMinutes: 1, presets: store.taskPresets)
                store.startFocus()
                if duringRest {
                    clock = store.endDate!; store.refreshForCurrentTime()
                    if store.phase == .completed { store.startBreak() }
                    precondition(store.isRestSession)
                }
                let deadline = store.endDate
                let phase = store.phase
                let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
                let records = try encoder.encode(store.records)
                store.toggleAutomaticCycle()
                precondition(!store.hasAutomaticTransitions && store.endDate == deadline && store.phase == phase)
                let restored = load()
                precondition(!restored.hasAutomaticTransitions)
                restored.toggleAutomaticCycle()
                precondition(restored.settings.autoStartBreak == autoBreak && restored.settings.autoStartFocus == autoFocus)
                precondition(restored.endDate == deadline && restored.phase == phase && restored.activeTask == "保持本轮")
                let after = try encoder.encode(restored.records)
                precondition(after == records && restored.settings.focusMinutes == 1 && restored.settings.shortBreakMinutes == 1)
                // Repeated switching and changing the detailed configuration must update what is restored.
                restored.toggleAutomaticCycle(); restored.toggleAutomaticCycle()
                precondition(restored.settings.autoStartBreak == autoBreak && restored.settings.autoStartFocus == autoFocus)
                clock = deadline!; restored.refreshForCurrentTime()
                precondition(restored.phase == (duringRest ? (autoFocus ? .focus : .readyForFocus) : (autoBreak ? .shortBreak : .completed)))
            }
        }
        let suite = "pangpang.test.cycle-first.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = PomodoroStore(defaults: defaults, schedulesTimer: false)
        first.toggleAutomaticCycle()
        precondition(first.settings.autoStartBreak && first.settings.autoStartFocus && first.phase == .idle)
        var changed = first.settings
        changed.autoStartBreak = false; first.updateSettings(changed)
        first.stopAutomaticCycle(); first.stopAutomaticCycle(); first.toggleAutomaticCycle()
        precondition(!first.settings.autoStartBreak && first.settings.autoStartFocus)
        changed.autoStartFocus = false; first.updateSettings(changed)
        let restored = PomodoroStore(defaults: defaults, schedulesTimer: false)
        restored.toggleAutomaticCycle()
        precondition(!restored.settings.autoStartBreak && restored.settings.autoStartFocus)
        precondition(restored.automaticCycleHelp.contains("等待手动开始休息"))
        print("PASS: cycle toggle restores all three combinations across restart and repeated clicks")
        print("PASS: focus/rest deadlines, tasks and records unchanged; restored options govern only the next transition")
        print("PASS: first enable uses full cycle, detailed settings update remembered options, repeated stop preserves options")
    }
}
