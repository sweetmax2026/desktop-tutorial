import Combine
import Foundation

struct MeditationTime: Codable, Hashable, Identifiable {
    let hour: Int
    let minute: Int

    var id: String { "\(hour)-\(minute)" }
    var displayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now)
    }
}

struct MoodEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let emoji: String
    let name: String
    let note: String?
}

@MainActor
final class WellbeingStore: ObservableObject {
    @Published private(set) var meditationTimes: [MeditationTime]
    @Published private(set) var meditationEndDate: Date?
    @Published private(set) var meditationSessionID = UUID()
    @Published private(set) var meditationCompletionDates: [Date]
    @Published private(set) var moodEntries: [MoodEntry]
    @Published private var currentTime = Date()

    var onMeditationScheduleChanged: (([MeditationTime]) -> Void)?
    var onMeditationReminderDue: (() -> Void)?
    var onStateChange: (() -> Void)?

    private let timesKey = "pangpang.meditation.times"
    private let moodsKey = "pangpang.mood.entries"
    private let meditationCompletionsKey = "pangpang.meditation.completions"
    private let lastMeditationReminderKey = "pangpang.meditation.lastReminderMinute"
    private var timer: Timer?

    init() {
        let defaults = [MeditationTime(hour: 11, minute: 0), MeditationTime(hour: 16, minute: 30), MeditationTime(hour: 20, minute: 0)]
        meditationTimes = UserDefaults.standard.data(forKey: timesKey).flatMap { try? JSONDecoder().decode([MeditationTime].self, from: $0) } ?? defaults
        moodEntries = UserDefaults.standard.data(forKey: moodsKey).flatMap { try? JSONDecoder().decode([MoodEntry].self, from: $0) } ?? []
        meditationCompletionDates = UserDefaults.standard.data(forKey: meditationCompletionsKey).flatMap { try? JSONDecoder().decode([Date].self, from: $0) } ?? []
        startTimer()
    }

    deinit { timer?.invalidate() }

    var isMeditating: Bool { meditationEndDate != nil }
    var meditationRemainingText: String? {
        guard let meditationEndDate else { return nil }
        let remaining = max(0, meditationEndDate.timeIntervalSince(currentTime))
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func startMeditation() {
        let now = Date()
        currentTime = now
        meditationEndDate = now.addingTimeInterval(60)
        meditationSessionID = UUID()
        onStateChange?()
    }

    func addMeditationTime(hour: Int, minute: Int) {
        let item = MeditationTime(hour: hour, minute: minute)
        guard !meditationTimes.contains(item) else { return }
        meditationTimes.append(item)
        meditationTimes.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        persistTimes()
    }

    func removeMeditationTime(_ item: MeditationTime) {
        meditationTimes.removeAll { $0 == item }
        persistTimes()
    }

    func refreshMeditationReminders() { onMeditationScheduleChanged?(meditationTimes) }

    func recordMood(emoji: String, name: String, note: String) {
        let trimmedNote = String(note.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
        moodEntries.insert(MoodEntry(id: UUID(), createdAt: .now, emoji: emoji, name: name, note: trimmedNote.isEmpty ? nil : trimmedNote), at: 0)
        if moodEntries.count > 100 { moodEntries = Array(moodEntries.prefix(100)) }
        guard let data = try? JSONEncoder().encode(moodEntries) else { return }
        UserDefaults.standard.set(data, forKey: moodsKey)
    }

    func moodCountToday() -> Int {
        moodEntries.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    var moodDailyCounts: [DailyCount] { dailyCounts(for: moodEntries.map(\.createdAt)) }
    var meditationCountToday: Int { meditationCompletionDates.filter { Calendar.current.isDateInToday($0) }.count }
    var meditationDailyCounts: [DailyCount] { dailyCounts(for: meditationCompletionDates) }

    private func persistTimes() {
        guard let data = try? JSONEncoder().encode(meditationTimes) else { return }
        UserDefaults.standard.set(data, forKey: timesKey)
        refreshMeditationReminders()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshMeditation() }
        }
    }

    private func refreshMeditation() {
        currentTime = Date()
        checkScheduledMeditationReminder(at: currentTime)
        guard let meditationEndDate, meditationEndDate <= currentTime else { return }
        self.meditationEndDate = nil
        meditationCompletionDates.append(currentTime)
        if meditationCompletionDates.count > 365 { meditationCompletionDates.removeFirst(meditationCompletionDates.count - 365) }
        if let data = try? JSONEncoder().encode(meditationCompletionDates) {
            UserDefaults.standard.set(data, forKey: meditationCompletionsKey)
        }
        onStateChange?()
    }

    private func checkScheduledMeditationReminder(at date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let hour = components.hour,
              let minute = components.minute,
              meditationTimes.contains(where: { $0.hour == hour && $0.minute == minute }) else { return }

        let minuteKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(hour)-\(minute)"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastMeditationReminderKey) != minuteKey else { return }
        defaults.set(minuteKey, forKey: lastMeditationReminderKey)
        onMeditationReminderDue?()
    }
}
