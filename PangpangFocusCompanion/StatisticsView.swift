import SwiftUI
import Charts

enum StatisticsPeriod: String, CaseIterable, Identifiable {
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
    var initialPeriod: StatisticsPeriod = .today
    @State private var period: StatisticsPeriod = .today
    @State private var metric: StatisticsMetric = .focus
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
    @State private var customEnd = Date()
    @State private var showsDates = false
    @State private var expandedRecord: UUID?
    @State private var hoveredRecord: UUID?

    private let paper = Color(red: 0.995, green: 0.991, blue: 0.978)
    private let blue = Color(red: 0.23, green: 0.46, blue: 0.99)

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(240, max(194, geometry.size.width * 0.243))
            HStack(spacing: 0) {
                sidebar.frame(width: sidebarWidth)
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            summary.padding(.top, 22)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(chartTitle).font(.system(size: 17, weight: .semibold))
                                Text(metric == .focus ? "分钟" : "次数")
                                    .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                                distributionChart.frame(height: max(125, min(215, geometry.size.height * 0.21)))
                                Text(chartCaption).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.padding(.top, 20)
                            recordsSection.padding(.top, 22).padding(.bottom, 24)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.id("\(metric)-\(period.rawValue)-\(customStart.timeIntervalSince1970)-\(customEnd.timeIntervalSince1970)")
                        .accessibilityIdentifier("statistics.content")
                }.padding(.horizontal, 28).padding(.top, 43)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay(alignment: .top) {
                Text(AppBrand.wordmark).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FocusTheme.secondary).padding(.top, 8)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }.background(paper).foregroundStyle(FocusTheme.ink).ignoresSafeArea()
            .environment(\.colorScheme, .light)
            .onAppear { metric = initialMetric; period = initialPeriod }
            .onChange(of: period) { _ in expandedRecord = nil }
    }

    private var sidebar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if let url = Bundle.main.url(forResource: "statistics-window-sidebar-v1", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onBack) { Label(returnTitle, systemImage: "chevron.left") }
                        .buttonStyle(.plain).font(.system(size: 14, weight: .medium))
                        .frame(height: 32, alignment: .leading).padding(.horizontal, 10)
                        .accessibilityIdentifier("statistics.back")
                    Text("数据统计").font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 10).padding(.top, 20).padding(.bottom, 12)
                    sidebarItem(.focus, title: "专注", detail: "\(focusMinutes) 分钟", footnote: "\(completedRounds) 轮完成", icon: "chart", fallback: "pawprint.fill", color: blue)
                    sidebarItem(.meditation, title: "冥想", detail: "\(meditationDates.count) 次", icon: "leaf", fallback: "leaf", color: Color(red: 0.31, green: 0.50, blue: 0.38))
                    sidebarItem(.mood, title: "情绪", detail: "\(moods.count) 次", icon: "heart", fallback: "heart", color: Color(red: 0.97, green: 0.40, blue: 0.35))
                    Spacer(minLength: 0)
                }.padding(.horizontal, 12).padding(.top, 36)
            }
        }
    }

    private func sidebarItem(_ value: StatisticsMetric, title: String, detail: String, footnote: String? = nil,
                             icon: String, fallback: String, color: Color) -> some View {
        Button { metric = value; expandedRecord = nil } label: {
            HStack(alignment: .top, spacing: 13) {
                Group {
                    if value == .focus {
                        Image(systemName: "pawprint.fill").resizable().scaledToFit().foregroundStyle(color)
                    } else if let url = Bundle.main.url(forResource: "focus-icon-\(icon)-v1", withExtension: "png"),
                              let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFit()
                    } else {
                        Image(systemName: fallback).resizable().scaledToFit().foregroundStyle(color)
                    }
                }.frame(width: 25, height: 25).padding(.top, 2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(detail).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                    if let footnote { Text(footnote).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary) }
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(StatisticsNavigationStyle(selected: metric == value, tint: blue))
            .padding(.bottom, 6)
            .accessibilityLabel("\(title)，\(detail)\(footnote.map { "，\($0)" } ?? "")")
            .accessibilityAddTraits(metric == value ? [.isSelected] : [])
            .accessibilityIdentifier(value == .focus ? "statistics.focus" : value == .meditation ? "statistics.meditation" : "statistics.mood")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(metric == .focus ? "专注回顾" : metric == .meditation ? "冥想回顾" : "情绪回顾")
                .font(.system(size: 21, weight: .bold)).fixedSize()
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                ForEach(StatisticsPeriod.allCases) { value in
                    Button { period = value; showsDates = value == .custom } label: {
                        Text(value.rawValue).font(.system(size: 12, weight: period == value ? .medium : .regular))
                            .frame(maxWidth: .infinity).frame(height: 26)
                            .foregroundStyle(period == value ? blue : FocusTheme.ink)
                            .background(period == value ? blue.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(period == value ? [.isSelected] : [])
                        .accessibilityIdentifier("statistics.period.\(value.id)")
                }
            }.padding(2).frame(width: 260).background(FocusTheme.secondary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityElement(children: .contain).accessibilityLabel("时间范围")
            Button { showsDates.toggle() } label: { Image(systemName: "calendar").font(.system(size: 17)).frame(width: 28, height: 30) }
                .buttonStyle(.plain).accessibilityLabel("选择日期范围")
                .accessibilityIdentifier("statistics.calendar")
                .popover(isPresented: $showsDates, arrowEdge: .bottom) { dateEditor }
        }.frame(height: 31)
    }

    private var focusMinutes: String { focusSeconds > 0 && focusSeconds < 60 ? "<1" : "\(Int(focusSeconds / 60))" }
    private var completedRounds: Int { focusRecords.filter(\.completed).count }
    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeTitle).font(.system(size: 14, weight: .medium)).padding(.bottom, 8)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(metric == .focus ? focusMinutes : "\(metric == .meditation ? meditationDates.count : moods.count)")
                    .font(.custom("DINCondensed-Bold", size: 88)).tracking(-1)
                    .foregroundStyle(Color(red: 0.09, green: 0.11, blue: 0.14))
                    .offset(y: 14)
                    .accessibilityIdentifier("statistics.total")
                Text(metric == .focus ? "分钟" : "次").font(.system(size: 16, weight: .medium)).offset(y: 10)
            }.frame(height: 83, alignment: .bottomLeading)
            Text(metric == .focus ? "\(completedRounds) 轮完成" : metric == .meditation ? "给自己的每一分钟，都有记录。" : "记下每一种感受，慢慢了解自己。")
                .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary).padding(.top, 2)
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recordsTitle).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(recordsCount).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
            }
            if metric == .focus && !focusRecords.isEmpty {
                HStack(spacing: 12) {
                    Text("日期").frame(width: 70, alignment: .leading)
                    Text("时间").frame(width: 104, alignment: .leading)
                    Text("内容").frame(maxWidth: .infinity, alignment: .leading)
                    Text("时长").frame(width: 64, alignment: .leading)
                    Color.clear.frame(width: 10, height: 1)
                }.font(.system(size: 11)).foregroundStyle(FocusTheme.secondary).padding(.horizontal, 3)
            }
            LazyVStack(alignment: .leading, spacing: 0) { recordRows }
        }
    }

    private var distributionChart: some View {
        Chart(samples) { sample in
            BarMark(x: .value("时间", sample.date, unit: chartUnit), y: .value(metric == .focus ? "分钟" : "次数", sample.value), width: .ratio(0.55))
                .foregroundStyle(chartColor.opacity(Calendar.current.isDateInToday(sample.date) ? 1 : 0.48)).cornerRadius(3)
                .annotation(position: .top) {
                    if sample.value > 0 && samples.count <= 31 {
                        Text(sample.value.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 10)).foregroundStyle(FocusTheme.secondary)
                    }
                }
        }
        .chartYScale(domain: 0...chartMaximum)
        .chartXAxis {
            AxisMarks(values: period == .week ? samples.map(\.date) + [range.end] : axisDates) { value in
                AxisValueLabel(centered: period == .week) {
                    if let date = value.as(Date.self), date < range.end { Text(axisLabel(date)).font(.system(size: 10)) }
                }
            }
        }
        .chartYAxis {
            if metric == .focus {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) {
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
                        Text(dateLabel(record.endedAt)).frame(width: 70, alignment: .leading)
                        Text("\(time(record.startedAt))–\(time(record.endedAt))")
                            .monospacedDigit().frame(width: 104, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.task.isEmpty ? record.category : record.task).lineLimit(1)
                            if !record.completed {
                                Text("提前结束").font(.system(size: 10)).foregroundStyle(FocusTheme.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(duration(record.seconds)).font(.system(size: 12)).frame(width: 64, alignment: .leading)
                        Image(systemName: expandedRecord == record.id ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10)).foregroundStyle(FocusTheme.secondary).frame(width: 10)
                    }.font(.system(size: 12)).padding(.vertical, 8).padding(.horizontal, 3).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .background(hoveredRecord == record.id || expandedRecord == record.id ? FocusTheme.accent.opacity(0.05) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
                    .onHover { hoveredRecord = $0 ? record.id : nil }
                    .accessibilityLabel("\(dateLabel(record.endedAt))，\(time(record.startedAt)) 至 \(time(record.endedAt))，\(record.task.isEmpty ? record.category : record.task)，\(duration(record.seconds))\(record.completed ? "" : "，提前结束")，点击查看成果笔记")
                    .accessibilityIdentifier("statistics.record.\(record.id.uuidString)")
                if expandedRecord == record.id {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("开始：\(dateLabel(record.startedAt)) \(time(record.startedAt))　结束：\(dateLabel(record.endedAt)) \(time(record.endedAt))")
                        Text("类别：\(record.category)")
                        Text(record.note.isEmpty ? "还没有成果笔记。" : record.note)
                        if record.estimated { Text("旧记录的时长为估算值。") }
                    }.font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).padding(.bottom, 12)
                }
                Rectangle().fill(FocusTheme.secondary.opacity(0.13)).frame(height: 0.5).accessibilityHidden(true)
            }
        case .meditation:
            if meditationDates.isEmpty { emptyRecords }
            ForEach(Array(meditationDates.sorted(by: >).enumerated()), id: \.offset) { _, date in
                HStack {
                    Label("1 分钟冥想", systemImage: "leaf").font(.system(size: 13))
                    Spacer()
                    Text(recordTime(date)).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }.padding(.vertical, 13)
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
            Button("查看") { period = .custom; showsDates = false }.buttonStyle(.borderedProminent).tint(blue)
                .accessibilityIdentifier("statistics.applyDates")
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
        let step: Double = maximum <= 5 ? 1 : maximum <= 30 ? 5 : 25
        return max(1, metric == .focus ? ceil(maximum / step) * step : ceil(maximum))
    }
    private var chartColor: Color { metric == .focus ? blue : metric == .meditation ? Color(red: 0.43, green: 0.54, blue: 0.30) : Color(red: 0.92, green: 0.47, blue: 0.41) }
    private var axisDates: [Date] {
        let stride = max(1, samples.count / (period == .today ? 6 : 5))
        return samples.enumerated().compactMap { $0.offset.isMultiple(of: stride) ? $0.element.date : nil }
    }
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

private struct StatisticsNavigationStyle: ButtonStyle {
    let selected: Bool
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(tint.opacity(selected ? 0.13 : configuration.isPressed ? 0.08 : 0),
                                       in: RoundedRectangle(cornerRadius: 13))
    }
}
