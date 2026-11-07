import SwiftUI

struct AppGuardPage: View {
    @ObservedObject var store: AppBlockerStore
    @ObservedObject var pomodoro: PomodoroStore
    let onBack: () -> Void
    var body: some View {
        FocusSettingsView(store: pomodoro, appBlocker: store, returnTitle: "返回专注", initialSection: .guardApps, onClose: onBack)
    }
}

enum SettingsSection { case timing, guardApps, privacy, feedback, updates }

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
    @State private var feedbackDraft = SupportFeedbackDraft()

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
                navigation("隐私与数据", icon: "hand.raised", value: .privacy, id: "settings.privacy")
                    .padding(.top, 6)
                navigation("意见反馈", icon: "bubble.left", value: .feedback, id: "settings.feedback")
                    .padding(.top, 6)
                navigation("版本与更新", icon: "arrow.down.circle", value: .updates, id: "settings.updates")
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
                else if section == .guardApps { SettingsGuardContents(store: appBlocker) }
                else if section == .privacy { SettingsPrivacyContents(store: store, appBlocker: appBlocker) }
                else if section == .feedback { SettingsFeedbackContents(draft: $feedbackDraft) }
                else { SettingsUpdatesContents() }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("计时设置").font(.system(size: 16, weight: .semibold)).padding(.bottom, 10)
                    durationRow("专注时长", detail: "设置一次专注的时长。", value: $draft.focusMinutes, range: 1...180, unit: "分钟")
                    durationRow("短休息", detail: "设置短休息的时长。", value: $draft.shortBreakMinutes, range: 1...60, unit: "分钟")
                    durationRow("长休息", detail: "设置长休息的时长。", value: $draft.longBreakMinutes, range: 1...120, unit: "分钟")
                    durationRow("长休息间隔", detail: "按当天完成轮数计算，每天重新累计。", value: $draft.longBreakInterval, range: 1...12, unit: "轮", prefix: "每")
                    visibilityRow("自动开始休息", detail: "专注完成后，自动开始短休息或长休息。", value: $draft.autoStartBreak, id: "settings.autoStartBreak")
                    visibilityRow("自动开始下一轮", detail: "休息结束后，沿用当前任务开始专注。", value: $draft.autoStartFocus, id: "settings.autoStartFocus")
                    Divider().padding(.top, 12).padding(.bottom, 18)
                    Text("显示设置").font(.system(size: 16, weight: .semibold)).padding(.bottom, 2)
                    visibilityRow("圆形悬浮入口", detail: "桌面猫头像入口。", value: $floatingEntry, id: "settings.floatingEntry")
                    visibilityRow("悬浮计时卡", detail: "专注与休息时显示剩余时间。", value: $miniCard, id: "settings.miniCard")
                }.padding(.trailing, 8)
            }
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

private enum SupportDisplay {
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—")（\(info["CFBundleVersion"] as? String ?? "—")）"
    }
    static var system: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

