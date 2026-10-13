import SwiftUI

struct AppGuardPage: View {
    @ObservedObject var store: AppBlockerStore
    let onBack: () -> Void
    private var stateText: String {
        if !store.isEnabled { return "守护未开启" }
        if store.blockedApplications.isEmpty { return "开关已开启，等待添加 App" }
        return store.isBlockingNow ? "正在守护专注" : "开关已开启，等待专注"
    }
    var body: some View {
        VStack(spacing: 0) {
            WellbeingPageHeader(title: "App 管控", onBack: onBack)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    FocusCat(size: 132).frame(maxWidth: .infinity).padding(.top, 4)
                        .accessibilityHidden(true)
                    Text("专注时，少一点打扰。")
                        .font(.system(size: 25, weight: .bold)).lineLimit(1).minimumScaleFactor(0.85)
                        .padding(.top, 12)
                    HStack {
                        Text("专注守护").font(.system(size: 21, weight: .semibold))
                        Spacer()
                        Toggle("专注守护", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                            .labelsHidden().toggleStyle(.switch).tint(FocusTheme.accent)
                            .accessibilityLabel("专注守护").accessibilityIdentifier("guard.enabled")
                    }.padding(.top, 45)
                    Text(stateText).font(.system(size: 15, weight: .medium))
                        .foregroundStyle(store.isEnabled ? FocusTheme.accent : FocusTheme.secondary)
                        .padding(.top, 10).fixedSize(horizontal: false, vertical: true)
                    Text("进入专注后，自动隐藏黑名单 App。")
                        .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                        .padding(.top, 20).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 20)
                    HStack(spacing: 14) {
                        Image(systemName: "leaf.fill").font(.system(size: 22)).foregroundStyle(FocusTheme.accent.opacity(0.65))
                        Text("休息和暂停自动放行。").font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                    }.padding(.bottom, 12)
                }.frame(width: 292)
                Divider().padding(.leading, 9).padding(.trailing, 28)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("黑名单").font(.system(size: 25, weight: .bold))
                            Text("已添加 \(store.blockedApplications.count) 个 App")
                                .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                        }
                        Spacer(minLength: 10)
                        Button { store.chooseApplications() } label: {
                            Label("添加 App", systemImage: "plus").frame(width: 122, height: 38)
                        }.buttonStyle(FocusPillStyle(fill: FocusTheme.accent, ink: .white))
                            .font(.system(size: 14, weight: .medium)).accessibilityIdentifier("guard.add")
                    }.padding(.top, 16)
                    ScrollView {
                        VStack(spacing: 0) {
                            if store.blockedApplications.isEmpty {
                                VStack(spacing: 14) {
                                    Image(systemName: "app.badge.checkmark").font(.system(size: 32))
                                        .foregroundStyle(FocusTheme.accent.opacity(0.7))
                                    Text("还没有添加 App").font(.system(size: 17, weight: .semibold))
                                    Text("把容易分心的 App 放在这里，\n专注时替你暂时挡一下。")
                                        .font(.system(size: 13)).multilineTextAlignment(.center).foregroundStyle(FocusTheme.secondary)
                                }.frame(maxWidth: .infinity).padding(.top, 48)
                            } else {
                                ForEach(store.blockedApplications) { application in
                                    HStack(spacing: 16) {
                                        Image(nsImage: store.icon(for: application)).resizable().scaledToFit()
                                            .frame(width: 54, height: 54).accessibilityHidden(true)
                                        Text(application.name).font(.system(size: 18, weight: .semibold))
                                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                            .help(application.bundleIdentifier)
                                        Button { store.remove(application) } label: {
                                            Image(systemName: "minus").font(.system(size: 15, weight: .semibold))
                                                .frame(width: 32, height: 32)
                                                .background(FocusTheme.secondary.opacity(0.10), in: Circle())
                                                .frame(width: 44, height: 44).contentShape(Rectangle())
                                        }.buttonStyle(.plain).foregroundStyle(FocusTheme.ink)
                                            .accessibilityLabel("移除 \(application.name)")
                                            .help("仅移出黑名单，不会删除 App")
                                            .accessibilityIdentifier("guard.remove.\(application.bundleIdentifier)")
                                    }.frame(minHeight: 78)
                                    if application.id != store.blockedApplications.last?.id { Divider() }
                                }
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }.frame(maxWidth: .infinity)
            }.padding(.horizontal, 36).padding(.top, 14).padding(.bottom, 18)
            Divider().padding(.horizontal, 36)
            HStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 28))
                    .foregroundStyle(FocusTheme.accent.opacity(0.65)).frame(width: 38)
                Text("只隐藏，不会退出 App 或删除数据。")
                    .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                Spacer()
            }.padding(.horizontal, 36).frame(height: 68)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).foregroundStyle(FocusTheme.ink).ignoresSafeArea()
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
    let onClose: () -> Void
    var returnTitle = "返回专注"
    @State private var draft: FocusSettings
    @State private var miniCard: Bool
    init(store: PomodoroStore, returnTitle: String = "返回专注", onClose: @escaping () -> Void) {
        self.store = store; self.onClose = onClose
        self.returnTitle = returnTitle
        _draft = State(initialValue: store.settings)
        _miniCard = State(initialValue: store.showsMiniCard)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) { Label(returnTitle, systemImage: "chevron.left") }
                    .buttonStyle(.plain).font(.system(size: 15, weight: .medium))
                    .accessibilityIdentifier("settings.back")
                Spacer()
                Text(store.canPause ? "\(store.phaseTitle)  \(store.remainingText() ?? "")" : "尚未开始")
                    .font(.system(size: 13, weight: .medium)).monospacedDigit()
                    .padding(.horizontal, 14).frame(height: 30)
                    .background(FocusTheme.accent.opacity(0.08), in: Capsule())
            }
            .frame(height: 36)
            .overlay { Text("设置").font(.system(size: 20, weight: .bold)).allowsHitTesting(false) }
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("专注").font(.system(size: 26, weight: .bold))
                    Text("设置一次专注的时长。").font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                    Text("专注时长").font(.system(size: 19, weight: .semibold)).padding(.top, 28)
                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("专注时长", value: $draft.focusMinutes, format: .number.grouping(.never))
                                .textFieldStyle(.plain).multilineTextAlignment(.center)
                                .font(.system(size: 62, weight: .semibold, design: .rounded)).frame(width: 110)
                                .accessibilityLabel("专注时长")
                            VStack(spacing: 6) {
                                durationArrow("chevron.up", label: "增加专注时长") { draft.focusMinutes = min(180, draft.focusMinutes + 1) }
                                durationArrow("chevron.down", label: "减少专注时长") { draft.focusMinutes = max(1, draft.focusMinutes - 1) }
                            }
                        }.padding(16).frame(height: 98)
                            .background(FocusTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                        Text("分钟").font(.system(size: 17)).foregroundStyle(FocusTheme.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Divider().frame(height: 240)
                VStack(alignment: .leading, spacing: 12) {
                    Text("休息").font(.system(size: 26, weight: .bold))
                    Text("设置短休息、长休息的时长与间隔。").font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                    VStack(spacing: 0) {
                        numberRow("短休息", value: $draft.shortBreakMinutes, range: 1...60, unit: "分钟")
                        Divider()
                        numberRow("长休息", value: $draft.longBreakMinutes, range: 1...120, unit: "分钟")
                        Divider()
                        numberRow("长休息间隔", value: $draft.longBreakInterval, range: 1...12, unit: "轮", prefix: "每")
                    }.padding(.top, 8)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.top, 28)
            Text("新设置用于下一阶段，当前计时不变。")
                .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary).padding(.top, 12)
            Divider().padding(.vertical, 16)
            HStack {
                VStack(alignment: .leading, spacing: 9) {
                    Text("专注小卡片").font(.system(size: 20, weight: .semibold))
                    Text("专注和休息时自动显示，记住你的选择。").font(.system(size: 13)).foregroundStyle(FocusTheme.secondary)
                }
                Spacer()
                Toggle("专注小卡片", isOn: $miniCard).labelsHidden().toggleStyle(.switch)
                    .tint(FocusTheme.accent).accessibilityLabel("专注小卡片")
            }
            Divider().padding(.top, 20)
            Spacer(minLength: 12)
            HStack {
                FocusCat(size: 76).accessibilityHidden(true)
                Button("恢复默认") { draft = FocusSettings(); miniCard = true }
                    .buttonStyle(.plain).foregroundStyle(FocusTheme.secondary).font(.system(size: 14))
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                Button {
                    store.updateSettings(draft)
                    store.showsMiniCard = miniCard
                    onClose()
                } label: { Text("保存并返回").frame(width: 174, height: 46) }
                    .buttonStyle(FocusPillStyle(fill: FocusTheme.accent, ink: .white))
                    .accessibilityIdentifier("settings.save")
                    Text("休息结束后，由你开始下一轮。").font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }
            }
        }.padding(.horizontal, 48).padding(.top, 36).padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).foregroundStyle(FocusTheme.ink).ignoresSafeArea()
    }
    private func durationArrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).frame(width: 30, height: 28) }
            .buttonStyle(.plain).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel(label)
    }
    private func numberRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, prefix: String = "") -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 17, weight: .medium))
            Spacer()
            if !prefix.isEmpty { Text(prefix).font(.system(size: 13)) }
            HStack(spacing: 4) {
                TextField(title, value: value, format: .number.grouping(.never))
                    .textFieldStyle(.plain).multilineTextAlignment(.center).frame(width: 42)
                    .font(.system(size: 16, weight: .medium)).accessibilityLabel(title)
                Stepper(title, value: value, in: range).labelsHidden().frame(width: 20)
            }.padding(.horizontal, 7).frame(height: 34)
                .background(FocusTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            Text(unit).font(.system(size: 13)).frame(width: 30, alignment: .trailing)
        }.frame(height: 52)
    }
}

