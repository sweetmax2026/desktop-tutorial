import SwiftUI
import Charts

private enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case today = "今天", week = "近 7 天", month = "近 30 天", custom = "自定义"
    var id: Self { self }
}
enum StatisticsMetric { case focus, meditation, mood }

struct StatisticsView: View {
    @ObservedObject var pomodoro: PomodoroStore
    @ObservedObject var wellbeing: WellbeingStore
    let onBack: () -> Void
    let onClose: () -> Void
    var returnTitle = "返回专注"
    var initialMetric: StatisticsMetric = .focus
    @State private var period: StatisticsPeriod = .today
    @State private var metric: StatisticsMetric = .focus
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var customEnd = Date()
    @State private var showsDates = false
    @State private var expandedRecord: UUID?
    @State private var hoveredRecord: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) { Label(returnTitle, systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 15, weight: .medium))
                    .accessibilityIdentifier("statistics.back")
                Spacer()
                Picker("时间范围", selection: Binding(get: { period }, set: { value in
                    period = value
                    showsDates = value == .custom
                })) {
                    ForEach(StatisticsPeriod.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 250)
                Button { showsDates = true } label: { Image(systemName: "calendar").frame(width: 28, height: 30) }
                    .buttonStyle(.plain).accessibilityLabel("选择日期范围")
            }.frame(height: 36)
                .overlay { Text("数据统计").font(.system(size: 20, weight: .bold)).offset(x: -18).allowsHitTesting(false) }
            Text(rangeTitle).font(.system(size: 21, weight: .semibold)).padding(.top, 18)
            overview.padding(.top, 16).frame(height: 124).padding(.bottom, 32)
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(chartTitle).font(.system(size: 19, weight: .semibold))
                        Spacer()
                        Text(metric == .focus ? "分钟" : "次数").font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                    }
                    distributionChart.frame(height: 166)
                    Text(chartCaption).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                }.frame(width: 400)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(recordsTitle).font(.system(size: 19, weight: .semibold))
                        Spacer()
                        Text(recordsCount).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) { recordRows }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(maxWidth: .infinity)
            }.frame(maxHeight: .infinity)
            HStack(spacing: 12) {
                FocusCat(size: 58).accessibilityHidden(true)
                Text(metric == .mood ? "记下每一种感受，慢慢了解自己。" : metric == .meditation ? "给自己的每一分钟，都有记录。" : focusRecords.isEmpty ? "留一点时间，给重要的事。" : "每一段专注，都有记录。")
                    .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                Spacer()
            }.frame(height: 58)
        }.padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).foregroundStyle(FocusTheme.ink).ignoresSafeArea()
            .onAppear { metric = initialMetric }
            .overlay(alignment: .topTrailing) {
                if showsDates {
                    dateEditor.background { FocusTheme.background.clipShape(RoundedRectangle(cornerRadius: 18)) }
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .padding(.top, 80).padding(.trailing, 32)
                }
            }
    }

    private var overview: some View {
        HStack(spacing: 18) {
            Button { metric = .focus } label: {
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(period == .today ? "今日专注" : "专注时长").font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(focusSeconds > 0 && focusSeconds < 60 ? "<1" : "\(Int(focusSeconds / 60))")
                                .font(.system(size: 56, weight: .semibold, design: .rounded)).foregroundStyle(FocusTheme.accent)
                            Text("分钟").font(.system(size: 19, weight: .semibold))
                        }
                        Text("\(focusRecords.filter(\.completed).count) 轮完成").font(.system(size: 15, weight: .medium))
                    }
                    HStack(spacing: 2) {
                        ForEach(0..<min(2, focusRecords.filter(\.completed).count), id: \.self) { index in FocusPaw(size: 36).rotationEffect(.degrees(index % 2 == 0 ? -10 : 8)) }
                    }.accessibilityHidden(true)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("查看专注统计")
            metricLink(.meditation, title: period == .today ? "今日冥想" : "冥想", count: meditationDates.count,
                symbol: "leaf.fill", color: Color(red: 0.43, green: 0.54, blue: 0.30))
            metricLink(.mood, title: period == .today ? "今日情绪" : "情绪", count: moods.count,
                symbol: "heart.fill", color: Color(red: 0.92, green: 0.47, blue: 0.41))
        }
    }
    private func metricLink(_ value: StatisticsMetric, title: String, count: Int, symbol: String, color: Color) -> some View {
        Button { metric = value; expandedRecord = nil } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).font(.system(size: 25)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                    HStack(spacing: 5) {
                        Text("\(count)").font(.system(size: 25, weight: .semibold, design: .rounded))
                        Text("次").font(.system(size: 14))
                        Image(systemName: "chevron.right").font(.system(size: 11))
                    }
                    Text(value == .meditation ? "放松身心" : "记录此刻的心情").font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                }
            }.padding(8).background(metric == value ? color.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).frame(width: 158)
    }

    private var distributionChart: some View {
        Chart(samples) { sample in
            BarMark(x: .value("时间", sample.date, unit: chartUnit), y: .value(metric == .focus ? "分钟" : "次数", sample.value), width: .ratio(0.55))
                .foregroundStyle(chartColor).cornerRadius(3)
                .annotation(position: .top) {
                    if sample.value > 0 && samples.count <= 31 {
                        Text(sample.value.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 9)).foregroundStyle(FocusTheme.secondary)
                    }
                }
        }
        .chartYScale(domain: 0...chartMaximum)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: period == .today ? 6 : 5)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) { Text(axisLabel(date)).font(.system(size: 10)) }
                }
            }
        }
        .chartYAxis {
            if metric == .focus {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FocusTheme.secondary.opacity(0.14))
                    AxisValueLabel().foregroundStyle(FocusTheme.secondary)
                }
            } else {
                AxisMarks(position: .leading, values: Array(stride(from: 0.0, through: chartMaximum, by: max(1, ceil(chartMaximum / 2))))) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(FocusTheme.secondary.opacity(0.14))
                    AxisValueLabel().foregroundStyle(FocusTheme.secondary)
                }
            }
        }
        .overlay {
            if samples.allSatisfy({ $0.value == 0 }) {
                Text("这段时间还没有\(metric == .focus ? "专注" : metric == .meditation ? "冥想" : "情绪")记录。")
                    .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary)
                    .padding(14).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityLabel("\(chartTitle)，\(rangeTitle)")
    }

    @ViewBuilder private var recordRows: some View {
        switch metric {
        case .focus:
            if focusRecords.isEmpty { emptyRecords }
            ForEach(focusRecords.sorted { $0.endedAt > $1.endedAt }) { record in
                Button { expandedRecord = expandedRecord == record.id ? nil : record.id } label: {
                    HStack(spacing: 12) {
                        Image(systemName: record.completed ? "circle.fill" : "circle.dashed")
                            .font(.system(size: 10)).foregroundStyle(FocusTheme.accent)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.task.isEmpty ? record.category : record.task).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text("\(recordTime(record.startedAt)) → \(time(record.endedAt))\(record.completed ? "" : " · 提前结束")")
                                .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                        }
                        Spacer(minLength: 2)
                        Text(duration(record.seconds)).font(.system(size: 12)).fixedSize()
                        Image(systemName: expandedRecord == record.id ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10)).foregroundStyle(FocusTheme.secondary)
                    }.padding(.vertical, 14).padding(.horizontal, 8).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .background(hoveredRecord == record.id || expandedRecord == record.id ? FocusTheme.accent.opacity(0.05) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
                    .onHover { hoveredRecord = $0 ? record.id : nil }
                if expandedRecord == record.id {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("类别：\(record.category)")
                        Text(record.note.isEmpty ? "还没有成果笔记。" : record.note)
                        if record.estimated { Text("旧记录的时长为估算值。") }
                    }.font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).padding(.bottom, 12)
                }
            }
        case .meditation:
            if meditationDates.isEmpty { emptyRecords }
            ForEach(Array(meditationDates.sorted(by: >).enumerated()), id: \.offset) { _, date in
                HStack {
                    Label("1 分钟冥想", systemImage: "leaf.fill").font(.system(size: 14))
                    Spacer()
                    Text(recordTime(date)).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }.padding(.vertical, 16)
            }
        case .mood:
            if moods.isEmpty { emptyRecords }
            ForEach(moods.sorted { $0.createdAt > $1.createdAt }) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(entry.emoji) \(entry.name)").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(recordTime(entry.createdAt)).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                    }
                    if let note = entry.note, !note.isEmpty { Text(note).font(.system(size: 13)).foregroundStyle(FocusTheme.secondary) }
                }.padding(.vertical, 14)
            }
        }
    }
    private var emptyRecords: some View {
        Text("暂无记录，完成后会显示在这里。")
            .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary).padding(.vertical, 30)
    }

    private var dateEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("选择日期范围").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { showsDates = false } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel("关闭日期选择")
            }
            DatePicker("开始", selection: $customStart, in: ...customEnd, displayedComponents: .date)
            DatePicker("结束", selection: $customEnd, in: customStart..., displayedComponents: .date)
            Button("查看") { period = .custom; showsDates = false }.buttonStyle(.borderedProminent).tint(FocusTheme.accent)
        }.padding(22).frame(width: 290).environment(\.colorScheme, .light)
    }
    private var range: DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start: Date
        let end: Date
        switch period {
        case .today: start = today; end = calendar.date(byAdding: .day, value: 1, to: today)!
        case .week: start = calendar.date(byAdding: .day, value: -6, to: today)!; end = calendar.date(byAdding: .day, value: 1, to: today)!
        case .month: start = calendar.date(byAdding: .day, value: -29, to: today)!; end = calendar.date(byAdding: .day, value: 1, to: today)!
        case .custom: start = calendar.startOfDay(for: min(customStart, customEnd)); end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(customStart, customEnd)))!
        }
        return DateInterval(start: start, end: end)
    }
    private func contains(_ date: Date) -> Bool { date >= range.start && date < range.end }
    private var focusRecords: [FocusRecord] { pomodoro.records.filter { contains($0.endedAt) } }
    private var focusSeconds: Double { focusRecords.reduce(0) { $0 + max(0, $1.seconds) } }
    private var meditationDates: [Date] { wellbeing.meditationCompletionDates.filter(contains) }
    private var moods: [MoodEntry] { wellbeing.moodEntries.filter { contains($0.createdAt) } }
    private var samples: [StatisticsSample] {
        let values: [(Date, Double)]
        switch metric {
        case .focus: values = focusRecords.map { ($0.endedAt, max(0, $0.seconds) / 60) }
        case .meditation: values = meditationDates.map { ($0, 1) }
        case .mood: values = moods.map { ($0.createdAt, 1) }
        }
        return statisticsSamples(values: values, range: range, hourly: period == .today)
    }
    private var chartTitle: String { metric == .focus ? (period == .today ? "专注分布" : "专注趋势") : metric == .meditation ? "冥想趋势" : "情绪记录趋势" }
    private var chartUnit: Calendar.Component { period == .today ? .hour : range.duration > 62 * 86400 ? .month : .day }
    private var chartMaximum: Double {
        let maximum = (samples.map(\.value).max() ?? 0) * 1.2
        return max(1, metric == .focus ? maximum : ceil(maximum))
    }
    private var chartColor: Color { metric == .focus ? FocusTheme.accent : metric == .meditation ? Color(red: 0.43, green: 0.54, blue: 0.30) : Color(red: 0.92, green: 0.47, blue: 0.41) }
    private var chartCaption: String { metric == .focus ? "按结束时间归类，含提前结束的有效专注时长。" : "按记录时间统计，空白日期为 0。" }
    private var recordsTitle: String { metric == .focus ? "专注记录" : metric == .meditation ? "冥想记录" : "情绪记录" }
    private var recordsCount: String { "共 \(metric == .focus ? focusRecords.count : metric == .meditation ? meditationDates.count : moods.count) 条" }
    private var rangeTitle: String { period == .today ? "\(dateLabel(range.start))  今天" : "\(dateLabel(range.start)) 至 \(dateLabel(range.end.addingTimeInterval(-1)))" }
    private func dateLabel(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"; return f.string(from: date) }
    private func time(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date) }
    private func recordTime(_ date: Date) -> String { period == .today ? time(date) : "\(dateLabel(date)) \(time(date))" }
    private func axisLabel(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = period == .today ? "H" : range.duration > 62 * 86400 ? "yy/M" : "M/d"; return f.string(from: date) }
    private func duration(_ seconds: Double) -> String { seconds > 0 && seconds < 60 ? "不足 1 分钟" : "\(Int(seconds / 60)) 分钟" }
}