private struct SettingsFeedbackContents: View {
    @Binding var draft: SupportFeedbackDraft
    @State private var status = ""
    @State private var submitting = false
    private let configuration = AppSupportConfiguration()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("意见反馈").font(.system(size: 16, weight: .semibold))
                Text("告诉我哪里不好用，或你希望增加什么。请勿填写密码或其他敏感信息。")
                    .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                Picker("反馈类型", selection: $draft.category) {
                    ForEach(["使用问题", "功能建议", "其他"], id: \.self) { Text($0) }
                }.accessibilityIdentifier("feedback.category")
                TextEditor(text: $draft.content).font(.system(size: 13))
                    .frame(minHeight: 120, maxHeight: 160)
                    .padding(6).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FocusTheme.secondary.opacity(0.16)))
                    .accessibilityLabel("反馈内容").accessibilityIdentifier("feedback.content")
                Text("\(draft.content.unicodeScalars.count)/2000字").font(.system(size: 11))
                    .foregroundStyle(draft.content.unicodeScalars.count > 2000 ? .red : FocusTheme.secondary)
                TextField("联系方式（选填，最多200字）", text: $draft.contact)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("feedback.contact")
                Toggle("附上应用和macOS版本，帮助排查", isOn: $draft.includesVersion)
                    .font(.system(size: 12)).accessibilityIdentifier("feedback.includeVersion")
                if draft.includesVersion {
                    Text("将附上：Pang 大师 \(SupportDisplay.version)，macOS \(SupportDisplay.system)")
                        .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                }
                Text("仅提交以上内容，不会附带任务、专注记录、心情内容或日志。反馈在服务端保留180天，可在反馈中注明查阅或删除请求及原反馈编号。")
                    .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                if configuration.feedbackURL == nil {
                    Text("反馈服务正在准备中，暂未开放在线提交。你可以先复制并保留内容。")
                        .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                }
                HStack(spacing: 12) {
                    Button(submitting ? "正在提交…" : "提交反馈") {
                        let snapshot = draft
                        submitting = true
                        status = "正在提交，请稍候。"
                        Task { @MainActor in
                            defer { submitting = false }
                            do {
                                let id = try await SupportFeedbackClient().submit(snapshot, configuration: configuration,
                                    version: SupportDisplay.version, system: SupportDisplay.system)
                                if draft == snapshot { draft = SupportFeedbackDraft() }
                                status = "反馈已收到，谢谢。反馈编号：" + id
                            } catch {
                                status = (error as? SupportFeedbackError)?.localizedDescription
                                    ?? "网络连接失败，内容已保留。请稍后重试，相同内容不会重复保存。"
                            }
                        }
                    }.buttonStyle(.borderedProminent)
                        .disabled(submitting || !draft.isValid || configuration.feedbackURL == nil)
                        .accessibilityIdentifier("feedback.submit")
                    Button("复制反馈内容") {
                        NSPasteboard.general.clearContents()
                        let copied = NSPasteboard.general.setString(draft.message(version: SupportDisplay.version, system: SupportDisplay.system), forType: .string)
                        status = copied ? "反馈内容已复制。" : "复制失败，请重试。"
                    }.disabled(!draft.isValid).accessibilityIdentifier("feedback.copy")
                }
                if !status.isEmpty { Text(status).font(.system(size: 12)).textSelection(.enabled).accessibilityIdentifier("feedback.status") }
            }.disabled(submitting).frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
        }
    }
}

private struct SettingsUpdatesContents: View {
    @State private var status = ""
    private let configuration = AppSupportConfiguration()
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("版本与更新").font(.system(size: 16, weight: .semibold))
            Text("当前版本：" + SupportDisplay.version).font(.system(size: 14))
            Text("关闭窗口后仍会计时，可从 Dock、菜单栏或 Control + Option + P 再次打开。真正退出应用后，专注截止时间会保留，重开时恢复或结算；退出期间不会发出专注完成提醒。进行中的1分钟冥想在退出后中断。")
                .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
            Text("发布后的更新提醒、下载与安装由Mac App Store提供。你可以在App Store设置中开启自动更新。")
                .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary)
            if configuration.productURL == nil {
                Text("应用上架后，这里将直达产品页；目前可以打开App Store。")
                    .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
            }
            Button(configuration.productURL == nil ? "打开App Store" : "前往App Store更新") {
                if let url = configuration.productURL {
                    status = NSWorkspace.shared.open(url) ? "已打开商店页面，请在商店查看更新状态。" : "暂时无法打开商店页面，请重试。"
                } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.AppStore") {
                    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                        let message = error == nil ? "已打开App Store，请选择“更新”查看。" : "暂时无法打开App Store，请重试。"
                        Task { @MainActor in status = message }
                    }
                } else {
                    status = "未找到App Store，请从系统应用中打开。"
                }
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("updates.openStore")
            if !status.isEmpty { Text(status).font(.system(size: 12)).accessibilityIdentifier("updates.status") }
            Spacer()
        }
    }
}

