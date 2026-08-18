// ContentView.swift
// Bikini Bottom HRV Monitor
// 主界面 — 比奇堡主题

import Charts
import SwiftUI

struct ContentView: View {
    @StateObject private var hrvManager: HRVManager
    @State private var refreshFeedback: String?

    init(hrvManager: HRVManager = .shared) {
        _hrvManager = StateObject(wrappedValue: hrvManager)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                hrvManager.currentStatus.backgroundGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            // 首屏聚焦角色、状态文案与 HRV 数值。
                            VStack(spacing: 3) {
                                characterHeroSection
                                statusTextSection
                                hrvValueSection
                            }
                            .frame(minHeight: max(180, proxy.size.height - 4))
                            .offset(y: -5)

                            // 以下内容通过下滑查看。
                            trendSection
                            healthDetailsSection
                            refreshButton

                            NavigationLink {
                                SettingsView(hrvManager: hrvManager)
                            } label: {
                                Label("提醒设置", systemImage: "bell")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            #if DEBUG
                            if !hrvManager.isDemoMode {
                                testNotificationButton
                            }
                            #endif
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    }
                }
            }
        }
        .onAppear {
            hrvManager.requestAuthorization()
        }
    }

    // MARK: - 首屏角色
    @ViewBuilder
    var characterHeroSection: some View {
        if let assetName = hrvManager.currentStatus.characterAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .scaleEffect(1.47)
                .frame(width: 100, height: 100)
                .clipped()
        } else {
            Text(hrvManager.currentStatus.emoji)
                .font(.system(size: 92))
        }
    }

    // MARK: - 首屏状态文案
    var statusTextSection: some View {
        VStack(spacing: 3) {
            Text(hrvManager.currentStatus.label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(hrvManager.currentStatus.themeColor)

            Text(hrvManager.currentStatus.themeQuote)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - HRV 数值区域
    @ViewBuilder
    var hrvValueSection: some View {
        VStack(spacing: 2) {
            if hrvManager.isLoading {
                ProgressView()
                    .tint(.white)
                Text("读取 HRV 数据中…")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))

            } else if let errorMsg = hrvManager.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text(errorMsg)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

            } else if let hrv = hrvManager.latestHRV {
                // 数值仍清晰，但为趋势图留出足够空间。
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(Int(hrv))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(hrvManager.currentStatus.themeColor)

                    Text("ms")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }

                if hrvManager.isDemoMode {
                    Text("演示数据 · 非真实健康记录")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }

            } else {
                // 有权限但没数据
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.5))
                Text("暂无 HRV 数据")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Text("Apple Watch 会在后台自动采集")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    // MARK: - 趋势图
    @ViewBuilder
    var trendSection: some View {
        let points = hrvManager.dailyTrend
        if points.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("近 7 天趋势")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))

                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("HRV", point.sdnn)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(hrvManager.currentStatus.themeColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("日期", point.date),
                            y: .value("HRV", point.sdnn)
                        )
                        .foregroundStyle(.white)
                    }

                    if let baseline = hrvManager.baseline28d {
                        RuleMark(y: .value("28 天基线", baseline))
                            .foregroundStyle(.white.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 120)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
        }
    }

    // MARK: - 下滑健康详情
    var healthDetailsSection: some View {
        VStack(spacing: 6) {
            detailRow("28 天基线", value: baselineDetailText)
            detailRow("样本数", value: "\(hrvManager.hrvReadings.count) 条")

            if let timestamp = hrvManager.latestTimestamp {
                detailRow("最近记录", value: timestamp.formatted(date: .omitted, time: .shortened))
            }

            Text(hrvManager.reminderEvaluationText)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }

    private var baselineDetailText: String {
        guard let baseline = hrvManager.baseline28d else {
            return hrvManager.baselineProgressText
        }
        return "\(Int(baseline.rounded())) ms"
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .foregroundColor(.white.opacity(0.8))
        }
        .font(.system(size: 9))
    }

    // MARK: - 刷新按钮
    var refreshButton: some View {
        Button(action: {
            if hrvManager.isDemoMode {
                hrvManager.advanceDemoScenario()
                refreshFeedback = "演示已切换"
            } else {
                refreshFeedback = "刷新中…"
                hrvManager.refresh {
                    if hrvManager.errorMessage == nil {
                        let time = Date().formatted(date: .omitted, time: .shortened)
                        refreshFeedback = "已刷新 · \(time)"
                    } else {
                        refreshFeedback = "刷新失败"
                    }
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: refreshIconName)
                    .font(.system(size: 10))
                Text(refreshButtonTitle)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(hrvManager.isLoading)
    }

    private var refreshButtonTitle: String {
        if hrvManager.isLoading { return "刷新中…" }
        return refreshFeedback ?? (hrvManager.isDemoMode ? "切换演示" : "刷新")
    }

    private var refreshIconName: String {
        if hrvManager.isLoading { return "arrow.clockwise" }
        if refreshFeedback?.hasPrefix("已刷新") == true { return "checkmark.circle.fill" }
        if refreshFeedback == "刷新失败" { return "exclamationmark.circle.fill" }
        return hrvManager.isDemoMode ? "sparkles" : "arrow.clockwise"
    }

    #if DEBUG
    private var testNotificationButton: some View {
        Button(action: hrvManager.sendTestNotification) {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 10))
                Text("测试提醒")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    #endif
}

// MARK: - Preview
#Preview {
    ContentView()
}
