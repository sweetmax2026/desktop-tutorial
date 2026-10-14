import SwiftUI

struct FocusCat: View {
    var size: CGFloat = 48
    var asset: String = "pangpang-head-v1"
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: asset, withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else { Image(systemName: "cat.fill").resizable().scaledToFit() }
        }
        .frame(width: size, height: size)
    }
}

struct CompactFocusCard: View {
    @ObservedObject var store: PomodoroStore
    let onOpen: () -> Void
    let onHide: () -> Void
    private var tint: Color { FocusTheme.accent }
    var body: some View {
        HStack(spacing: 9) {
            Button(action: onOpen) { FocusCat(size: 34) }.buttonStyle(.plain).help("打开沉浸专注")
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.phase == .readyForFocus ? "准备好下一轮了吗？" : store.phaseTitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Text(store.remainingText() ?? "开始下一轮")
                        .font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit().fixedSize()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.12))
                            Capsule().fill(tint.opacity(0.7)).frame(width: geometry.size.width * store.progress)
                        }
                    }.frame(width: 92, height: 4)
                }
                .frame(width: 98, alignment: .leading)
            }.buttonStyle(.plain)
            Button {
                if store.canPause { store.togglePause() } else { store.startFocus() }
            } label: {
                Image(systemName: store.isPaused || !store.canPause ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())
            }.buttonStyle(.plain).help(store.isPaused ? "继续" : store.canPause ? "暂停" : "开始下一轮")
            Button(action: onHide) { Image(systemName: "xmark").font(.system(size: 10)).frame(width: 20, height: 28) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("本轮暂时收起；长期关闭可在菜单栏设置")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.96, green: 0.98, blue: 1)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.2)))
        .padding(6).frame(width: 264, height: 92)
    }
}

struct FocusExperienceView: View {
    @ObservedObject var store: PomodoroStore
    var appBlocker: AppBlockerStore
    let onBack: () -> Void
    let onClose: () -> Void
    let onHistory: () -> Void
    var editLatestNote = false
    @State private var showsTask = false
    @State private var showsSettings = false
    @State private var showsNote = false
    @State private var note = ""
    @State private var noteRecordID: UUID?
    private let ink = FocusTheme.ink
    private var isBreak: Bool { store.isRestSession }
    private var actionColor: Color {
        FocusTheme.accent
    }
    private var actionTitle: String {
        if store.canPause { return store.isPaused ? "继续计时" : "暂停一下" }
        return store.phase == .readyForFocus ? "开始下一轮" : "开始专注"
    }
    private var taskTitle: String {
        let task = store.canPause ? store.activeTask : store.draftTask
        return task.isEmpty ? (store.canPause ? store.activeCategory : store.draftCategory) : task
    }

    var body: some View {
        Group {
            if showsSettings {
                FocusSettingsView(store: store, appBlocker: appBlocker, returnTitle: "返回沉浸专注") {
                    withAnimation(.easeInOut(duration: 0.16)) { showsSettings = false }
                }.transition(.opacity)
            } else {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                FocusTheme.background
                header.padding(.horizontal, 30).padding(.top, 36)
                VStack(spacing: 0) {
                    Text(store.canPause ? store.phaseTitle : "")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.85)).frame(height: 24)
                    Text(store.remainingText() ?? store.configuredFocusText)
                        .font(.system(size: 92, weight: .semibold, design: .rounded))
                        .monospacedDigit().tracking(-3).fixedSize().frame(height: 112)
                        .accessibilityLabel("剩余时间 \(store.remainingText() ?? store.configuredFocusText)")
                    Button { showsTask = true } label: {
                        HStack(spacing: 7) {
                            Text(isBreak ? "休息一下" : taskTitle).lineLimit(1)
                            if !store.canPause { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)) }
                        }.font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: 360).frame(height: 32).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(store.canPause)
                        .popover(isPresented: $showsTask, arrowEdge: .bottom) { taskEditor }
                    Button {
                        if store.canPause { store.togglePause() } else { store.startFocus() }
                    } label: {
                        Text(actionTitle).frame(width: 216, height: 62).contentShape(Capsule())
                    }.buttonStyle(FocusPillStyle(fill: actionColor, ink: .white))
                        .padding(.top, 34).accessibilityIdentifier("focus.primary")
                    Group {
                        if store.canEnd {
                            Button(isBreak ? "结束休息" : "结束本轮") { store.endCurrentSession() }
                                .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(ink.opacity(0.85))
                                .frame(width: 100, height: 32).accessibilityIdentifier("focus.end")
                        } else { Color.clear.frame(height: 32) }
                    }.padding(.top, 8)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.445)
                harvestShelf.frame(height: 134)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
            }
        }
        .onAppear { if editLatestNote { openNote() } }
        .onChange(of: store.canPause) { active in if active { showsTask = false } }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) { Label("返回专注", systemImage: "chevron.left").frame(height: 36) }
                .buttonStyle(.plain).font(.system(size: 15, weight: .medium))
            Spacer()
            FocusSettingsButton { withAnimation(.easeInOut(duration: 0.16)) { showsSettings = true } }
        }
    }

    private var taskEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("这轮想做什么？").font(.system(size: 16, weight: .semibold))
            Picker("类别", selection: $store.draftCategory) {
                ForEach(["专注", "工作", "阅读", "学习", "其他"], id: \.self) { Text($0) }
            }
            TextField("写一个小目标（选填）", text: $store.draftTask).textFieldStyle(.roundedBorder)
            HStack {
                Text("不填也可以直接开始。").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("完成") { showsTask = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 330).environment(\.colorScheme, .light)
    }

    private var harvestShelf: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28).fill(FocusTheme.shelf)
                .padding(.bottom, -28)
            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日收获").font(.system(size: 16, weight: .semibold, design: .rounded))
                    HStack(spacing: 8) {
                        ForEach(0..<min(store.focusCountToday, 3), id: \.self) { index in FocusPaw(size: 40).rotationEffect(.degrees(index % 2 == 0 ? -10 : 8)) }
                        if store.focusCountToday == 0 {
                            Text("第一枚猫爪，等你拿下。")
                                .font(.system(size: 13)).foregroundStyle(ink.opacity(0.85))
                        }
                        Text("\(store.focusCountToday) 轮 · \(store.todayMinutes) 分钟")
                            .font(.system(size: 17, weight: .medium, design: .rounded)).fixedSize()
                            .padding(.leading, store.focusCountToday == 0 ? 0 : 8)
                    }.frame(height: 46)
                }
                Spacer(minLength: 16)
                VStack(alignment: .trailing, spacing: 10) {
                    if let record = store.latestCompleted, Calendar.current.isDateInToday(record.endedAt) {
                        Button { openNote() } label: { Label("记成果", systemImage: "square.and.pencil") }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ink.opacity(0.85))
                    }
                    Button(action: onHistory) {
                        HStack(spacing: 10) {
                            Text("查看记录")
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }.font(.system(size: 15, weight: .medium)).frame(height: 36)
                    }.buttonStyle(.plain)
                }.padding(.bottom, 4)
                    .popover(isPresented: $showsNote, arrowEdge: .top) { noteEditor }
            }.padding(.horizontal, 50).padding(.top, 24).padding(.bottom, 22)
        }.clipped()
            .overlay(alignment: .topTrailing) {
                // The companion straddles the shelf, but never covers a control.
                FocusCat(size: 116).padding(.trailing, 48).offset(y: -70)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
    }

    private func openNote() {
        guard let record = store.latestCompleted else { return }
        note = record.note
        noteRecordID = record.id
        showsNote = true
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
        }.padding(20).frame(width: 330).environment(\.colorScheme, .light)
    }
}

