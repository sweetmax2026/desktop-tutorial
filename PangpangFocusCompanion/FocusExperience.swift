import SwiftUI

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSettings = false
    @State private var showsTask = false
    @State private var showsNote = false
    @State private var note = ""
    @State private var noteRecordID: UUID?
    @State private var rewardLanded = false
    @State private var showsAbandonedFeedback = false
    private var running: Bool { store.phase == .focus }
    private var completed: Bool { store.phase == .completed }
    private var ready: Bool { !running && !completed && !store.isRestSession && !store.isPaused }
    private var taskTitle: String { store.draftTask.isEmpty ? store.draftCategory : store.draftTask }

    var body: some View {
        Group {
            if showsSettings {
                FocusSettingsView(store: store, appBlocker: appBlocker) { showsSettings = false }
            } else {
                GeometryReader { geometry in
                    ZStack {
                        if running { runningBackground.overlay(Color.black.opacity(0.25)) }
                        else if store.isRestSession { runningBackground.opacity(0.22).background(.white) }
                        else { FocusTheme.background }
                        if ready || store.isPaused { header }
                        if running {
                            countdown(size: min(132, geometry.size.width * 0.16), color: .white)
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.49)
                            HoldToAbandon(action: store.endCurrentSession)
                                .frame(width: 210, height: 48)
                                .position(x: geometry.size.width / 2, y: geometry.size.height - 52)
                        } else if completed {
                            completionContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                        } else if store.isPaused {
                            legacyContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
                        } else if store.isRestSession {
                            restContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.47)
                        } else {
                            readyContents
                                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.52)
                        }
                        if ready || store.isRestSession {
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
            showsTask = false
            if phase == .focus { showsSettings = false; showsNote = false; showsAbandonedFeedback = false }
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

    private var readyContents: some View {
        VStack(spacing: 0) {
            Button { showsTask = true } label: {
                Text(store.configuredFocusText)
                    .font(.system(size: 112, weight: .semibold, design: .rounded)).monospacedDigit().tracking(-3)
            }.buttonStyle(.plain).help("调整本轮时长与任务").accessibilityIdentifier("focus.duration")
                .overlay(alignment: .trailing) { resetControl.offset(x: 56) }
            Button { showsTask = true } label: {
                HStack(spacing: 7) {
                    Text(taskTitle).lineLimit(1)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }.font(.system(size: 18, weight: .medium)).frame(maxWidth: 360).frame(height: 32)
            }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary)
                .popover(isPresented: $showsTask) { taskEditor }
            primary("开始专注", id: "focus.start") { store.startFocus() }.padding(.top, 38)
            Group {
                if showsAbandonedFeedback, let record = store.lastAbandonedRecord {
                    Text("本轮已结束，\(elapsed(record.seconds))已记录").font(.system(size: 12))
                        .foregroundStyle(FocusTheme.secondary)
                } else { Text(" ").font(.system(size: 12)) }
            }.frame(height: 24).padding(.top, 10)
        }.fixedSize(horizontal: false, vertical: true)
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
    private var taskEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("这轮想做什么？").font(.system(size: 16, weight: .semibold))
            Stepper("专注 \(store.settings.focusMinutes) 分钟", value: Binding(
                get: { store.settings.focusMinutes },
                set: { var settings = store.settings; settings.focusMinutes = $0; store.updateSettings(settings) }), in: 1...180)
            Picker("类别", selection: $store.draftCategory) {
                ForEach(["专注", "工作", "阅读", "学习", "其他"], id: \.self) { Text($0) }
            }
            TextField("写一个小目标（选填）", text: $store.draftTask).textFieldStyle(.roundedBorder)
                .onChange(of: store.draftTask) { value in if value.count > 80 { store.draftTask = String(value.prefix(80)) } }
            HStack { Spacer(); Button("完成") { showsTask = false }.keyboardShortcut(.defaultAction) }
        }.padding(22).frame(width: 330)
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