private enum PrivacyDeletion: String, Identifiable, CaseIterable {
    case focus, mood, meditation, tasks, applications
    var id: String { rawValue }
    var title: String {
        switch self {
        case .focus: return "删除专注记录"
        case .mood: return "删除心情记录"
        case .meditation: return "删除冥想记录"
        case .tasks: return "删除保存的任务"
        case .applications: return "清空守护名单"
        }
    }
    var detail: String {
        switch self {
        case .focus: return "删除全部专注历史、成果笔记和完成次数，保留保存的任务与时长设置。"
        case .mood: return "删除全部心情记录及文字，保留其他记录。"
        case .meditation: return "删除全部冥想完成记录，保留提醒时间。"
        case .tasks: return "删除任务选项和上次选择，历史专注记录中的任务名称保留。"
        case .applications: return "移除全部所选App及访问书签，并关闭守护；不会退出或删除这些App。"
        }
    }
}

private struct SettingsPrivacyContents: View {
    @ObservedObject var store: PomodoroStore
    @ObservedObject var appBlocker: AppBlockerStore
    @EnvironmentObject private var wellbeing: WellbeingStore
    @State private var showsPolicy = false
    @State private var pendingDeletion: PrivacyDeletion?
    @State private var feedback = ""
    private var deletionAllowed: Bool { !store.hasActiveSession && !wellbeing.isMeditating }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("隐私与数据").font(.system(size: 16, weight: .semibold))
                Text("任务、记录和设置保存在这台Mac。应用不上传这些数据，也不包含广告或第三方分析服务。")
                    .font(.system(size: 13)).foregroundStyle(FocusTheme.secondary)
                Text("在线反馈开放后，点击提交会将你填写的内容发送到反馈服务，详见政策。")
                    .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                Button("阅读隐私政策") { showsPolicy = true }
                    .accessibilityIdentifier("privacy.policy")
                Divider()
                Text("管理本机数据").font(.system(size: 15, weight: .semibold))
                Text("记录不会按条数自动删除。下面的操作需要再次确认，确认后无法在应用内撤销；其他设置保持不变。")
                    .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                if !deletionAllowed {
                    Text("请先结束当前计时或冥想，再删除数据。")
                        .font(.system(size: 12)).foregroundStyle(FocusTheme.accent)
                        .accessibilityIdentifier("privacy.deletionBlocked")
                }
                ForEach(PrivacyDeletion.allCases) { action in
                    VStack(alignment: .leading, spacing: 5) {
                        Button(action.title) { pendingDeletion = action }.foregroundStyle(.red)
                            .disabled(!deletionAllowed).accessibilityIdentifier("privacy.delete.\(action.rawValue)")
                        Text(action.detail).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                    }
                }
                if !feedback.isEmpty {
                    Text(feedback).font(.system(size: 12)).accessibilityIdentifier("privacy.feedback")
                }
                Text("应用内删除不会清除系统通知、系统日志或已有的系统备份。")
                    .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
        }
        .alert(item: $pendingDeletion) { action in
            Alert(title: Text("确认\(action.title)？"),
                  message: Text(action.detail + "\n此操作无法在应用内撤销。"),
                  primaryButton: .destructive(Text("确认删除")) {
                      guard deletionAllowed else { feedback = "当前有进行中的计时，未删除数据。"; return }
                      switch action {
                      case .focus: store.deleteFocusHistory()
                      case .mood: wellbeing.deleteMoodHistory()
                      case .meditation: wellbeing.deleteMeditationHistory()
                      case .tasks: store.deleteSavedTasks()
                      case .applications: appBlocker.deleteSavedApplications()
                      }
                      feedback = "已完成：" + action.title
                  }, secondaryButton: .cancel(Text("取消")))
        }
        .sheet(isPresented: $showsPolicy) {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策").font(.system(size: 18, weight: .semibold))
                ScrollView {
                    Text(policyText).font(.system(size: 13)).lineSpacing(5)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { Spacer(); Button("关闭") { showsPolicy = false }.keyboardShortcut(.cancelAction) }
            }.padding(24).frame(width: 490, height: 490)
        }
    }
    private var policyText: String {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "隐私政策未能载入，请重新打开应用后重试。"
        }
        return text
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
