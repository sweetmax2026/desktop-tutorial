import Combine
import Foundation

enum PomodoroPhase: String, Codable { case idle, focus, shortBreak, longBreak, readyForFocus, paused }
enum BubbleAction { case dismiss, startNextFocus, startMeditation }

struct BubbleMessage {
    let text: String
    let actionTitle: String
    let action: BubbleAction
}

@MainActor
final class PomodoroStore: ObservableObject {
    @Published private(set) var phase: PomodoroPhase = .idle
    @Published private(set) var completedFocuses = 0
    @Published private(set) var focusCompletionDates: [Date] = []
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private var currentTime = Date()

    var onBubble: ((BubbleMessage) -> Void)?
    var onNotification: ((String, String) -> Void)?
    var onStateChange: (() -> Void)?

    private var timer: Timer?
    private var phaseBeforePause: PomodoroPhase?
    private let defaultsKey = "pangpang.pomodoro.snapshot"
    private let focusDuration: TimeInterval = 25 * 60
    private let shortBreakDuration: TimeInterval = 5 * 60
    private let longBreakDuration: TimeInterval = 10 * 60

    init() { restore(); startTimer() }
    deinit { timer?.invalidate() }

    var isPaused: Bool { phase == .paused }
    var canPause: Bool { phase == .focus || phase == .shortBreak || phase == .longBreak || phase == .paused }
    var canEnd: Bool { canPause }
    var primaryActionTitle: String { phase == .readyForFocus ? "开始下一轮专注" : "开始 25 分钟专注" }
    var statusText: String {
        switch phase {
        case .idle: return "pangpang · 未开始"
        case .focus: return "pangpang · 专注中"
        case .shortBreak: return "pangpang · 休息中"
        case .longBreak: return "pangpang · 长休息中"
        case .readyForFocus: return "pangpang · 等待下一轮"
        case .paused: return "pangpang · 已暂停"
        }
    }
    var phaseTitle: String {
        switch phase {
        case .idle: return "还没开始"
        case .focus: return "专注中"
        case .shortBreak: return "5 分钟休息中"
        case .longBreak: return "10 分钟长休息中"
        case .readyForFocus: return "准备下一轮"
        case .paused: return "已暂停"
        }
    }

    var focusCountToday: Int { focusCompletionDates.filter { Calendar.current.isDateInToday($0) }.count }
    var focusDailyCounts: [DailyCount] { dailyCounts(for: focusCompletionDates) }

    func remainingText(now: Date? = nil) -> String? {
        let now = now ?? currentTime
        let remaining = phase == .paused ? pausedRemaining : endDate.map { max(0, $0.timeIntervalSince(now)) }
        guard let remaining else { return nil }
        return String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60)
    }

    func startFocus() {
        phase = .focus; pausedRemaining = nil; endDate = Date().addingTimeInterval(focusDuration)
        announceStateChanged()
        onBubble?(BubbleMessage(text: "好，25 分钟。别分心。", actionTitle: "知道了", action: .dismiss))
    }

    func togglePause() {
        if phase == .paused {
            guard let pausedRemaining else { return }
            phase = phaseBeforePause ?? .focus
            endDate = Date().addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
            phaseBeforePause = nil
        } else if let endDate {
            phaseBeforePause = phase
            pausedRemaining = max(0, endDate.timeIntervalSinceNow)
            self.endDate = nil
            phase = .paused
        }
        announceStateChanged()
    }

    func endCurrentSession() {
        phase = .idle; endDate = nil; pausedRemaining = nil; phaseBeforePause = nil
        announceStateChanged()
    }

    func refreshForCurrentTime() {
        currentTime = Date()
        guard let endDate, endDate <= currentTime else { return }
        switch phase {
        case .focus:
            completedFocuses += 1
            focusCompletionDates.append(currentTime)
            if focusCompletionDates.count > 365 { focusCompletionDates.removeFirst(focusCompletionDates.count - 365) }
            let longBreak = completedFocuses % 4 == 0
            phase = longBreak ? .longBreak : .shortBreak
            self.endDate = Date().addingTimeInterval(longBreak ? longBreakDuration : shortBreakDuration)
            onBubble?(BubbleMessage(text: "Take a break.", actionTitle: "好", action: .dismiss))
            onNotification?("pangpang", "Take a break.")
        case .shortBreak, .longBreak:
            phase = .readyForFocus; self.endDate = nil
            onBubble?(BubbleMessage(text: "休息够了没？", actionTitle: "开始下一轮", action: .startNextFocus))
            onNotification?("pangpang", "休息结束。准备好开始下一轮了吗？")
        default: return
        }
        pausedRemaining = nil
        announceStateChanged()
    }

    func persist() {
        let snapshot = Snapshot(phase: phase, completedFocuses: completedFocuses, focusCompletionDates: focusCompletionDates, endDate: endDate, pausedRemaining: pausedRemaining, phaseBeforePause: phaseBeforePause)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        phase = snapshot.phase; completedFocuses = snapshot.completedFocuses; focusCompletionDates = snapshot.focusCompletionDates ?? []; endDate = snapshot.endDate
        pausedRemaining = snapshot.pausedRemaining; phaseBeforePause = snapshot.phaseBeforePause
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
    }
}
