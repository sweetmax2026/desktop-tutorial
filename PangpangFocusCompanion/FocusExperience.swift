import SwiftUI
import CoreText

struct FocusCat: View {
    var size: CGFloat = 48
    var asset: String = "pangpang-head-v1"
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: asset, withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else { Image(systemName: "cat.fill").resizable().scaledToFit() }
        }.frame(width: size, height: size)
    }
}

struct CompactFocusCard: View {
    @ObservedObject var store: PomodoroStore
    let onOpen: () -> Void
    let onHide: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    FocusCat(size: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.phaseTitle).font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                        Text(store.remainingText() ?? (store.phase == .completed ? "查看收获" : "准备下一轮"))
                            .font(.system(size: 21, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).help("打开专注").accessibilityIdentifier("mini.open")
            Button(action: onHide) {
                Image(systemName: "xmark").font(.system(size: 11)).frame(width: 28, height: 32)
            }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary).help("本轮收起计时卡")
        }.padding(18).frame(width: 264, height: 92)
            .background(Color(red: 0.96, green: 0.98, blue: 1), in: RoundedRectangle(cornerRadius: 22))
    }
}

// Compatibility wrapper for existing routes. There is no separate immersive mode.
struct FocusExperienceView: View {
    @ObservedObject var store: PomodoroStore
    var appBlocker: AppBlockerStore
    let onBack: () -> Void
    let onClose: () -> Void
    let onHistory: () -> Void
    var editLatestNote = false
    var body: some View {
        FocusFlowScreen(store: store, appBlocker: appBlocker,
            onTool: { _ in onBack() }, onHistory: onHistory, editLatestNote: editLatestNote)
    }
}

struct FocusFlowScreen: View {
    @ObservedObject var store: PomodoroStore
    @ObservedObject var appBlocker: AppBlockerStore
    let onTool: (ToolboxTool) -> Void
    let onHistory: () -> Void
    var editLatestNote = false
    let entryDuration: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSettings = false
    @State private var showsNote = false
    @State private var note = ""
    @State private var noteRecordID: UUID?
    @State private var rewardLanded = false
    @State private var showsAbandonedFeedback = false
    @State private var focusProgress: Double
    private var running: Bool { store.phase == .focus }
    private var completed: Bool { store.phase == .completed }
    private var ready: Bool { !running && !completed && !store.isRestSession && !store.isPaused }

    @MainActor
    init(store: PomodoroStore, appBlocker: AppBlockerStore,
         onTool: @escaping (ToolboxTool) -> Void, onHistory: @escaping () -> Void,
         editLatestNote: Bool = false, entryDuration: TimeInterval = 0.35) {
        self.store = store; self.appBlocker = appBlocker
        self.onTool = onTool; self.onHistory = onHistory
        self.editLatestNote = editLatestNote; self.entryDuration = entryDuration
        _focusProgress = State(initialValue: store.phase == .focus ? 1 : 0)
    }

