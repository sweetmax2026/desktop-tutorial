import SwiftUI

private enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case today = "今天"
    case week = "近 7 天"
    case month = "近 30 天"
    case custom = "日期"
    var id: Self { self }
}

private enum StatisticsMetric: String, CaseIterable, Identifiable {
    case all = "全部"
    case focus = "番茄钟"
    case meditation = "冥想"
    case mood = "情绪"
    var id: Self { self }
}

struct StatisticsView: View {
    @ObservedObject var pomodoro: PomodoroStore
    @ObservedObject var wellbeing: WellbeingStore
    @State private var period: StatisticsPeriod = .today
    @State private var metric: StatisticsMetric = .all
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var customEnd = Date()
    @State private var showsCustomPicker = false
    @State private var selectedDay: DailyCount?
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Text("数据详情").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 15) {
                    pickerRow
                    if period == .custom { customDatePickers }
                    summaryCards
                    trendSection
                    detailsSection
                }
                .padding(.bottom, 4)
            }
        }
        .padding(18)
        .frame(width: 460, height: 560, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .sheet(item: $selectedDay) { day in
            DailyDetailSheet(
                day: day.date,
                focusDates: focusDates,
                meditationDates: meditationDates,
                moodEntries: moodEntries
            )
        }
    }

    private var pickerRow: some View {
        HStack(spacing: 8) {
            Picker("时间范围", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _, newValue in
                if newValue == .custom { showsCustomPicker = true }
            }
            Button { showsCustomPicker = true } label: { Image(systemName: "calendar") }
                .buttonStyle(.bordered)
                .popover(isPresented: $showsCustomPicker, arrowEdge: .top) { customDatePickers }
        }
    }

    private var customDatePickers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择日期范围").font(.system(size: 13, weight: .semibold))
            DatePicker("开始", selection: $customStart, in: ...customEnd, displayedComponents: .date)
            DatePicker("结束", selection: $customEnd, in: customStart..., displayedComponents: .date)
            Button("完成") { period = .custom; showsCustomPicker = false }
                .buttonStyle(.borderedProminent)
        }
        .font(.system(size: 12))
        .padding(14)
        .frame(width: 250)
    }

    private var summaryCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeTitle).font(.system(size: 13, weight: .semibold))
            HStack(spacing: 8) {
                summaryCard(metric: .focus, title: "番茄钟", value: "\(focusDates.count)", detail: "\(focusDates.count * 25) 分钟", tint: .red)
                summaryCard(metric: .meditation, title: "冥想", value: "\(meditationDates.count)", detail: "\(meditationDates.count) 分钟", tint: .blue)
                summaryCard(metric: .mood, title: "情绪", value: "\(moodEntries.count)", detail: moodSummary, tint: .orange)
            }
        }
    }

    private func summaryCard(metric cardMetric: StatisticsMetric, title: String, value: String, detail: String, tint: Color) -> some View {
        Button { metric = metric == cardMetric ? .all : cardMetric } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(tint)
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(tint.opacity(metric == cardMetric ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(metric == cardMetric ? tint.opacity(0.55) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("趋势").font(.system(size: 13, weight: .semibold))
            if selectedDailyCounts.allSatisfy({ $0.count == 0 }) {
                Text("这段时间还没有完成记录。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            } else {
                SimpleTrendChart(values: selectedDailyCounts, tint: trendTint)
                    .frame(height: 126)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日明细").font(.system(size: 13, weight: .semibold))
            ForEach(selectedDailyCounts) { day in
                Button { selectedDay = day } label: {
                    HStack {
                        Text(dateLabel(day.date)).font(.system(size: 12))
                        Spacer()
                        Text(detailText(for: day)).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            if metric == .mood || metric == .all, !moodEntries.isEmpty {
                Divider().padding(.vertical, 3)
                Text("情绪记录").font(.system(size: 12, weight: .semibold))
                ForEach(moodEntries.prefix(12)) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.emoji) \(entry.name) · \(dateTimeLabel(entry.createdAt))").font(.system(size: 12))
                        if let note = entry.note { Text(note).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2) }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var range: DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        switch period {
        case .today: return DateInterval(start: today, end: calendar.date(byAdding: .day, value: 1, to: today) ?? .now)
        case .week: return DateInterval(start: calendar.date(byAdding: .day, value: -6, to: today) ?? today, end: calendar.date(byAdding: .day, value: 1, to: today) ?? .now)
        case .month: return DateInterval(start: calendar.date(byAdding: .day, value: -29, to: today) ?? today, end: calendar.date(byAdding: .day, value: 1, to: today) ?? .now)
        case .custom:
            let start = calendar.startOfDay(for: customStart)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd
            return DateInterval(start: start, end: end)
        }
    }

    private var focusDates: [Date] { pomodoro.focusCompletionDates.filter(range.contains) }
    private var meditationDates: [Date] { wellbeing.meditationCompletionDates.filter(range.contains) }
    private var moodEntries: [MoodEntry] { wellbeing.moodEntries.filter { range.contains($0.createdAt) } }
    private var moodSummary: String {
        guard let mostCommon = Dictionary(grouping: moodEntries, by: \.name).max(by: { $0.value.count < $1.value.count })?.key else { return "暂无记录" }
        return "最多：\(mostCommon)"
    }
    private var rangeTitle: String { period == .today ? "今天" : "\(dateLabel(range.start)) – \(dateLabel(Calendar.current.date(byAdding: .second, value: -1, to: range.end) ?? range.end))" }
    private var selectedDailyCounts: [DailyCount] {
        let dates: [Date]
        switch metric {
        case .focus: dates = focusDates
        case .meditation: dates = meditationDates
        case .mood: dates = moodEntries.map(\.createdAt)
        case .all: dates = focusDates + meditationDates + moodEntries.map(\.createdAt)
        }
        return daysInRange.map { day in DailyCount(date: day, count: dates.filter { Calendar.current.isDate($0, inSameDayAs: day) }.count) }.reversed()
    }
    private var daysInRange: [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        var day = calendar.startOfDay(for: range.start)
        while day < range.end && days.count < 366 {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? range.end
        }
        return days
    }
    private var trendTint: Color { metric == .focus ? .red : metric == .meditation ? .blue : metric == .mood ? .orange : .purple }
    private func detailText(for day: DailyCount) -> String {
        if metric == .focus { return "\(day.count) 轮" }
        if metric == .meditation { return "\(day.count) 次" }
        if metric == .mood { return "\(day.count) 条" }
        let calendar = Calendar.current
        let focus = focusDates.filter { calendar.isDate($0, inSameDayAs: day.date) }.count
        let meditation = meditationDates.filter { calendar.isDate($0, inSameDayAs: day.date) }.count
        let mood = moodEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: day.date) }.count
        return "番茄 \(focus) · 冥想 \(meditation) · 情绪 \(mood)"
    }
    private func dateLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }
    private func dateTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "M 月 d 日 HH:mm"
        return formatter.string(from: date)
    }
}

private struct DailyDetailSheet: View {
    let day: Date
    let focusDates: [Date]
    let meditationDates: [Date]
    let moodEntries: [MoodEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            detailRow(icon: "timer", title: "番茄钟", value: "完成 \(events(focusDates).count) 轮")
            detailRow(icon: "wind", title: "冥想", value: "完成 \(events(meditationDates).count) 次")
            if !entries.isEmpty {
                Divider()
                Text("情绪记录").font(.system(size: 13, weight: .semibold))
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.emoji) \(entry.name) · \(time(entry.createdAt))").font(.system(size: 12))
                        if let note = entry.note { Text(note).font(.system(size: 12)).foregroundStyle(.secondary) }
                    }
                }
            }
            Spacer()
        }
        .padding(18).frame(width: 330, height: 300, alignment: .topLeading)
    }

    private var entries: [MoodEntry] { moodEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) } }
    private func events(_ dates: [Date]) -> [Date] { dates.filter { Calendar.current.isDate($0, inSameDayAs: day) } }
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20); Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
            .font(.system(size: 13)).padding(10).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
    private var title: String {
        if Calendar.current.isDateInToday(day) { return "今天" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: day)
    }
    private func time(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; return formatter.string(from: date) }
}

private struct SimpleTrendChart: View {
    let values: [DailyCount]
    let tint: Color
    private var maxCount: CGFloat { CGFloat(max(values.map(\.count).max() ?? 1, 1)) }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: max(3, geometry.size.width / CGFloat(max(values.count, 1)) * 0.18)) {
                ForEach(values) { value in
                    VStack(spacing: 3) {
                        Text(value.count == 0 ? "" : "\(value.count)").font(.system(size: 9)).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tint.opacity(value.count == 0 ? 0.18 : 0.80))
                            .frame(height: max(4, (geometry.size.height - 28) * CGFloat(value.count) / maxCount))
                        Text(shortDate(value.date)).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
