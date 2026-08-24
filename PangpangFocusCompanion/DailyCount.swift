import Foundation

struct DailyCount: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
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