    var body: some View {
        Group {
            if showsSettings {
                FocusSettingsView(store: store, appBlocker: appBlocker) { showsSettings = false }
            } else if ready || running {
                preparationAndFocus
            } else {
                GeometryReader { geometry in
                    ZStack {
                        if store.isRestSession { runningBackground.opacity(0.22).background(.white) }
                        else { FocusTheme.background }
                        if store.isPaused { header }
                        if completed {
                            completionContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                        } else if store.isPaused {
                            legacyContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                        } else if store.isRestSession {
                            restContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.47)
                        }
                        if store.isRestSession {
                            wellbeingActions
                                .position(x: geometry.size.width / 2, y: geometry.size.height - 108)
                        }
                        if !running {
                            footer
                            FocusCat(size: 160, asset: store.isRestSession ? "pangpang-rest-peek-v1" : "pangpang-home-peek-v1")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .padding(.trailing, 28).padding(.bottom, 2)
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }.foregroundStyle(FocusTheme.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                }.ignoresSafeArea()
            }
        }
        .onAppear {
            if editLatestNote { openNote() }
        }
        .onChange(of: store.phase) { phase in
            if phase == .focus {
                showsSettings = false; showsNote = false; showsAbandonedFeedback = false
                withAnimation(reduceMotion ? nil : .easeOut(duration: entryDuration)) { focusProgress = 1 }
            } else {
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { focusProgress = 0 }
            }
        }
        .task(id: store.completionRecordID) {
            guard completed else { return }
            rewardLanded = reduceMotion
            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled, completed else { return }
                withAnimation(.spring(response: 0.65, dampingFraction: 0.55)) { rewardLanded = true }
            }
        }
        .onChange(of: store.lastAbandonedRecordID) { id in showsAbandonedFeedback = id != nil }
        .task(id: store.lastAbandonedRecordID) {
            guard store.lastAbandonedRecordID != nil else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { showsAbandonedFeedback = false }
        }
    }

