import Foundation

struct DailyCount: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

struct StatisticsSample: Identifiable {
    let date: Date
    var value: Double
    var id: Date { date }
}

// Half-open ranges avoid counting a midnight record in both adjacent days.
// Hourly values are grouped by record completion, not estimated pause timestamps.
func statisticsSamples(values: [(Date, Double)], range: DateInterval, hourly: Bool,
                       calendar: Calendar = .current) -> [StatisticsSample] {
    let component: Calendar.Component = hourly ? .hour : range.duration > 62 * 86400 ? .month : .day
    var cursor = calendar.dateInterval(of: component, for: range.start)?.start ?? range.start
    var result: [StatisticsSample] = []
    let filtered = values.filter { $0.0 >= range.start && $0.0 < range.end }
    let grouped = Dictionary(grouping: filtered) { calendar.dateInterval(of: component, for: $0.0)?.start ?? $0.0 }
    while cursor < range.end {
        result.append(StatisticsSample(date: cursor, value: grouped[cursor, default: []].reduce(0) { $0 + max(0, $1.1) }))
        guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
        cursor = next
    }
    return result
}

func dailyCounts(for dates: [Date], days: Int = 7) -> [DailyCount] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return (0..<days).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        let count = dates.filter { calendar.isDate($0, inSameDayAs: date) }.count
        return DailyCount(date: date, count: count)
    }
}
