import Foundation

@main
enum StatisticsChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13))!
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let range = DateInterval(start: start, end: end)
        let ten = calendar.date(byAdding: .hour, value: 10, to: start)!
        let eleven = calendar.date(byAdding: .hour, value: 11, to: start)!
        let hourly = statisticsSamples(values: [(ten, 25), (eleven, 25), (end, 100), (start.addingTimeInterval(-1), 100)], range: range, hourly: true, calendar: calendar)
        assert(hourly.count == 24 && hourly.reduce(0) { $0 + $1.value } == 50)
        assert(hourly[10].value == 25 && hourly[11].value == 25)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: start)!
        let daily = statisticsSamples(values: [(ten, 25), (eleven, 25)], range: DateInterval(start: weekStart, end: end), hourly: false, calendar: calendar)
        assert(daily.count == 7 && daily.last!.value == 50 && daily.first!.value == 0)
        let yearStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let monthly = statisticsSamples(values: [(ten, 25)], range: DateInterval(start: yearStart, end: yearEnd), hourly: false, calendar: calendar)
        assert(monthly.count == 12 && monthly[9].value == 25)
        assert(statisticsSamples(values: [], range: range, hourly: true, calendar: calendar).allSatisfy { $0.value == 0 })
        print("PASS: hourly/daily/monthly totals, missing days zero, midnight exclusion, empty range")
    }
}