    /// One persistent timer moves between ready and focus; its identity, glyphs
    /// and live countdown survive the transition. Model time starts immediately.
    private var preparationAndFocus: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let scale = min(width / 800, height / 600)
            let progress = min(1, max(0, focusProgress))
            ZStack {
                FocusReadySurface(store: store, onSettings: { showsSettings = true },
                    onHistory: onHistory, onTool: onTool,
                    feedback: showsAbandonedFeedback ? store.lastAbandonedRecord.map { "本轮已结束，\(elapsed($0.seconds))已记录" } : nil,
                    controlsOpacity: 1 - progress, controlsFadeDuration: reduceMotion ? 0 : entryDuration * 0.45)
                    .allowsHitTesting(ready).accessibilityHidden(!ready)
                runningBackground.overlay(Color.black.opacity(0.25))
                    .frame(width: width, height: height).clipped()
                    .opacity(progress).allowsHitTesting(false)
                Color.clear.modifier(AnimatedTimerInk(
                    text: running ? (store.remainingText() ?? store.configuredFocusText) : store.configuredFocusText,
                    scale: scale, compactDigits: store.focusTimerUsesCompactDigits, lightInk: progress))
                    .frame(width: 400 * scale, height: 220 * scale)
                    .position(x: width * (0.2775 + 0.2225 * progress), y: height * (0.377 + 0.113 * progress))
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(running ? "剩余专注时间" : "专注时长")
                    .accessibilityValue(running ? (store.remainingText() ?? store.configuredFocusText) : store.configuredFocusText)
                    .accessibilityIdentifier(running ? "focus.countdown" : "focus.duration")
                if running {
                    HoldToAbandon(action: store.endCurrentSession)
                        .frame(width: 210, height: 48)
                        .position(x: width / 2, y: height - 52)
                        .opacity(progress)
                        .animation(reduceMotion ? nil : .easeOut(duration: entryDuration * 0.35).delay(entryDuration * 0.65), value: focusProgress)
                }
            }.frame(width: width, height: height).clipped()
        }.ignoresSafeArea()
    }

    private var header: some View {
        VStack {
            HStack(spacing: 20) {
                Text(AppBrand.wordmark).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(FocusTheme.ink)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 19)).frame(width: 36, height: 36)
                }.buttonStyle(.plain).help("设置").accessibilityLabel("设置").accessibilityIdentifier("focus.settings")
                Button(action: onHistory) {
                    Image(systemName: "chart.bar").font(.system(size: 19)).frame(width: 36, height: 36)
                }.buttonStyle(.plain).help("数据统计").accessibilityLabel("数据统计").accessibilityIdentifier("focus.statistics")
            }.foregroundStyle(FocusTheme.secondary).padding(.horizontal, 32).padding(.top, 42)
            Spacer()
        }
    }

    private var restContents: some View {
        VStack(spacing: 0) {
            Text("休息中").font(.system(size: 15, weight: .medium))
                .foregroundStyle(FocusTheme.secondary).padding(.bottom, 16)
            countdown(size: 124, color: FocusTheme.ink)
            Button("结束休息") { store.resetToReady() }
                .buttonStyle(.plain).font(.system(size: 17, weight: .medium))
                .frame(width: 224, height: 56)
                .background(FocusTheme.accent.opacity(0.1), in: Capsule())
                .padding(.top, 36).accessibilityIdentifier("focus.endRest")
                .help("结束休息，回到准备；不会自动开始下一轮。")
        }
    }

    private var wellbeingActions: some View {
        HStack(spacing: 24) {
            FocusWellbeingShortcut(title: "1 分钟冥想", symbol: "leaf.fill",
                color: Color(red: 0.43, green: 0.54, blue: 0.30), id: "focus.meditation") { onTool(.meditation) }
            FocusWellbeingShortcut(title: "情绪记录", symbol: "heart.fill",
                color: Color(red: 0.92, green: 0.47, blue: 0.41), id: "focus.mood") { onTool(.mood) }
        }
    }

    private var legacyContents: some View {
        VStack(spacing: 16) {
            Text("上次的计时已暂停").font(.system(size: 15)).foregroundStyle(FocusTheme.secondary)
            countdown(size: 96, color: FocusTheme.ink)
                .overlay(alignment: .trailing) { resetControl.offset(x: 56) }
            primary("继续这轮计时", id: "focus.resumeLegacy") { store.togglePause() }
            Text("已完成记录不会清空").font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
        }
    }

    private var resetControl: some View {
        Button { store.resetToReady() } label: {
            Image(systemName: "arrow.counterclockwise").font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary)
            .help("重置为准备状态，保留已有记录")
            .accessibilityLabel("重置计时").accessibilityIdentifier("focus.reset")
    }

    private var completionContents: some View {
        VStack(spacing: 12) {
            FocusPaw(size: 152).scaleEffect(rewardLanded ? 1 : 0.6)
                .offset(y: rewardLanded ? 0 : -70).rotationEffect(.degrees(rewardLanded ? -8 : -20))
                .opacity(rewardLanded ? 1 : 0)
            Text("这一轮，完成了").font(.system(size: 26, weight: .semibold))
            Text("\(Int((store.completionRecord?.seconds ?? 0) / 60)) 分钟")
                .font(.system(size: 60, weight: .semibold, design: .rounded)).monospacedDigit()
            primary("休息一下", id: "focus.startRest") { store.startBreak() }.padding(.top, 8)
            HStack(spacing: 22) {
                Button("记一笔") { openNote() }.accessibilityIdentifier("focus.note")
                    .popover(isPresented: $showsNote) { noteEditor }
                Divider().frame(height: 12)
                Button("先不休息") { store.resetToReady() }.accessibilityIdentifier("focus.skipRest")
            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).padding(.top, 4)
        }.frame(width: 400)
    }

    private var footer: some View {
        VStack {
            Spacer()
            Button(action: onHistory) {
                HStack(spacing: 9) {
                    ForEach(Array(store.todayRecords.suffix(8))) { record in
                        FocusPaw(size: 40).saturation(record.completed ? 1 : 0)
                            .opacity(record.completed ? 1 : 0.48)
                            .offset(y: completed && record.id == store.completionRecordID && !rewardLanded ? -32 : 0)
                            .help(record.completed ? "完成一轮" : "提前结束 · \(elapsed(record.seconds))")
                    }
                    Text("今日 \(store.focusCountToday) 轮").font(.system(size: 13, weight: .medium))
                        .padding(.leading, 8)
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }.foregroundStyle(FocusTheme.secondary).frame(height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("今日 \(store.focusCountToday) 轮，\(store.todayMinutes) 分钟，查看记录")
                .accessibilityIdentifier("focus.history")
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32).padding(.bottom, 24)
                .padding(.trailing, 180)
        }
    }

    private var runningBackground: some View {
        Group {
            if let url = Bundle.main.url(forResource: "focus-quiet-backdrop-v1", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFill()
            } else { Color(red: 0.54, green: 0.68, blue: 0.94) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private func countdown(size: CGFloat, color: Color) -> some View {
        Text(store.remainingText() ?? store.configuredFocusText)
            .font(.system(size: size, weight: .semibold, design: .rounded)).monospacedDigit().tracking(-3)
            .foregroundStyle(color).fixedSize().accessibilityIdentifier("focus.countdown")
    }
    private func primary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(width: 272, height: 64) }
            .buttonStyle(FocusPillStyle(fill: FocusTheme.accent, ink: .white, fontSize: 23)).accessibilityIdentifier(id)
    }
    private func elapsed(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) 秒" : "\(Int(seconds / 60)) 分钟"
    }
    private func openNote() {
        guard let record = store.completionRecord ?? store.latestCompleted else { return }
        note = record.note; noteRecordID = record.id; showsNote = true
    }
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("记下这一轮的成果").font(.system(size: 16, weight: .semibold))
            TextField("完成了什么？（选填）", text: $note).textFieldStyle(.roundedBorder)
            HStack {
                Text("\(note.count)/100").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("保存") {
                    if let noteRecordID { store.updateNote(id: noteRecordID, note: note) }
                    showsNote = false
                }.disabled(note.count > 100).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 330)
    }
}

