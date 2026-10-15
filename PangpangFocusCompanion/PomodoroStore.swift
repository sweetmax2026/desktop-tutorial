import Combine
import Foundation

enum AppBrand {
    static let name = "Pang 大师"
    static let wordmark = "Pāng 大师"
    static let subtitle = "猫咪陪伴番茄钟"
}

enum PomodoroPhase: String, Codable { case idle, focus, shortBreak, longBreak, readyForFocus, paused, completed }
enum BubbleAction { case dismiss, startNextFocus, startMeditation }

struct BubbleMessage {
    let text: String
    let actionTitle: String
    let action: BubbleAction
    var detail: String = ""
    var symbol: String = "checkmark.shield"
    var secondaryTitle: String? {
        switch action {
        case .dismiss: return nil
        case .startNextFocus: return "稍后开始"
        case .startMeditation: return "暂时不用"
        }
    }
}

struct FocusRecord: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let seconds: TimeInterval
    let category: String
    let task: String
    let completed: Bool
    let estimated: Bool
    var note: String
}

struct FocusSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 10
    var longBreakInterval = 4
    var validated: FocusSettings {
        FocusSettings(focusMinutes: min(180, max(1, focusMinutes)),
            shortBreakMinutes: min(60, max(1, shortBreakMinutes)),
            longBreakMinutes: min(120, max(1, longBreakMinutes)),
            longBreakInterval: min(12, max(1, longBreakInterval)))
    }
}

@MainActor
final class PomodoroStore: ObservableObject {
    @Published private(set) var phase: PomodoroPhase = .idle
    @Published private(set) var completedFocuses = 0
    @Published private(set) var focusCompletionDates: [Date] = []
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private var currentTime = Date()
    @Published private(set) var records: [FocusRecord] = []
    @Published private(set) var activeSessionID: UUID?
    @Published private(set) var completionRecordID: UUID?
    @Published private(set) var lastAbandonedRecordID: UUID?
    private var pendingLongBreak = false
    @Published var draftTask = ""
    @Published var draftCategory = "专注"
    @Published private(set) var activeTask = ""
    @Published private(set) var activeCategory = "专注"
    @Published private(set) var settings = FocusSettings()
    private var activeDuration: TimeInterval = 1500
    private var focusesSinceLongBreak = 0
    @Published var showsMiniCard: Bool {
        didSet {
            defaults.set(showsMiniCard, forKey: "pangpang.focus.miniCard")
            onPresentationChange?()
        }
    }
    @Published var showsFloatingEntry: Bool {
        didSet {
            defaults.set(showsFloatingEntry, forKey: "pangpang.floatingEntry.enabled")
            onFloatingEntryChange?()
        }
    }
    var onFloatingEntryChange: (() -> Void)?
    private var startedAt: Date?
    private let defaults: UserDefaults
    private let now: () -> Date
    var onPresentationChange: (() -> Void)?
    var onFocusFinished: ((FocusRecord) -> Void)?

    var onBubble: ((BubbleMessage) -> Void)?
    var onNotification: ((String, String) -> Void)?
    var onStateChange: (() -> Void)?