struct FocusPaw: View {
    let size: CGFloat
    var body: some View {
        if let url = Bundle.main.url(forResource: "focus-paw-simple-v1", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

struct FocusPillStyle: ButtonStyle {
    let fill: Color
    let ink: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .foregroundStyle(ink)
            .background(LinearGradient(colors: [fill, fill.opacity(configuration.isPressed ? 0.75 : 0.88)],
                startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: fill.opacity(0.25), radius: configuration.isPressed ? 3 : 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TodayHarvestView: View {
    @ObservedObject var store: PomodoroStore
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("今日收获").font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text("\(store.focusCountToday) 轮 · \(store.todayMinutes) 分钟").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if store.focusCountToday == 0 {
                Text("第一枚猫爪，等你拿下。").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                    ForEach(0..<min(store.focusCountToday, 32), id: \.self) { _ in
                        FocusPaw(size: 28)
                    }
                }
                if store.focusCountToday > 32 { Text("还有 \(store.focusCountToday - 32) 枚猫爪").font(.caption) }
            }
        }.padding(13).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct FocusCompletionView: View {
    @ObservedObject var store: PomodoroStore
    let record: FocusRecord
    let onNote: () -> Void
    @State private var stamped = false
    var body: some View {
        HStack(spacing: 14) {
            FocusPaw(size: 48)
                .rotationEffect(.degrees(stamped ? -8 : -22)).scaleEffect(stamped ? 1 : 0.4)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: stamped)
            VStack(alignment: .leading, spacing: 6) {
                Text("这一轮，拿下了。").font(.system(size: 17, weight: .bold, design: .rounded))
                Text("\(Int(record.seconds / 60)) 分钟 · 今日 \(store.focusCountToday) 轮").font(.system(size: 12))
                Text("休息一下，下一枚猫爪等你。").font(.system(size: 11)).foregroundStyle(.secondary)
                Button("记下这轮成果") { onNote() }.buttonStyle(HintButtonStyle(primary: true))
            }
        }.padding(20).frame(width: 340, height: 156)
        .background(FocusTheme.shelf, in: RoundedRectangle(cornerRadius: 24))
        .padding(8).onAppear { stamped = true }
    }
}

struct FocusHistoryView: View {
    let records: [FocusRecord]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("专注时间轴").font(.system(size: 15, weight: .semibold, design: .rounded))
            if records.isEmpty { Text("这个时间范围还没有专注记录。").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(Dictionary(grouping: records, by: \.category).keys.sorted()), id: \.self) { category in
                let minutes = Int(records.filter { $0.category == category }.reduce(0) { $0 + $1.seconds } / 60)
                HStack {
                    Text(category).frame(width: 48, alignment: .leading)
                    ProgressView(value: Double(minutes), total: Double(max(1, Int(records.reduce(0) { $0 + $1.seconds } / 60)))).tint(.pink)
                    Text("\(minutes) 分钟").monospacedDigit()
                }.font(.system(size: 11))
            }
            ForEach(records.sorted { $0.endedAt > $1.endedAt }) { record in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: record.completed ? "pawprint.fill" : "circle.dashed").foregroundStyle(record.completed ? .pink : .secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.task.isEmpty ? record.category : record.task).font(.system(size: 13, weight: .semibold))
                        Text("\(record.startedAt.formatted(date: .abbreviated, time: .shortened)) → \(record.endedAt.formatted(date: .omitted, time: .shortened)) · \(Int(record.seconds / 60)) 分钟\(record.completed ? "" : " · 提前结束")")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        if record.estimated { Text("旧记录：时段按 25 分钟估算").font(.system(size: 10)).foregroundStyle(.secondary) }
                        if !record.note.isEmpty { Text(record.note).font(.system(size: 12)) }
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