/// The ready-page illustration and controls; the enclosing flow owns the timer
/// so it can remain continuous when the controls fade away.
private struct FocusReadySurface: View {
    @ObservedObject var store: PomodoroStore
    let onSettings: () -> Void
    let onHistory: () -> Void
    let onTool: (ToolboxTool) -> Void
    var feedback: String?
    var controlsOpacity: Double = 1
    var controlsFadeDuration: TimeInterval = 0.16
    @State private var taskDraft = ""
    @State private var minutesDraft = 25
    @State private var categoryDraft = "专注"
    @State private var showsTaskEditor = false
    @State private var showsTaskHistory = false
    @FocusState private var taskFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let scale = min(width / 800, height / 600)
            let column = min(width * 0.355, 380 * scale)
            let center = width * 0.2775
            ZStack {
                if let url = Bundle.main.url(forResource: "focus-window-scene-v1", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: width, height: height).clipped()
                        .allowsHitTesting(false).accessibilityHidden(true)
                } else { Color(red: 0.98, green: 0.98, blue: 0.96) }
                Group {
                Text(AppBrand.wordmark).font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(Color(red: 0.43, green: 0.43, blue: 0.43))
                    .position(x: width / 2, y: 14 * scale)
                    .allowsHitTesting(false).accessibilityHidden(true)
                HStack(spacing: 15 * scale) {
                    Button(action: onHistory) { readyIcon("chart", fallback: "chart.bar.xaxis", size: 23 * scale).frame(width: 36 * scale, height: 36 * scale) }
                        .help("数据统计").accessibilityLabel("数据统计").accessibilityIdentifier("focus.statistics")
                    Button(action: onSettings) { readyIcon("settings", fallback: "gearshape", size: 23 * scale).frame(width: 36 * scale, height: 36 * scale) }
                        .help("设置").accessibilityLabel("设置").accessibilityIdentifier("focus.settings")
                }.buttonStyle(FocusReadyQuietStyle()).position(x: width - 64 * scale, y: 59 * scale)

                Button {
                    taskDraft = store.draftTask
                    minutesDraft = store.settings.focusMinutes
                    categoryDraft = store.draftCategory
                    showsTaskHistory = false
                    showsTaskEditor = true
                } label: {
                    HStack(spacing: 9 * scale) {
                        Text(store.draftTask.isEmpty ? "添加本轮任务（选填）" : store.draftTask)
                            .font(.system(size: (store.draftTask.isEmpty ? 15 : 19) * scale, weight: .medium))
                            .lineLimit(1).truncationMode(.tail)
                        Text("编辑").font(.system(size: 10 * scale)).foregroundStyle(Color(red: 0.51, green: 0.55, blue: 0.62))
                    }.padding(.horizontal, 12 * scale).frame(maxWidth: column, minHeight: 42 * scale)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(FocusReadyQuietStyle())
                    .accessibilityLabel("编辑本轮任务、时长与类别").accessibilityIdentifier("focus.taskEdit")
                    .accessibilityValue(store.draftTask.isEmpty ? "未添加任务" : store.draftTask)
                    .sheet(isPresented: $showsTaskEditor) { taskEditor }
                    .position(x: center, y: height * 0.54)

                Button { store.startFocus() } label: {
                    Text("开始专注").font(.system(size: 21 * scale, weight: .medium))
                        .frame(width: column, height: 55 * scale)
                }.buttonStyle(FocusReadyPrimaryStyle()).position(x: center, y: height * 0.64)
                    .accessibilityIdentifier("focus.start")

                HStack(spacing: 10 * scale) {
                    readyShortcut("1 分钟冥想", icon: "leaf", fallback: "leaf", id: "focus.meditation", scale: scale, width: (column + 12 * scale) / 2) {
                        onTool(.meditation)
                    }
                    readyShortcut("记录心情", icon: "heart", fallback: "heart", id: "focus.mood", scale: scale, width: (column + 12 * scale) / 2) {
                        onTool(.mood)
                    }
                }.position(x: center, y: height * 0.758)

                if let feedback {
                    Text(feedback).font(.system(size: 11 * scale)).foregroundStyle(FocusTheme.secondary)
                        .position(x: center, y: height * 0.84).accessibilityIdentifier("focus.abandonedFeedback")
                }
                Button { onHistory() } label: {
                    HStack(spacing: 18 * scale) {
                        HStack(spacing: 8 * scale) {
                            ForEach(Array(store.todayRecords.suffix(5))) { record in
                                FocusPaw(size: 36 * scale).saturation(record.completed ? 1 : 0)
                                    .opacity(record.completed ? 1 : 0.48)
                                    .help(record.completed ? "完成一轮" : "提前结束")
                            }
                        }.accessibilityHidden(true)
                        Text("今日 \(store.focusCountToday) 轮 · \(store.todayMinutes) 分钟")
                            .font(.system(size: 13 * scale, weight: .medium)).lineLimit(1)
                    }.padding(.horizontal, 10 * scale).frame(height: 44 * scale)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(FocusReadyQuietStyle())
                    .accessibilityLabel("今日 \(store.focusCountToday) 轮，\(store.todayMinutes) 分钟，查看记录")
                    .accessibilityIdentifier("focus.history")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 32 * scale).padding(.bottom, 24 * scale).padding(.trailing, width * 0.43)
                }.opacity(controlsOpacity)
                    .animation(controlsFadeDuration > 0 ? .easeOut(duration: controlsFadeDuration) : nil, value: controlsOpacity)
            }.foregroundStyle(Color(red: 0.19, green: 0.24, blue: 0.34))
                .frame(width: width, height: height).clipped()
        }.ignoresSafeArea()
            .onChange(of: store.phase) { if $0 == .focus { showsTaskEditor = false } }
    }

    private func saveTask() {
        store.saveTaskConfiguration(name: taskDraft, category: categoryDraft, focusMinutes: minutesDraft)
        showsTaskEditor = false
        taskFocused = false
    }
    private func readyIcon(_ name: String, fallback: String, size: CGFloat) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: "focus-icon-\(name)-v1", withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else { Image(systemName: fallback).resizable().scaledToFit() }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
    private func readyShortcut(_ title: String, icon: String, fallback: String, id: String, scale: CGFloat, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10 * scale) {
                readyIcon(icon, fallback: fallback, size: 24 * scale)
                Text(title).font(.system(size: 14 * scale, weight: .medium)).lineLimit(1)
            }.frame(width: width, height: 48 * scale).contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(FocusReadyQuietStyle()).accessibilityIdentifier(id)
    }
    private var taskEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本轮任务").font(.system(size: 16, weight: .semibold))
            HStack(spacing: 6) {
                TextField("任务名称（选填）", text: $taskDraft).textFieldStyle(.roundedBorder)
                    .focused($taskFocused).onSubmit(saveTask)
                    .accessibilityLabel("任务名称").accessibilityIdentifier("focus.taskInput")
                Button { showsTaskHistory.toggle() } label: {
                    Image(systemName: showsTaskHistory ? "chevron.up" : "chevron.down").frame(width: 28, height: 24)
                }.accessibilityLabel("选择历史任务").accessibilityIdentifier("focus.taskHistory")
            }
            if showsTaskHistory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("历史任务").font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                    if store.taskPresets.isEmpty {
                        Text("还没有历史任务，保存后会出现在这里。")
                            .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).padding(.vertical, 10)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(store.taskPresets) { preset in
                                    HStack(spacing: 6) {
                                        Button {
                                            taskDraft = preset.name; categoryDraft = preset.category
                                            minutesDraft = preset.focusMinutes; showsTaskHistory = false
                                        } label: {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(preset.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                                Text("\(preset.category) · \(preset.focusMinutes) 分钟")
                                                    .font(.system(size: 11)).foregroundStyle(FocusTheme.secondary)
                                            }.frame(maxWidth: .infinity, alignment: .leading).padding(8).contentShape(Rectangle())
                                        }.buttonStyle(.plain).accessibilityLabel("选择 \(preset.name)，\(preset.category)，\(preset.focusMinutes) 分钟")
                                        Button { store.removeTaskPreset(id: preset.id) } label: {
                                            Image(systemName: "trash").frame(width: 28, height: 30)
                                        }.buttonStyle(.borderless).help("从历史任务中移除，已完成记录保留")
                                            .accessibilityLabel("删除历史任务 \(preset.name)")
                                    }
                                }
                            }
                        }.frame(height: min(160, CGFloat(store.taskPresets.count) * 54))
                    }
                    Button("添加新任务") { taskDraft = ""; showsTaskHistory = false; taskFocused = true }
                        .buttonStyle(.link).accessibilityIdentifier("focus.newTask")
                }.padding(10).background(FocusTheme.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
            }
            Stepper("专注 \(minutesDraft) 分钟", value: $minutesDraft, in: 1...180)
                .accessibilityIdentifier("focus.taskMinutes")
            Picker("类别", selection: $categoryDraft) {
                ForEach(taskCategories, id: \.self) { Text($0) }
            }
            HStack {
                Button("取消") { showsTaskEditor = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存并使用", action: saveTask).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("focus.saveTask")
            }
        }.padding(22).frame(width: 340).environment(\.colorScheme, .light)
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async { taskFocused = true }
            }
            .onDisappear { taskFocused = false }
    }
    private var taskCategories: [String] {
        let categories = ["专注", "工作", "阅读", "学习", "其他"]
        return categories.contains(categoryDraft) ? categories : categories + [categoryDraft]
    }
}

