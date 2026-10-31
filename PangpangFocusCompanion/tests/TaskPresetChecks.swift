import Foundation

@main @MainActor
enum TaskPresetChecks {
    static func main() throws {
        let suite = "pangpang.test.tasks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var clock = Date()
        func reload() -> PomodoroStore { PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false) }
        let store = reload()
        store.saveTaskConfiguration(name: "  阅读一章  ", category: "阅读", focusMinutes: 40)
        let firstID = store.taskPresets[0].id
        store.saveTaskConfiguration(name: "写作", category: "工作", focusMinutes: 25)
        store.saveTaskConfiguration(name: "阅读一章", category: "学习", focusMinutes: 50)
        assert(store.taskPresets.count == 2 && store.taskPresets[0].id == firstID)
        assert(store.taskPresets[0].focusMinutes == 50 && store.taskPresets[0].category == "学习")
        assert(reload().taskPresets[0].id == firstID, "Task identity, order and settings survive restart")
        let history = reload().taskPresets.last!
        store.saveTaskConfiguration(name: history.name, category: history.category, focusMinutes: history.focusMinutes)
        assert(store.draftTask == "写作" && store.draftCategory == "工作" && store.settings.focusMinutes == 25)
        let originalBreak = store.settings.shortBreakMinutes
        store.startFocus()
        let deadline = store.endDate
        store.saveTaskConfiguration(name: "不能覆盖进行中的任务", category: "其他", focusMinutes: 1)
        assert(store.endDate == deadline && store.settings.focusMinutes == 25 && store.activeTask == "写作")
        store.removeTaskPreset(id: history.id)
        assert(store.endDate == deadline && store.activeTask == "写作", "Deleting a preset must not change an active session")
        clock = clock.addingTimeInterval(1500)
        store.refreshForCurrentTime()
        let record = store.records[0]
        assert(record.task == "写作" && record.seconds == 1500 && record.completed)
        store.resetToReady()
        for preset in store.taskPresets { store.removeTaskPreset(id: preset.id) }
        let empty = reload()
        assert(empty.taskPresets.isEmpty && empty.records.count == 1 && empty.records[0].id == record.id,
               "Removed tasks must not be reimported from unchanged completed records")
        empty.saveTaskConfiguration(name: "  ", category: "专注", focusMinutes: 180)
        assert(empty.taskPresets.isEmpty && empty.settings.focusMinutes == 180 && empty.settings.shortBreakMinutes == originalBreak)
        empty.saveTaskConfiguration(name: String(repeating: "长", count: 100), category: "学习", focusMinutes: 999)
        assert(empty.draftTask.count == 80 && empty.settings.focusMinutes == 180)
        empty.saveTaskConfiguration(name: "下限", category: "", focusMinutes: 0)
        assert(empty.settings.focusMinutes == 1 && empty.draftCategory == "专注")
        // One-time upgrade imports an existing real task without changing history.
        defaults.removeObject(forKey: "pangpang.focus.task-presets.v1")
        let migrated = reload()
        assert(migrated.taskPresets.count == 1 && migrated.taskPresets[0].name == "写作")
        assert(migrated.taskPresets[0].focusMinutes == 25 && migrated.records[0].id == record.id)
        migrated.removeTaskPreset(id: migrated.taskPresets[0].id)
        assert(reload().taskPresets.isEmpty && reload().records.count == 1)
        print("PASS: task creation, deduplication, recency, restore, configuration selection and duration bounds")
        print("PASS: active deadline unchanged, deleted presets stay deleted, completed records unchanged, one-time migration")
    }
}
