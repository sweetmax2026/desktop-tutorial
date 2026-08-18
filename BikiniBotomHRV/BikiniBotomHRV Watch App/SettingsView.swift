import SwiftUI

/// 只保存用户主动选择的提醒规则；HRV 数据仍然只来自 HealthKit。
struct SettingsView: View {
    @ObservedObject var hrvManager: HRVManager

    @AppStorage(HRVManager.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(HRVManager.lowHRVThresholdKey) private var lowHRVThreshold = 0.75
    @State private var isMutedToday = false
    @State private var saveFeedback = "设置会自动保存"

    var body: some View {
        List {
            Section("低 HRV 提醒") {
                Toggle("开启提醒", isOn: $remindersEnabled)
                    .onChange(of: remindersEnabled) { _, enabled in
                        hrvManager.setRemindersEnabled(enabled)
                        markSaved()
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("低于基线 \(thresholdPercent)% 时提醒")
                    Slider(value: $lowHRVThreshold, in: 0.60...0.90, step: 0.05)
                        .tint(.yellow)
                }
                .onChange(of: lowHRVThreshold) { _, value in
                    hrvManager.setLowHRVThresholdRatio(value)
                    markSaved()
                }

                Text("每次提醒后冷却 1 小时；23:00–09:00 不发送提醒。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label(
                    saveFeedback,
                    systemImage: saveFeedback == "已保存" ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(saveFeedback == "已保存" ? Color.green : Color.gray)
            }

            Section("今天") {
                Button {
                    hrvManager.muteRemindersForToday()
                    isMutedToday = true
                    markSaved()
                } label: {
                    Label(
                        isMutedToday ? "今天已静音" : "今天不再提醒",
                        systemImage: isMutedToday ? "bell.slash.fill" : "bell.slash"
                    )
                }
                .disabled(isMutedToday)

                Text(isMutedToday ? "明天会自动恢复提醒。" : "只暂停今天其后的低 HRV 提醒。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("海底伙伴") {
                HStack(spacing: 10) {
                    themeCharacter(name: "CharacterGood", label: "活力")
                    themeCharacter(name: "CharacterModerate", label: "慢一点")
                    themeCharacter(name: "CharacterStressed", label: "休息")
                }
            }

            Section {
                Text("HealthKit 写入新的 HRV 样本后才会判断提醒；它不是实时医疗监护。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    DiagnosticsView(hrvManager: hrvManager)
                } label: {
                    Label("运行诊断", systemImage: "stethoscope")
                }
            }

            #if DEBUG
            Section("测试") {
                Button("3 秒后发送测试提醒") {
                    hrvManager.sendTestNotification()
                }

                if let status = hrvManager.testNotificationStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            #endif
        }
        .navigationTitle("提醒设置")
        .onAppear {
            isMutedToday = hrvManager.isReminderMutedToday
        }
    }

    private var thresholdPercent: Int {
        Int((lowHRVThreshold * 100).rounded())
    }

    private func markSaved() {
        saveFeedback = "已保存"
    }

    private func themeCharacter(name: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        SettingsView(hrvManager: .shared)
    }
}