/// DIN's glyph outlines extend above its advertised ascender. SwiftUI Text
/// clips that overshoot; center the real outlines in a roomy native surface.
// Interpolate in SwiftUI before updating AppKit; NSViewRepresentable's own
// property updates otherwise jump to their final value during layout motion.
private struct AnimatedTimerInk: AnimatableModifier {
    let text: String
    let scale: CGFloat
    let compactDigits: Bool
    var lightInk: Double
    var animatableData: Double {
        get { lightInk }
        set { lightInk = newValue }
    }
    func body(content: Content) -> some View {
        ReadyTimerLabel(text: text, scale: scale, compactDigits: compactDigits, lightInk: lightInk)
    }
}

private struct ReadyTimerLabel: NSViewRepresentable {
    let text: String
    let scale: CGFloat
    let compactDigits: Bool
    let lightInk: Double
    func makeNSView(context: Context) -> ReadyTimerDisplay { ReadyTimerDisplay() }
    func updateNSView(_ view: ReadyTimerDisplay, context: Context) {
        view.text = text; view.scale = scale; view.compactDigits = compactDigits
        view.lightInk = lightInk; view.needsDisplay = true
    }
}

private final class ReadyTimerDisplay: NSView {
    var text = "25:00"
    var scale: CGFloat = 1
    var compactDigits = false
    var lightInk: Double = 0
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let parts = text.split(separator: ":")
        let digitSize: CGFloat = compactDigits ? 144 : 184
        let digitFont = NSFont(name: "DINCondensed-Bold", size: digitSize * scale) ?? .systemFont(ofSize: digitSize * scale)
        let colonFont = NSFont(name: "ArialRoundedMTBold", size: 107 * scale) ?? .systemFont(ofSize: 107 * scale)
        let ink = CGFloat(min(1, max(0, lightInk)))
        let segments = [(String(parts.first ?? "25"), digitFont), (":", colonFont), (String(parts.last ?? "00"), digitFont)]
        func line(_ value: String, font: NSFont) -> CTLine {
            CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [
                .font: font, .kern: -6 * scale,
                .foregroundColor: NSColor(red: 0.09 + 0.91 * ink, green: 0.11 + 0.89 * ink,
                                          blue: 0.14 + 0.86 * ink, alpha: 1)
            ]))
        }
        let lines = segments.map { line($0.0, font: $0.1) }
        // Digit advances are tabular but outline widths (especially 1) differ.
        // Center fixed zero-reference cells, not each live string's outline.
        let boxes = segments.map { value, font in
            CTLineGetBoundsWithOptions(line(value == ":" ? ":" : String(repeating: "0", count: value.count), font: font), .useGlyphPathBounds)
        }
        let widths = lines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }
        let gap = 6 * scale
        var x = (bounds.width - widths.reduce(0, +) - gap * 2) / 2
        context.saveGState()
        context.textMatrix = .identity
        for index in lines.indices {
            let box = boxes[index]
            context.textPosition = CGPoint(x: x + (widths[index] - box.width) / 2 - box.minX,
                                           y: bounds.midY - box.midY)
            CTLineDraw(lines[index], context)
            x += widths[index] + gap
        }
        context.restoreGState()
    }
}