struct BlueToolboxHome: View {
    @State private var showsSettings = false
    @ObservedObject var store: PomodoroStore
    @ObservedObject var wellbeing: WellbeingStore
    @ObservedObject var appBlocker: AppBlockerStore
    let onTool: (ToolboxTool) -> Void
    let onHistory: () -> Void
    var body: some View {
        Group {
            if showsSettings {
                FocusSettingsView(store: store, returnTitle: "返回工具箱") {
                    withAnimation(.easeInOut(duration: 0.16)) { showsSettings = false }
                }.transition(.opacity)
            } else {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                FocusTheme.background
                HStack {
                    Text("工具箱").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    FocusSettingsButton { withAnimation(.easeInOut(duration: 0.16)) { showsSettings = true } }
                }.padding(.horizontal, 32).padding(.top, 36)
                VStack(spacing: 0) {
                    Text(store.canPause ? store.phaseTitle : "留一点时间，给重要的事。")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Color(red: 0.18, green: 0.28, blue: 0.48))
                        .padding(.horizontal, 16).frame(height: 32)
                        .background(FocusTheme.accent.opacity(0.1), in: Capsule())
                    Text(store.remainingText() ?? store.configuredFocusText)
                        .font(.system(size: 92, weight: .semibold, design: .rounded)).monospacedDigit()
                        .tracking(-3).frame(height: 114).padding(.top, 10)
                    Text(store.isRestSession ? "休息一下" : store.canPause && !store.activeTask.isEmpty ? store.activeTask : store.canPause ? store.activeCategory : store.draftCategory)
                        .font(.system(size: 18, weight: .medium)).foregroundStyle(FocusTheme.secondary)
                        .lineLimit(1).frame(maxWidth: 350).frame(height: 30)
                    HStack(spacing: 20) {
                        Button { onTool(.pomodoro) } label: {
                            Text(store.canPause ? "回到专注" : "开始专注").frame(width: 216, height: 60)
                        }.buttonStyle(FocusPillStyle(fill: FocusTheme.accent, ink: .white))
                            .accessibilityIdentifier("toolbox.focus")
                        if store.canPause {
                            Button { store.togglePause() } label: {
                                Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 20, weight: .semibold)).frame(width: 58, height: 58)
                                    .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.55))
                                    .background(FocusTheme.accent.opacity(0.1), in: Circle())
                            }.buttonStyle(.plain).accessibilityLabel(store.isPaused ? "继续计时" : "暂停计时")
                        }
                    }.padding(.top, 24)
                }.position(x: geometry.size.width / 2, y: geometry.size.height * 0.36)
                HStack(spacing: 16) {
                    tool("1 分钟冥想", detail: "今日 \(wellbeing.meditationCountToday) 次", symbol: "leaf.fill", color: Color(red: 0.43, green: 0.54, blue: 0.30), tool: .meditation)
                    Divider().frame(height: 40)
                    tool("情绪记录", detail: "今日 \(wellbeing.moodCountToday()) 次", symbol: "heart.fill", color: Color(red: 0.92, green: 0.47, blue: 0.41), tool: .mood)
                    Divider().frame(height: 40)
                    tool("App 管控", detail: appBlocker.statusText, symbol: "square.grid.2x2.fill", color: Color(red: 0.50, green: 0.46, blue: 0.42), tool: .appBlocker)
                }.padding(.horizontal, 76).frame(height: 56)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.665)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 28).fill(FocusTheme.shelf).padding(.bottom, -28)
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日收获").font(.system(size: 16, weight: .semibold))
                            HStack(spacing: 8) {
                                ForEach(0..<min(3, store.focusCountToday), id: \.self) { _ in FocusPaw(size: 66) }
                                Text("\(store.focusCountToday) 轮 · \(store.todayMinutes) 分钟")
                                    .font(.system(size: 17, weight: .medium)).fixedSize()
                            }.frame(height: 46)
                        }
                        Spacer()
                        Button(action: onHistory) {
                            HStack(spacing: 10) {
                                Text("查看记录")
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            }.font(.system(size: 15, weight: .medium)).frame(height: 40)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 50).padding(.top, 24)
                }.frame(height: 134).clipped()
                    .overlay(alignment: .topTrailing) {
                        FocusCat(size: 108).padding(.trailing, 48).offset(y: -52)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }.frame(maxHeight: .infinity, alignment: .bottom)
            }.foregroundStyle(FocusTheme.ink)
        }.ignoresSafeArea()
            }
        }
    }
    private func tool(_ title: String, detail: String, symbol: String, color: Color, tool: ToolboxTool) -> some View {
        Button { onTool(tool) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 23)).foregroundStyle(color)
                    .frame(width: 52, height: 52).background(color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 15, weight: .semibold)).fixedSize()
                    HStack(spacing: 5) {
                        Text(detail).lineLimit(1)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                    }.font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