    private var timer: Timer?
    private var phaseBeforePause: PomodoroPhase?
    private let defaultsKey = "pangpang.pomodoro.snapshot"
    private var focusDuration: TimeInterval { TimeInterval(settings.focusMinutes * 60) }
    private var shortBreakDuration: TimeInterval { TimeInterval(settings.shortBreakMinutes * 60) }
    private var longBreakDuration: TimeInterval { TimeInterval(settings.longBreakMinutes * 60) }
    private let settingsKey = "pangpang.focus.settings.v1"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, schedulesTimer: Bool = true) {
        self.defaults = defaults
        self.now = now
        showsMiniCard = defaults.object(forKey: "pangpang.focus.miniCard") as? Bool ?? true
        showsFloatingEntry = defaults.bool(forKey: "pangpang.floatingEntry.enabled")
        currentTime = now()
        if let data = defaults.data(forKey: settingsKey), let saved = try? JSONDecoder().decode(FocusSettings.self, from: data) {
            settings = saved.validated
        }
        restore()
        if schedulesTimer { startTimer() }
    }
    deinit { timer?.invalidate() }

    var isPaused: Bool { phase == .paused }
    var isRestSession: Bool {
        phase == .shortBreak || phase == .longBreak ||
        (phase == .paused && (phaseBeforePause == .shortBreak || phaseBeforePause == .longBreak))
    }
    // Kept for source compatibility. New sessions cannot be paused from any surface.
    var canPause: Bool { false }
    var hasActiveSession: Bool { phase == .focus || isRestSession || isPaused }
    var canEnd: Bool { hasActiveSession }
    var completionRecord: FocusRecord? { records.first { $0.id == completionRecordID } }
    var lastAbandonedRecord: FocusRecord? { records.first { $0.id == lastAbandonedRecordID } }
    var primaryActionTitle: String { phase == .readyForFocus ? "开始下一轮专注" : "开始 \(settings.focusMinutes) 分钟专注" }
    var configuredFocusText: String { String(format: "%02d:00", settings.focusMinutes) }
    func updateSettings(_ value: FocusSettings) {
        settings = value.validated
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
        // The active phase keeps its deadline and original duration, including when paused.
        onPresentationChange?()
        onStateChange?()
    }
    var statusText: String {
        switch phase {
        case .idle: return "\(AppBrand.name) · 未开始"
        case .focus: return "\(AppBrand.name) · 专注中"
        case .shortBreak: return "\(AppBrand.name) · 休息中"
        case .longBreak: return "\(AppBrand.name) · 长休息中"
        case .readyForFocus: return "\(AppBrand.name) · 等待下一轮"
        case .paused: return "\(AppBrand.name) · 已暂停"
        case .completed: return "\(AppBrand.name) · 本轮完成"
        }
    }
    var phaseTitle: String {
        switch phase {
        case .idle: return "还没开始"
        case .focus: return "专注中"
        case .shortBreak: return "\(Int(activeDuration / 60)) 分钟休息中"
        case .longBreak: return "\(Int(activeDuration / 60)) 分钟长休息中"
        case .readyForFocus: return "准备下一轮"
        case .paused: return "已暂停"
        case .completed: return "这一轮，完成了"
        }
    }

    var focusCountToday: Int { focusCompletionDates.filter { Calendar.current.isDateInToday($0) }.count }
    var focusDailyCounts: [DailyCount] { dailyCounts(for: focusCompletionDates) }
    var todayRecords: [FocusRecord] { records.filter { Calendar.current.isDateInToday($0.endedAt) } }
    var todayMinutes: Int { Int(todayRecords.reduce(0) { $0 + $1.seconds } / 60) }
    var latestCompleted: FocusRecord? { records.last(where: { $0.completed }) }
    var progress: Double {
        let duration = activeDuration
        let remaining = pausedRemaining ?? endDate.map { max(0, $0.timeIntervalSince(currentTime)) } ?? duration
        return min(1, max(0, 1 - remaining / duration))
    }

    func updateNote(id: UUID, note: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].note = String(note.prefix(100))
        persist()
    }

    func remainingText(now: Date? = nil) -> String? {
        let now = now ?? currentTime
        let remaining = phase == .paused ? pausedRemaining : endDate.map { max(0, $0.timeIntervalSince(now)) }
        guard let remaining else { return nil }
        // Preserve the existing second display for fractional legacy snapshots.
        let seconds = Int(remaining)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func startFocus() {
        guard phase == .idle || phase == .readyForFocus else { return }
        completionRecordID = nil; lastAbandonedRecordID = nil
        currentTime = now()
        startedAt = currentTime
        activeSessionID = UUID()
        activeTask = String(draftTask.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        activeCategory = draftCategory
        activeDuration = focusDuration
        phase = .focus; pausedRemaining = nil; endDate = now().addingTimeInterval(focusDuration)
        announceStateChanged()
    }

    func togglePause() {
        // Only resume an explicitly paused legacy snapshot. Never introduce new pauses.
        guard phase == .paused else { return }
        if phase == .paused {
            guard let pausedRemaining else { return }
            phase = phaseBeforePause ?? .focus
            endDate = now().addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
            phaseBeforePause = nil
        }
        announceStateChanged()
    }

    func startBreak() {
        guard phase == .completed else { return }
        currentTime = now()
        phase = pendingLongBreak ? .longBreak : .shortBreak
        activeDuration = pendingLongBreak ? longBreakDuration : shortBreakDuration
        completionRecordID = nil
        endDate = currentTime.addingTimeInterval(activeDuration)
        announceStateChanged()
    }

    /// Reset is never a shortcut around the deliberate focus abandonment gesture.
    func resetToReady() {
        guard phase != .focus else { return }
        endCurrentSession()
    }

    func endCurrentSession() {
        if phase == .focus, let endDate, endDate <= now() {
            refreshForCurrentTime()
            return
        }
        if phase == .focus || (phase == .paused && phaseBeforePause == .focus) {
            let remaining = pausedRemaining ?? endDate.map { max(0, $0.timeIntervalSince(now())) } ?? activeDuration
            if let startedAt, let activeSessionID, activeDuration - remaining >= 1 {
                records.append(FocusRecord(id: activeSessionID, startedAt: startedAt, endedAt: now(),
                    seconds: min(activeDuration, max(0, activeDuration - remaining)), category: activeCategory,
                    task: activeTask, completed: false, estimated: false, note: ""))
                lastAbandonedRecordID = activeSessionID
            }
        }
        activeSessionID = nil; startedAt = nil
        phase = .idle; endDate = nil; pausedRemaining = nil; phaseBeforePause = nil
        completionRecordID = nil
        announceStateChanged()
    }

    func refreshForCurrentTime() {
        currentTime = now()
        guard let endDate, endDate <= currentTime else { return }
        switch phase {
        case .focus:
            let record = FocusRecord(id: activeSessionID ?? UUID(), startedAt: startedAt ?? endDate.addingTimeInterval(-activeDuration),
                endedAt: endDate, seconds: activeDuration, category: activeCategory, task: activeTask,
                completed: true, estimated: startedAt == nil, note: "")
            records.append(record)
            activeSessionID = nil; startedAt = nil
            completedFocuses += 1
            focusCompletionDates.append(endDate)
            if focusCompletionDates.count > 365 { focusCompletionDates.removeFirst(focusCompletionDates.count - 365) }
            focusesSinceLongBreak += 1
            let longBreak = focusesSinceLongBreak >= settings.longBreakInterval
            if longBreak { focusesSinceLongBreak = 0 }
            pendingLongBreak = longBreak
            completionRecordID = record.id
            phase = .completed
            self.endDate = nil
            onFocusFinished?(record)
            onNotification?(AppBrand.name, "这一轮完成了，猫爪已收好。准备好了再休息。")
        case .shortBreak, .longBreak:
            phase = .readyForFocus; self.endDate = nil
            onBubble?(BubbleMessage(text: "休息结束啦", actionTitle: "开始下一轮", action: .startNextFocus, detail: "准备好了，再开始下一轮。", symbol: "play.circle"))
            onNotification?(AppBrand.name, "休息结束。准备好开始下一轮了吗？")
        default: return
        }
        pausedRemaining = nil
        announceStateChanged()
    }

    func persist() {
        let snapshot = Snapshot(phase: phase, completedFocuses: completedFocuses, focusCompletionDates: focusCompletionDates, endDate: endDate, pausedRemaining: pausedRemaining, phaseBeforePause: phaseBeforePause, records: records, startedAt: startedAt, activeSessionID: activeSessionID, activeTask: activeTask, activeCategory: activeCategory, activeDuration: activeDuration, focusesSinceLongBreak: focusesSinceLongBreak, completionRecordID: completionRecordID, pendingLongBreak: pendingLongBreak)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private func restore() {
        guard let data = defaults.data(forKey: defaultsKey), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        phase = snapshot.phase; completedFocuses = snapshot.completedFocuses; focusCompletionDates = snapshot.focusCompletionDates ?? []; endDate = snapshot.endDate
        pausedRemaining = snapshot.pausedRemaining; phaseBeforePause = snapshot.phaseBeforePause
        records = snapshot.records ?? focusCompletionDates.map {
            FocusRecord(id: UUID(), startedAt: $0.addingTimeInterval(-1500), endedAt: $0,
                seconds: 1500, category: "专注", task: "", completed: true, estimated: true, note: "")
        }
        startedAt = snapshot.startedAt
        activeSessionID = snapshot.activeSessionID
        completionRecordID = snapshot.completionRecordID
        pendingLongBreak = snapshot.pendingLongBreak ?? false
        activeTask = snapshot.activeTask ?? ""
        activeCategory = snapshot.activeCategory ?? "专注"
        let restoredPhase = phase == .paused ? (phaseBeforePause ?? .focus) : phase
        activeDuration = snapshot.activeDuration ?? (restoredPhase == .longBreak ? 600 : restoredPhase == .shortBreak ? 300 : 1500)
        focusesSinceLongBreak = snapshot.focusesSinceLongBreak ?? (completedFocuses % 4)
        refreshForCurrentTime()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshForCurrentTime()
            }
        }
    }
    private func announceStateChanged() { persist(); onStateChange?() }

    private struct Snapshot: Codable {
        let phase: PomodoroPhase
        let completedFocuses: Int
        let focusCompletionDates: [Date]?
        let endDate: Date?
        let pausedRemaining: TimeInterval?
        let phaseBeforePause: PomodoroPhase?
        let records: [FocusRecord]?
        let startedAt: Date?
        let activeSessionID: UUID?
        let activeTask: String?
        let activeCategory: String?
        let activeDuration: TimeInterval?
        let focusesSinceLongBreak: Int?
        let completionRecordID: UUID?
        let pendingLongBreak: Bool?
    }
}