private struct FocusReadyQuietStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background((hovered || focused) ? Color.white.opacity(configuration.isPressed ? 0.8 : 0.62) : .clear,
                in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity((hovered || focused) ? 0.075 : 0), radius: configuration.isPressed ? 2 : 9, y: configuration.isPressed ? 1 : 3)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? FocusTheme.accent : .clear, lineWidth: 2))
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
    }
}

private struct FocusReadyPrimaryStyle: ButtonStyle {
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.white)
            .background(Color(red: 0.24, green: configuration.isPressed ? 0.41 : 0.48, blue: configuration.isPressed ? 0.88 : 0.99), in: Capsule())
            .shadow(color: FocusTheme.accent.opacity(hovered ? 0.16 : 0), radius: configuration.isPressed ? 2 : 7, y: configuration.isPressed ? 1 : 3)
            .onHover { hovered = $0 }
    }
}

private struct FocusWellbeingShortcut: View {
    let title: String
    let symbol: String
    let color: Color
    let id: String
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Label {
                Text(title).font(.system(size: 13, weight: .medium))
            } icon: {
                Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(color)
            }.foregroundStyle(FocusTheme.secondary).padding(.horizontal, 12).frame(height: 40)
                .background(hovered ? color.opacity(0.08) : .clear, in: Capsule())
                .contentShape(Capsule())
        }.buttonStyle(.plain).onHover { hovered = $0 }.accessibilityIdentifier(id)
    }
}

