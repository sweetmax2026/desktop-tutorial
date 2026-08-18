import SwiftUI

/// 真机试用时用于区分：权限、数据不足、后台投递或提醒规则等不同问题。
struct DiagnosticsView: View {
    @ObservedObject var hrvManager: HRVManager
    @State private var refreshFeedback: String?

    var body: some View {
        List {
            Section("HealthKit") {
                statusRow("读取请求", hrvManager.healthAccessStatus)
                statusRow("最近成功查询", lastRefreshText)
                statusRow("近 28 天样本", "\(hrvManager.hrvReadings.count) 条")
                statusRow("个人基线", hrvManager.baselineProgressText)
            }

            Section("后台与通知") {
                statusRow("监听", hrvManager.isMonitoring ? "运行中" : "未启动")
                statusRow("后台投递", hrvManager.backgroundDeliveryStatus)
                statusRow("通知权限", hrvManager.notificationStatus)
            }

            Section("当前提醒规则") {
                statusRow("低 HRV 提醒", hrvManager.remindersEnabled ? "开启" : "关闭")
                statusRow("阈值", "低于基线 \(hrvManager.reminderThresholdPercent)%")
                statusRow("防打扰", hrvManager.reminderProtectionText)
                Text(hrvManager.reminderEvaluationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("重新检查") {
                    refreshFeedback = "正在重新查询…"
                    hrvManager.refreshDiagnostics {
                        refreshFeedback = hrvManager.errorMessage == nil ? "检查完成" : "检查失败，请查看主界面提示"
                    }
                }
                .disabled(hrvManager.isLoading)

                if let refreshFeedback {
                    Text(refreshFeedback)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("运行诊断")
        .onAppear {
            hrvManager.refreshDiagnostics {
                refreshFeedback = hrvManager.errorMessage == nil ? "检查完成" : "检查失败，请查看主界面提示"
            }
        }
    }

    private var lastRefreshText: String {
        guard let date = hrvManager.lastSuccessfulRefresh else { return "尚无" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView(hrvManager: .shared)
    }
}
