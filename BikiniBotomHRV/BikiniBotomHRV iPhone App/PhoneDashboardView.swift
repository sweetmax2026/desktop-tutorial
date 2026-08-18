import Charts
import SwiftUI

struct PhoneDashboardView: View {
    @ObservedObject var store: PhoneHRVStore

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        recoveryCard
                        metricsCard
                        whyCard
                    }
                    .padding()
                }
                .navigationTitle("今日恢复")
                .toolbar {
                    Button {
                        store.loadReadings()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新健康数据")
                }
            }
            .tabItem { Label("首页", systemImage: "heart.fill") }

            NavigationStack {
                ScrollView {
                    trendCard
                        .padding()
                }
                .navigationTitle("HRV 趋势")
            }
            .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                explanationView
                    .navigationTitle("提醒说明")
            }
            .tabItem { Label("说明", systemImage: "bell.badge") }

            NavigationStack {
                settingsView
                    .navigationTitle("设置")
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Color(red: 0.05, green: 0.45, blue: 0.75))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.recoveryLabel, systemImage: "water.waves")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            Text(store.latest.map { "\(Int($0.sdnn))" } ?? "—")
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("HRV · SDNN（毫秒）")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
            Text(store.recoveryDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(colors: [Color(red: 0.03, green: 0.22, blue: 0.52), Color(red: 0.02, green: 0.53, blue: 0.63)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var metricsCard: some View {
        HStack(spacing: 0) {
            metric(title: "28 天基线", value: store.baseline28d.map { "\(Int($0)) ms" } ?? "建立中")
            Divider().padding(.vertical, 6)
            metric(title: "样本数量", value: "\(store.readings.count) 条")
            Divider().padding(.vertical, 6)
            metric(title: "提醒阈值", value: "低于 75%")
        }
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 7) {
            Text(value).font(.headline).multilineTextAlignment(.center)
            Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("为什么会提醒我？", systemImage: "bell.and.waves.left.and.right")
                .font(.headline)
            Text("手表只会在有新的 HRV 样本、低于个人基线阈值、且不处于静默或冷却期时提醒你。它不是医疗诊断。")
                .foregroundStyle(.secondary)
            NavigationLink("查看完整说明") {
                explanationView.navigationTitle("提醒说明")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("近 7 天每日中位数").font(.headline)
            if store.dailyTrend.isEmpty {
                ContentUnavailableView("暂无趋势", systemImage: "chart.line.uptrend.xyaxis", description: Text("允许读取健康数据后，趋势会显示在这里。"))
                    .frame(height: 260)
            } else {
                Chart(store.dailyTrend) { point in
                    LineMark(x: .value("日期", point.date), y: .value("HRV", point.sdnn))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue)
                    PointMark(x: .value("日期", point.date), y: .value("HRV", point.sdnn))
                        .foregroundStyle(.blue)
                }
                .chartYAxisLabel("SDNN（毫秒）")
                .frame(height: 280)
            }
            Text(store.accessMessage).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var explanationView: some View {
        List {
            Section("当前规则") {
                Label("个人基线", systemImage: "calendar")
                Text("读取近 28 天数据，至少 7 条样本后以中位数建立基线。")
                Label("提醒条件", systemImage: "arrow.down.heart")
                Text("最新 HRV 低于个人基线的 75% 时，才会考虑提醒。")
                Label("防打扰", systemImage: "moon.zzz")
                Text("每次提醒后冷却 1 小时；23:00–09:00 不发提醒。")
            }
            Section("边界") {
                Text("HRV 受睡眠、运动、饮酒和压力等多种因素影响。本 App 用于自我观察，不作医疗判断。")
            }
        }
    }

    private var settingsView: some View {
        List {
            Section("数据") {
                LabeledContent("健康数据状态", value: store.accessMessage)
                Button("重新读取近 28 天数据") {
                    store.loadReadings()
                }
            }
            Section("提醒设置") {
                Text("提醒开关、阈值、冷却和静默时段目前仍以手表端设置为准。下一步会将手机设置同步给手表。")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PhoneDashboardView(store: PhoneHRVStore())
}