/// Pointer hold is cancellable on release/leave. Keyboard and VoiceOver use an explicit
/// confirmation, so neither a stray click nor a single key abandons a session.
struct HoldToAbandon: NSViewRepresentable {
    let action: () -> Void
    func makeNSView(context: Context) -> HoldAbandonButton { HoldAbandonButton() }
    func updateNSView(_ view: HoldAbandonButton, context: Context) { view.onConfirm = action }
}

final class HoldAbandonButton: NSButton {
    var onConfirm: (() -> Void)?
    private var work: DispatchWorkItem?
    private var started: TimeInterval?
    private var progressTimer: Timer?
    override var acceptsFirstResponder: Bool { true }
    init() {
        super.init(frame: .zero)
        isBordered = false
        setAccessibilityLabel("长按放弃专注")
        setAccessibilityHelp("按住一秒半放弃；松开或移出可取消。键盘或辅助功能激活时需要确认。")
        setAccessibilityIdentifier("focus.abandon")
        font = .systemFont(ofSize: 15, weight: .medium)
        contentTintColor = NSColor(red: 0.09, green: 0.14, blue: 0.23, alpha: 1)
        title = "长按放弃专注"
    }
    required init?(coder: NSCoder) { nil }
    override func mouseDown(with event: NSEvent) {
        guard work == nil else { return }
        started = ProcessInfo.processInfo.systemUptime
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.window?.isKeyWindow == true else { self?.cancelHold(); return }
            self.cancelHold()
            self.onConfirm?()
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.needsDisplay = true }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) { cancelHold() }
    override func mouseDragged(with event: NSEvent) {
        if !bounds.insetBy(dx: -6, dy: -6).contains(convert(event.locationInWindow, from: nil)) { cancelHold() }
    }
    override func viewDidMoveToWindow() { if window == nil { cancelHold() } }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 { confirmAccessible() }
        else { super.keyDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool { confirmAccessible(); return true }
    private func confirmAccessible() {
        guard let window else { return }
        cancelHold()
        let alert = NSAlert()
        alert.messageText = "结束这轮专注？"
        alert.informativeText = "已投入的时间会保留，但不计为完成一轮。"
        alert.addButton(withTitle: "继续专注")
        alert.addButton(withTitle: "放弃本轮")
        alert.beginSheetModal(for: window) { [weak self] result in
            if result == .alertSecondButtonReturn { self?.onConfirm?() }
        }
    }
    private func cancelHold() {
        work?.cancel(); work = nil; started = nil
        progressTimer?.invalidate(); progressTimer = nil; needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        if let started {
            let progress = min(1, (ProcessInfo.processInfo.systemUptime - started) / 1.5)
            NSColor.white.withAlphaComponent(0.22).setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height),
                         xRadius: 12, yRadius: 12).fill()
        }
        super.draw(dirtyRect)
    }
}

struct FocusPaw: View {
    let size: CGFloat
    var body: some View {
        if let url = Bundle.main.url(forResource: "focus-paw-simple-v1", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
        }
    }
}

struct FocusPillStyle: ButtonStyle {
    let fill: Color
    let ink: Color
    var fontSize: CGFloat = 21
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(ink)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .shadow(color: fill.opacity(0.2), radius: configuration.isPressed ? 3 : 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TodayHarvestView: View {
    @ObservedObject var store: PomodoroStore
    var body: some View {
        HStack(spacing: 8) {
            FocusPaw(size: 28)
            Text("今日 \(store.focusCountToday) 轮 · \(store.todayMinutes) 分钟")
                .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
        }.padding(13)
    }
}
