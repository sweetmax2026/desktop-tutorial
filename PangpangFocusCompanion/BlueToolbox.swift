import SwiftUI

struct AppGuardPage: View {
    @ObservedObject var store: AppBlockerStore
    @ObservedObject var pomodoro: PomodoroStore
    let onBack: () -> Void
    var body: some View {
        FocusSettingsView(store: pomodoro, appBlocker: store, returnTitle: "返回专注", initialSection: .guardApps, onClose: onBack)
    }
}

enum SettingsSection { case timing, guardApps }

struct SettingsActionStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .medium)).frame(minWidth: primary ? 56 : 0)
            .padding(.horizontal, 16).frame(height: 34)
            .foregroundStyle(primary ? Color.white : FocusTheme.accent)
            .background(primary ? FocusTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(primary ? Color.clear : FocusTheme.accent.opacity(0.55)) }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct SettingsGuardContents: View {
    @ObservedObject var store: AppBlockerStore
    private var status: String {
        if !store.isEnabled { return "守护未开启" }
        if store.blockedApplications.isEmpty { return "已开启，等待添加 App" }
        return store.isBlockingNow ? "正在守护专注" : "已开启，等待专注"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("专注守护").font(.system(size: 16, weight: .semibold)).padding(.bottom, 22)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("开启 App 管控").font(.system(size: 15, weight: .medium))
                    Text("仅专注中生效，休息时自动放行。")
                        .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }
                Spacer()
                Toggle("开启 App 管控", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).tint(FocusTheme.accent)
                    .accessibilityIdentifier("guard.enabled")
            }
            Label(status, systemImage: "circle.fill")
                .font(.system(size: 12)).foregroundStyle(store.isEnabled ? FocusTheme.accent : FocusTheme.secondary)
                .padding(.top, 22)
            Divider().padding(.top, 28).padding(.bottom, 20)
            HStack {
                Text("管控 App").font(.system(size: 15, weight: .semibold))
                Text("\(store.blockedApplications.count) 个 App").font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                Spacer()
                Button { store.chooseApplications() } label: { Label("添加 App", systemImage: "plus") }
                    .buttonStyle(SettingsActionStyle()).accessibilityIdentifier("guard.add")
            }
            ScrollView {
                VStack(spacing: 0) {
                    if store.blockedApplications.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "app.badge.checkmark").font(.system(size: 26)).foregroundStyle(FocusTheme.accent)
                            Text("还没有添加 App").font(.system(size: 14, weight: .medium))
                            Text("添加容易分心的 App，专注时会暂时隐藏。").font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                        }.frame(maxWidth: .infinity).padding(.top, 36)
                    } else {
                        ForEach(store.blockedApplications) { application in
                            HStack(spacing: 14) {
                                Image(nsImage: store.icon(for: application)).resizable().scaledToFit()
                                    .frame(width: 40, height: 40).accessibilityHidden(true)
                                Text(application.name).font(.system(size: 14, weight: .medium))
                                    .lineLimit(1).help(application.bundleIdentifier)
                                Spacer()
                                Button { store.remove(application) } label: {
                                    Image(systemName: "minus").font(.system(size: 13, weight: .medium))
                                        .frame(width: 28, height: 28)
                                        .background(FocusTheme.secondary.opacity(0.08), in: Circle())
                                        .frame(width: 36, height: 36).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("移除 \(application.name)")
                                    .help("仅移出管控列表，不会删除 App")
                                    .accessibilityIdentifier("guard.remove.\(application.bundleIdentifier)")
                            }.frame(height: 64)
                        }
                    }
                }.frame(maxWidth: .infinity)
            }.padding(.top, 12)
            Label("只隐藏 App，不会退出或删除数据。", systemImage: "info.circle")
                .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).padding(.top, 16)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum FocusTheme {
    static let ink = Color(red: 0.15, green: 0.17, blue: 0.21)
    static let secondary = Color(red: 0.36, green: 0.40, blue: 0.48)
    static let accent = Color(red: 0.40, green: 0.53, blue: 0.97)
    static let shelf = Color(red: 0.91, green: 0.94, blue: 1)
    static var background: some View {
        LinearGradient(colors: [Color(red: 0.91, green: 0.96, blue: 1), .white,
            Color(red: 0.98, green: 0.96, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct FocusSettingsButton: View {
    let onOpen: () -> Void
    var body: some View {
        Button(action: onOpen) {
            Label("设置", systemImage: "gearshape")
                .font(.system(size: 15, weight: .medium)).frame(height: 36)
        }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary)
            .accessibilityIdentifier("focus.settings")
    }
}

struct FocusSettingsView: View {
    @ObservedObject var store: PomodoroStore
    var appBlocker: AppBlockerStore
    let onClose: () -> Void
    var returnTitle: String
    @State private var draft: FocusSettings
    @State private var miniCard: Bool
    @State private var floatingEntry: Bool
    @State private var section: SettingsSection

    init(store: PomodoroStore, appBlocker: AppBlockerStore, returnTitle: String = "返回专注",
         initialSection: SettingsSection = .timing, onClose: @escaping () -> Void) {
        self.store = store; self.appBlocker = appBlocker; self.onClose = onClose; self.returnTitle = returnTitle
        _draft = State(initialValue: store.settings)
        _miniCard = State(initialValue: store.showsMiniCard)
        _floatingEntry = State(initialValue: store.showsFloatingEntry)
        _section = State(initialValue: initialSection)
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onClose) { Label(returnTitle, systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FocusTheme.secondary).accessibilityIdentifier("settings.back")
                    .padding(.horizontal, 16).frame(height: 36).padding(.bottom, 22)
                navigation("计时与显示", icon: "clock", value: .timing, id: "settings.timing")
                navigation("专注守护", icon: "checkmark.shield", value: .guardApps, id: "settings.guard")
                    .padding(.top, 6)
                Spacer()
                HStack(spacing: 10) {
                    FocusCat(size: 30).accessibilityHidden(true)
                    Text(AppBrand.wordmark).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }.padding(.horizontal, 16)
            }.padding(.horizontal, 16).padding(.top, 44).padding(.bottom, 24)
                .frame(width: 216).frame(maxHeight: .infinity)
                .background(FocusTheme.accent.opacity(0.025))
            VStack(alignment: .leading, spacing: 0) {
                Text("设置").font(.system(size: 20, weight: .semibold)).padding(.bottom, 26)
                if section == .timing { timingContents }
                else { SettingsGuardContents(store: appBlocker) }
            }.padding(.horizontal, 36).padding(.top, 48).padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).foregroundStyle(FocusTheme.ink).ignoresSafeArea()
            .onChange(of: store.showsMiniCard) { miniCard = $0 }
            .onChange(of: store.showsFloatingEntry) { floatingEntry = $0 }
    }
    private func navigation(_ title: String, icon: String, value: SettingsSection, id: String) -> some View {
        Button { section = value } label: {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(height: 42)
                .foregroundStyle(section == value ? FocusTheme.accent : FocusTheme.secondary)
                .background(section == value ? FocusTheme.accent.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
            .accessibilityAddTraits(section == value ? .isSelected : [])
    }
    private var timingContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("计时设置").font(.system(size: 16, weight: .semibold)).padding(.bottom, 10)
            durationRow("专注时长", detail: "设置一次专注的时长。", value: $draft.focusMinutes, range: 1...180, unit: "分钟")
            durationRow("短休息", detail: "设置短休息的时长。", value: $draft.shortBreakMinutes, range: 1...60, unit: "分钟")
            durationRow("长休息", detail: "设置长休息的时长。", value: $draft.longBreakMinutes, range: 1...120, unit: "分钟")
            durationRow("长休息间隔", detail: "设置多少轮后进行一次长休息。", value: $draft.longBreakInterval, range: 1...12, unit: "轮", prefix: "每")
            Divider().padding(.top, 12).padding(.bottom, 18)
            Text("显示设置").font(.system(size: 16, weight: .semibold)).padding(.bottom, 2)
            visibilityRow("圆形悬浮入口", detail: "桌面猫头像入口。", value: $floatingEntry, id: "settings.floatingEntry")
            visibilityRow("悬浮计时卡", detail: "专注与休息时显示剩余时间。", value: $miniCard, id: "settings.miniCard")
            Spacer(minLength: 14)
            HStack(spacing: 12) {
                Text("新设置用于下一阶段，当前计时不变。").font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("恢复默认") { draft = FocusSettings(); miniCard = true; floatingEntry = false }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(FocusTheme.accent).fixedSize()
                Button("保存") {
                    store.updateSettings(draft)
                    store.showsMiniCard = miniCard
                    store.showsFloatingEntry = floatingEntry
                    onClose()
                }.buttonStyle(SettingsActionStyle(primary: true)).accessibilityIdentifier("settings.save")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func description(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 15, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
        }
    }
    private func visibilityRow(_ title: String, detail: String, value: Binding<Bool>, id: String) -> some View {
        HStack {
            description(title, detail: detail)
            Spacer()
            Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).tint(FocusTheme.accent)
                .accessibilityLabel(title).accessibilityIdentifier(id)
        }.frame(height: 56)
    }
    private func durationRow(_ title: String, detail: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, prefix: String = "") -> some View {
        HStack(spacing: 8) {
            description(title, detail: detail)
            Spacer(minLength: 10)
            Text(prefix).font(.system(size: 12)).frame(width: 14)
            HStack(spacing: 4) {
                TextField(title, value: value, format: .number.grouping(.never))
                    .textFieldStyle(.plain).multilineTextAlignment(.center).frame(width: 42)
                    .font(.system(size: 14)).accessibilityLabel(title)
                Stepper(title, value: value, in: range).labelsHidden().frame(width: 18)
            }.padding(.horizontal, 7).frame(width: 94, height: 32)
                .background(FocusTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Text(unit).font(.system(size: 13)).frame(width: 42, alignment: .trailing)
        }.frame(height: 56)
    }
}

// Both the home entry and former immersive entry now host the same lifecycle.
struct BlueToolboxHome: View {
    @ObservedObject var store: PomodoroStore
    @ObservedObject var wellbeing: WellbeingStore
    @ObservedObject var appBlocker: AppBlockerStore
    let onTool: (ToolboxTool) -> Void
    let onHistory: () -> Void
    var body: some View {
        FocusFlowScreen(store: store, appBlocker: appBlocker, onTool: onTool, onHistory: onHistory)
    }
}
