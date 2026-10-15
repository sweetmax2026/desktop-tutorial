import AppKit
import SwiftUI

enum PangpangPalette {
    static let petBackground = Color(red: 0.66, green: 0.83, blue: 0.94)
    static let petEdge = Color(red: 0.48, green: 0.69, blue: 0.83)
    static let blush = Color(red: 1.0, green: 0.78, blue: 0.83)
    static let ink = Color(red: 0.20, green: 0.24, blue: 0.31)
}

struct PangpangPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .circular)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.99, blue: 1.0),
                        Color(red: 0.91, green: 0.96, blue: 0.99),
                        Color(red: 1.0, green: 0.94, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct PangpangCardBackground: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.80), tint.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(.white.opacity(0.75), lineWidth: 1))
    }
}

enum PetActivity {
    case focus
    case rest
    case paused
    case guarding
}

struct FloatingPetButton: View {
    let phase: PomodoroPhase
    let onTap: () -> Void
    let onDrag: () -> Void
    let onStartFocus: () -> Void
    let onHide: () -> Void
    let onQuit: () -> Void
    @State private var isBlinking = false

    var body: some View {
        ZStack {
            Circle().fill(PangpangPalette.petBackground)
            Image(nsImage: petImage).resizable().scaledToFit().frame(width: 48, height: 48)
                .scaleEffect(y: isBlinking ? 0.985 : 1)
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(PangpangPalette.petEdge, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
        .overlay(
            PetInteractionOverlay(
                onTap: onTap,
                onDrag: onDrag,
                onDragEnded: savePanelPosition,
                onStartFocus: onStartFocus,
                onHide: onHide,
                onQuit: onQuit
            )
            .frame(width: 68, height: 68)
        )
        .padding(9)
        .accessibilityLabel(AppBrand.name)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...7)))
                isBlinking = true
                try? await Task.sleep(for: .milliseconds(130))
                isBlinking = false
            }
        }
    }

    private var petImage: NSImage {
        guard let url = Bundle.main.url(forResource: "pangpang-head-v1", withExtension: "png"), let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "cat.fill", accessibilityDescription: AppBrand.name) ?? NSImage()
        }
        return image
    }

    private func savePanelPosition() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.frame.size == NSSize(width: 86, height: 86) }) else { return }
        UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: "pangpang.pet.origin")
    }
}

struct FloatingPetVisual: View {
    let activity: PetActivity?
    @State private var isBlinking = false

    var body: some View {
        ZStack {
            Circle().fill(catGradient)
            Image(nsImage: petImage).resizable().scaledToFit().frame(width: 48, height: 48)
                .scaleEffect(y: isBlinking ? 0.985 : 1)
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ringGradient, lineWidth: activity == nil ? 1.5 : 2))
        .shadow(color: accent.opacity(activity == nil ? 0.12 : 0.26), radius: activity == nil ? 5 : 7, y: 3)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...7)))
                isBlinking = true
                try? await Task.sleep(for: .milliseconds(130))
                isBlinking = false
            }
        }
    }

    private var petImage: NSImage {
        guard let url = Bundle.main.url(forResource: "pangpang-head-v1", withExtension: "png"), let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "cat.fill", accessibilityDescription: AppBrand.name) ?? NSImage()
        }
        return image
    }

    private var accent: Color { activity.map(activityAccent) ?? PangpangPalette.petEdge }
    private var catGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.72, green: 0.88, blue: 0.97), Color(red: 0.78, green: 0.83, blue: 0.98), activity.map(activityAccent).map { $0.opacity(0.20) } ?? PangpangPalette.petBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var ringGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.41, green: 0.69, blue: 0.88), accent, Color(red: 0.94, green: 0.52, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct PetStripView: View {
    let activity: PetActivity?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FloatingPetVisual(activity: activity)
                .frame(width: 86, height: 86, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let activity {
                PetActivityBadge(activity: activity)
                    .padding(.top, 9)
                    .padding(.trailing, 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.82, anchor: .leading)))
            }
        }
        .frame(width: activity == nil ? 86 : 138, height: 86, alignment: .leading)
        .offset(x: activity == nil ? 0 : 8)
        .frame(width: activity == nil ? 86 : 154, height: 86, alignment: .leading)
        .animation(.easeOut(duration: 0.22), value: activityLabel)
    }

    private var activityLabel: String { activity.map(PetActivityBadge.label(for:)) ?? "" }
}

private struct PetActivityBadge: View {
    let activity: PetActivity

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text(Self.label(for: activity))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(badgeInk)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(badgeGradient, in: Capsule())
        .overlay(Capsule().strokeBorder(badgeBorderGradient, lineWidth: 1))
        .shadow(color: .white.opacity(0.14), radius: 1)
        .shadow(color: tint.opacity(0.42), radius: 6, y: 2)
        .accessibilityLabel(Self.label(for: activity))
    }

    static func label(for activity: PetActivity) -> String {
        switch activity {
        case .focus: return "专注"
        case .rest: return "休息"
        case .paused: return "暂停"
        case .guarding: return "专注守护"
        }
    }

    private var symbol: String {
        switch activity {
        case .focus: return "sparkles"
        case .rest: return "cup.and.saucer.fill"
        case .paused: return "moon.zzz.fill"
        case .guarding: return "lock.fill"
        }
    }

    private var tint: Color {
        activityAccent(activity)
    }

    private var badgeInk: Color {
        switch activity {
        case .focus: return Color(red: 0.70, green: 0.20, blue: 0.29)
        case .rest: return Color(red: 0.22, green: 0.43, blue: 0.64)
        case .paused: return Color(red: 0.30, green: 0.31, blue: 0.38)
        case .guarding: return Color(red: 0.32, green: 0.26, blue: 0.64)
        }
    }

    private var badgeGradient: LinearGradient {
        let colors: [Color]
        switch activity {
        case .focus:
            colors = [Color(red: 1.0, green: 0.88, blue: 0.92), Color(red: 1.0, green: 0.79, blue: 0.85), Color(red: 0.87, green: 0.90, blue: 1.0)]
        case .rest:
            colors = [Color(red: 0.91, green: 0.97, blue: 1.0), Color(red: 0.77, green: 0.90, blue: 1.0), Color(red: 0.91, green: 0.87, blue: 1.0)]
        case .paused:
            colors = [Color(red: 0.96, green: 0.96, blue: 0.99), Color(red: 0.85, green: 0.87, blue: 0.93), Color(red: 0.95, green: 0.90, blue: 0.97)]
        case .guarding:
            colors = [Color(red: 1.0, green: 0.86, blue: 0.92), Color(red: 0.89, green: 0.83, blue: 1.0), Color(red: 0.80, green: 0.90, blue: 1.0)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var badgeBorderGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.96, green: 0.58, blue: 0.69), tint, Color(red: 0.52, green: 0.64, blue: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func activityAccent(_ activity: PetActivity) -> Color {
    switch activity {
    case .focus: return Color(red: 0.91, green: 0.39, blue: 0.48)
    case .rest: return Color(red: 0.33, green: 0.62, blue: 0.85)
    case .paused: return Color(red: 0.45, green: 0.47, blue: 0.54)
    case .guarding: return Color(red: 0.48, green: 0.45, blue: 0.82)
    }
}

final class PetContentView: NSView {
    init(frame frameRect: NSRect, activity: PetActivity?, onTap: @escaping () -> Void, onDragChanged: @escaping () -> Void, onDragEnded: @escaping () -> Void) {
        super.init(frame: frameRect)
        let button = PetButton(frame: NSRect(x: 0, y: 0, width: 86, height: 86))
        button.autoresizingMask = [.height]
        button.onTap = onTap
        button.onDragChanged = onDragChanged
        button.onDragEnded = onDragEnded
        addSubview(button)

        // Draw the gradient badge above the interaction layer, while passing all
        // pointer events through to the pet button underneath.
        let visual = PassthroughHostingView(rootView: PetStripView(activity: activity))
        visual.frame = bounds
        visual.autoresizingMask = [.width, .height]
        addSubview(visual)
    }

    required init?(coder: NSCoder) { nil }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class PetButton: NSButton {
    var onTap: (() -> Void)?
    var onDragChanged: (() -> Void)?
    var onDragEnded: (() -> Void)?
    private var mouseDownLocation: NSPoint?
    private var windowOriginAtMouseDown: NSPoint?
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityLabel(AppBrand.name)
        target = self
        action = #selector(pressed)
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func pressed() { onTap?() }
    override func accessibilityPerformPress() -> Bool {
        onTap?()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin
        isDragging = false
        highlight(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startMouse = mouseDownLocation, let startOrigin = windowOriginAtMouseDown, let window else { return }
        let mouse = NSEvent.mouseLocation
        let delta = NSSize(width: mouse.x - startMouse.x, height: mouse.y - startMouse.y)
        guard abs(delta.width) > 4 || abs(delta.height) > 4 else { return }
        isDragging = true
        highlight(false)
        window.setFrameOrigin(NSPoint(x: startOrigin.x + delta.width, y: startOrigin.y + delta.height))
        onDragChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        highlight(false)
        defer { mouseDownLocation = nil; windowOriginAtMouseDown = nil; isDragging = false }
        if isDragging { onDragEnded?() } else { onTap?() }
    }
}

private struct PetInteractionOverlay: NSViewRepresentable {
    let onTap: () -> Void
    let onDrag: () -> Void
    let onDragEnded: () -> Void
    let onStartFocus: () -> Void
    let onHide: () -> Void
    let onQuit: () -> Void

    func makeNSView(context: Context) -> PetInteractionView {
        let view = PetInteractionView()
        view.configure(
            onTap: onTap,
            onDrag: onDrag,
            onDragEnded: onDragEnded,
            onStartFocus: onStartFocus,
            onHide: onHide,
            onQuit: onQuit
        )
        return view
    }

    func updateNSView(_ view: PetInteractionView, context: Context) {
        view.configure(
            onTap: onTap,
            onDrag: onDrag,
            onDragEnded: onDragEnded,
            onStartFocus: onStartFocus,
            onHide: onHide,
            onQuit: onQuit
        )
    }
}

private final class PetInteractionView: NSView {
    private var initialMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?
    private var hasDragged = false
    private var onTap: () -> Void = {}
    private var onDrag: () -> Void = {}
    private var onDragEnded: () -> Void = {}
    private var onStartFocus: () -> Void = {}
    private var onHide: () -> Void = {}
    private var onQuit: () -> Void = {}

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }

    func configure(onTap: @escaping () -> Void, onDrag: @escaping () -> Void, onDragEnded: @escaping () -> Void, onStartFocus: @escaping () -> Void, onHide: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onTap = onTap
        self.onDrag = onDrag
        self.onDragEnded = onDragEnded
        self.onStartFocus = onStartFocus
        self.onHide = onHide
        self.onQuit = onQuit
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
        hasDragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startMouse = initialMouseLocation, let startOrigin = initialWindowOrigin, let window else { return }
        let mouse = NSEvent.mouseLocation
        let delta = NSSize(width: mouse.x - startMouse.x, height: mouse.y - startMouse.y)
        hasDragged = abs(delta.width) > 2 || abs(delta.height) > 2
        window.setFrameOrigin(NSPoint(x: startOrigin.x + delta.width, y: startOrigin.y + delta.height))
        onDrag()
    }

    override func mouseUp(with event: NSEvent) {
        if hasDragged { onDragEnded() } else { onTap() }
        initialMouseLocation = nil
        initialWindowOrigin = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let start = menu.addItem(withTitle: "开始专注", action: #selector(startFocus), keyEquivalent: "")
        start.target = self
        let hide = menu.addItem(withTitle: "隐藏桌面入口", action: #selector(hidePet), keyEquivalent: "")
        hide.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 \(AppBrand.name)", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func startFocus() { onStartFocus() }
    @objc private func hidePet() { onHide() }
    @objc private func quit() { onQuit() }
}

enum ToolboxTool { case home, pomodoro, meditation, mood, appBlocker }

struct ToolboxView: View {
    @ObservedObject var pomodoro: PomodoroStore
    @ObservedObject var wellbeing: WellbeingStore
    @ObservedObject var appBlocker: AppBlockerStore
    @State private var selectedTool: ToolboxTool
    @State private var draftMeditationTime = Date()
    @State private var savedMoodName: String?
    @State private var selectedMood: MoodOption?
    @State private var moodNote = ""
    let onToolChanged: (ToolboxTool) -> Void
    let onShowStatistics: () -> Void
    let onClose: () -> Void

    init(pomodoro: PomodoroStore, wellbeing: WellbeingStore, appBlocker: AppBlockerStore, initialTool: ToolboxTool, onToolChanged: @escaping (ToolboxTool) -> Void, onShowStatistics: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.pomodoro = pomodoro
        self.wellbeing = wellbeing
        self.appBlocker = appBlocker
        _selectedTool = State(initialValue: initialTool)
        self.onToolChanged = onToolChanged
        self.onShowStatistics = onShowStatistics
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            FocusTheme.background.clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 18)
            VStack(alignment: .leading, spacing: selectedTool == .home ? 11 : 15) {
                HStack(spacing: 9) {
                    if selectedTool != .home {
                        Button { select(.home) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PangpangPalette.petEdge)
                            .frame(width: 26, height: 26)
                            .background(.white.opacity(0.68), in: Circle())
                    }
                    Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.46), in: Circle())
                }
                Group {
                    switch selectedTool {
                    case .home: home
                    case .pomodoro: pomodoroDetail
                    case .meditation: meditationDetail
                    case .mood: moodDetail
                    case .appBlocker: appBlockerDetail
                    }
                }
            }
            .padding(.horizontal, 33)
            .padding(.top, selectedTool == .home ? 27 : 33)
            .padding(.bottom, selectedTool == .home ? 29 : 41)
        }
        .frame(width: 390, height: 510, alignment: .topLeading)
    }

    private var title: String {
        switch selectedTool {
        case .home: return AppBrand.wordmark
        case .pomodoro: return "番茄钟"
        case .meditation: return "1 分钟冥想"
        case .mood: return "1 分钟情绪记录"
        case .appBlocker: return "App 管控"
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    TodayHarvestView(store: pomodoro)
                    statusCard
                    HStack(spacing: 9) {
                        quickAction(icon: "play.fill", title: "专注", tint: .red) { select(.pomodoro) }
                        quickAction(icon: "wind", title: "冥想", tint: .blue) { wellbeing.startMeditation(); select(.meditation) }
                        quickAction(icon: "face.smiling", title: "记录", tint: .orange) { select(.mood) }
                    }
                    VStack(spacing: 0) {
                        toolRow(icon: "timer", title: "番茄钟", detail: "今天 \(pomodoro.focusCountToday) 轮", tint: .red) { select(.pomodoro) }
                        Divider().padding(.leading, 43)
                        toolRow(icon: "wind", title: "1 分钟冥想", detail: "今天 \(wellbeing.meditationCountToday) 次", tint: .blue) { select(.meditation) }
                        Divider().padding(.leading, 43)
                        toolRow(icon: "face.smiling", title: "情绪记录", detail: wellbeing.moodCountToday() == 0 ? "今天还没有记录" : "今天 \(wellbeing.moodCountToday()) 条", tint: .orange) { select(.mood) }
                        Divider().padding(.leading, 43)
                        toolRow(icon: appBlocker.isEnabled ? "lock.fill" : "lock.open", title: "App 管控", detail: appBlocker.statusText, tint: .purple) { select(.appBlocker) }
                    }
                    .background(PangpangCardBackground(tint: PangpangPalette.petBackground))
                }
            }
            Button(action: onShowStatistics) {
                Label("数据详情", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            Text("数据仅保存在这台 Mac 上。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: pomodoro.canPause ? "timer" : "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(pomodoro.canPause ? .red : .secondary)
                .frame(width: 36, height: 36)
                .background((pomodoro.canPause ? Color.red : Color.secondary).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(ongoingTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(pomodoro.remainingText().map { "剩余 \($0)" } ?? "\(AppBrand.name) 不会催你，只会记得。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if pomodoro.canPause {
                Button {
                    pomodoro.togglePause()
                } label: {
                    Image(systemName: pomodoro.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(PangpangPalette.petEdge)
                .background(.white.opacity(0.68), in: Circle())
                .overlay(Circle().strokeBorder(PangpangPalette.petEdge.opacity(0.24), lineWidth: 1))
                .accessibilityLabel(pomodoro.isPaused ? "继续计时" : "暂停计时")
                .help(pomodoro.isPaused ? "继续计时" : "暂停计时")
            }
        }
        .padding(11)
        .background(PangpangCardBackground(tint: pomodoro.canPause ? .red : PangpangPalette.petBackground))
    }

    private var ongoingTitle: String {
        switch pomodoro.phase {
        case .focus: return "专注中"
        case .shortBreak: return "休息中"
        case .longBreak: return "长休息中"
        case .paused: return "已暂停"
        default: return "现在，照顾一下自己。"
        }
    }

    private func quickAction(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(PangpangCardBackground(tint: tint))
        }
        .buttonStyle(.plain)
    }

    private var pomodoroDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(pomodoro.phaseTitle).font(.system(size: 28, weight: .bold, design: .rounded))
            if let remaining = pomodoro.remainingText() {
                Text(remaining).font(.system(size: 42, weight: .semibold, design: .monospaced)).foregroundStyle(.primary)
            } else {
                Text("\(pomodoro.settings.focusMinutes) 分钟专注 · \(pomodoro.settings.shortBreakMinutes) 分钟休息 · 第 \(pomodoro.settings.longBreakInterval) 轮后 \(pomodoro.settings.longBreakMinutes) 分钟").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 9) {
                Button(pomodoro.primaryActionTitle) { if pomodoro.phase == .idle || pomodoro.phase == .readyForFocus { pomodoro.startFocus() } }
                    .buttonStyle(.borderedProminent).tint(Color(red: 0.76, green: 0.31, blue: 0.27))
                    .disabled(pomodoro.phase != .idle && pomodoro.phase != .readyForFocus)
                if pomodoro.canPause { Button(pomodoro.isPaused ? "继续" : "暂停") { pomodoro.togglePause() }.buttonStyle(.bordered) }
                if pomodoro.canEnd { Button("结束") { pomodoro.endCurrentSession() }.buttonStyle(.bordered) }
            }
            Divider()
            statsLink(todayText: "今天已完成 \(pomodoro.focusCountToday) 轮")
            Spacer()
        }
    }

    private var meditationDetail: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(wellbeing.isMeditating ? "慢慢呼吸。" : "给自己一分钟。")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(wellbeing.meditationRemainingText.map { "剩余 \($0)" } ?? "随时可以开始")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                BreathingFlowerView(
                    isActive: wellbeing.isMeditating,
                    sessionID: wellbeing.meditationSessionID
                )
                Button(wellbeing.isMeditating ? "重新开始 1 分钟" : "开始 1 分钟冥想") { wellbeing.startMeditation() }
                    .buttonStyle(.borderedProminent).tint(.blue)
                    .help(wellbeing.isMeditating ? "从 1:00 重新计时" : "开始 1 分钟冥想")
                Divider()
                statsLink(todayText: "今天完成 \(wellbeing.meditationCountToday) 次")
                Divider()
                Text("每日提醒").font(.system(size: 13, weight: .semibold))
                ForEach(wellbeing.meditationTimes) { time in
                    HStack {
                        Text(time.displayText).font(.system(size: 13))
                        Spacer()
                        Button(role: .destructive) { wellbeing.removeMeditationTime(time) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                    }
                }
                HStack {
                    DatePicker("添加时间", selection: $draftMeditationTime, displayedComponents: .hourAndMinute).labelsHidden()
                    Button("添加") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: draftMeditationTime)
                        wellbeing.addMeditationTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
                    }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var moodDetail: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                Text(savedMoodName.map { "已记下：\($0)" } ?? "此刻感觉怎么样？")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                ForEach(MoodOption.all) { option in
                    Button {
                        selectedMood = option
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.emoji).font(.system(size: 24))
                            Text(option.name).font(.system(size: 10))
                        }
                        .frame(width: 54, height: 60)
                        .background(selectedMood?.id == option.id ? Color.orange.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.bordered)
                }
                    }
                }
                ZStack(alignment: .topLeading) {
                    if moodNote.isEmpty {
                        Text("想补充一点什么吗？（选填）")
                            .font(.system(size: 12)).foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    TextEditor(text: $moodNote)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .onChange(of: moodNote) { newValue in
                            // Do not rewrite each keypress: doing so interrupts spaces and IME composition.
                            if newValue.count > 100 {
                                moodNote = String(newValue.prefix(100))
                            }
                        }
                }
                .frame(height: 72)
                .padding(6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Text("\(moodNote.count)/100").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("保存记录") {
                        let mood = selectedMood ?? MoodOption(emoji: "📝", name: "随手记")
                        wellbeing.recordMood(emoji: mood.emoji, name: mood.name, note: moodNote)
                        savedMoodName = mood.name
                        moodNote = ""
                        self.selectedMood = nil
                    }
                    .buttonStyle(.borderedProminent).tint(.orange)
                    .disabled(selectedMood == nil && moodNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Divider()
                statsLink(todayText: "今天已记录 \(wellbeing.moodCountToday()) 次 · 仅本地保存")
                if let last = wellbeing.moodEntries.first {
                    Text("最近一次：\(last.emoji) \(last.name)\(last.note.map { " · \($0)" } ?? "")")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }

    private var appBlockerDetail: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: appBlocker.isEnabled ? "lock.fill" : "lock.open")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 40, height: 40)
                    .background(Color.purple.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(appBlocker.isBlockingNow ? "\(AppBrand.name) 正在守护" : appBlocker.isEnabled ? "已开启，等待专注" : "需要时再打开")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("打开黑名单 App 时，会立刻隐藏并带你回来。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("App 管控", isOn: Binding(
                    get: { appBlocker.isEnabled },
                    set: { appBlocker.setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.purple)
            }
            .padding(13)
            .background(PangpangCardBackground(tint: .purple))

            HStack {
                Text("黑名单")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    appBlocker.chooseApplications()
                } label: {
                    Label("添加 App", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if appBlocker.blockedApplications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(Color.purple.opacity(0.55))
                    Text("还没有黑名单")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("把容易让你分心的 App 放进来。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(PangpangCardBackground(tint: .purple))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(appBlocker.blockedApplications) { application in
                            HStack(spacing: 11) {
                                Image(nsImage: appBlocker.icon(for: application))
                                    .resizable().scaledToFit().frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(application.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(application.bundleIdentifier)
                                        .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    appBlocker.remove(application)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 15))
                                }
                                .buttonStyle(.plain)
                                .help("移出黑名单")
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            if application.id != appBlocker.blockedApplications.last?.id {
                                Divider().padding(.leading, 53)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(PangpangCardBackground(tint: .purple))
            }

            Text("开关可独立设置，仅在专注计时中生效；休息和暂停期间自动放行。不会强制退出或删除数据。")
                .font(.system(size: 10.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var meditationSummary: String {
        if wellbeing.isMeditating { return wellbeing.meditationRemainingText ?? "进行中" }
        return wellbeing.meditationTimes.map(\.displayText).joined(separator: " · ")
    }

    private func statsLink(todayText: String) -> some View {
        HStack {
            Text(todayText).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Button("数据详情", action: onShowStatistics)
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
        }
    }

    private func toolRow(icon: String, title: String, detail: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(ResponsiveRowButtonStyle())
    }

    private func select(_ tool: ToolboxTool) {
        selectedTool = tool
        onToolChanged(tool)
    }
}

struct BreathingFlowerView: View {
    let isActive: Bool
    let sessionID: UUID
    var largeStyle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var isInhaling = true

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                ForEach(0..<(largeStyle ? 6 : 8), id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: largeStyle ? [Color(red: 0.55, green: 0.70, blue: 1).opacity(0.35), Color(red: 0.40, green: 0.53, blue: 0.97).opacity(0.38)] : [
                                    Color(red: 0.35, green: 0.72, blue: 0.98).opacity(0.82),
                                    Color(red: 0.55, green: 0.55, blue: 0.96).opacity(0.76),
                                    Color(red: 0.98, green: 0.55, blue: 0.72).opacity(0.68)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: largeStyle ? 144 : 52, height: largeStyle ? 144 : 52)
                        .offset(y: largeStyle ? -(isExpanded ? 66 : 30) : -(isExpanded ? 34 : 16))
                        .rotationEffect(.degrees(Double(index) * (largeStyle ? 60 : 45)))
                        .opacity(isActive ? 0.88 : 0.48)
                }

                if !largeStyle { Circle()
                    .fill(.white.opacity(0.72))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "wind")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PangpangPalette.petEdge)
                    }
                    .shadow(color: PangpangPalette.petEdge.opacity(0.18), radius: 6) }
            }
            .frame(width: largeStyle ? 300 : 142, height: largeStyle ? 256 : 142)

            Text(cueText)
                .font(.system(size: largeStyle ? 15 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(PangpangPalette.ink.opacity(0.72))
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background { if !largeStyle { PangpangCardBackground(tint: .blue) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? cueText : "呼吸动画，准备开始")
        .task(id: "\(isActive)-\(sessionID.uuidString)") {
            guard isActive else {
                isInhaling = true
                withAnimation(.easeOut(duration: 0.45)) { isExpanded = false }
                return
            }

            isInhaling = true
            isExpanded = false
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                isExpanded = true
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) { isInhaling.toggle() }
            }
        }
    }

    private var cueText: String {
        if !isActive { return largeStyle ? "跟着花朵，慢慢呼吸" : "准备好后，跟着它呼吸" }
        if reduceMotion { return "慢慢呼吸" }
        return isInhaling ? "吸气" : "呼气"
    }
}

private struct ResponsiveRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 11))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MoodOption: Identifiable {
    let emoji: String
    let name: String
    var id: String { name }
    static let all = [
        MoodOption(emoji: "🙂", name: "平静"),
        MoodOption(emoji: "😊", name: "轻松"),
        MoodOption(emoji: "😐", name: "一般"),
        MoodOption(emoji: "😟", name: "低落"),
        MoodOption(emoji: "😤", name: "烦躁")
    ]
}

struct BubbleView: View {
    static let panelSize = NSSize(width: 352, height: 184)
    let message: BubbleMessage
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: message.symbol).font(.system(size: 34, weight: .medium))
                    .foregroundStyle(FocusTheme.accent).frame(width: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text).font(.system(size: 18, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true).lineLimit(2)
                    Text(message.detail).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FocusTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }.padding(.top, 12).padding(.trailing, 8)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Spacer()
                if let title = message.secondaryTitle {
                    Button(title, action: onDismiss).buttonStyle(HintButtonStyle(primary: false))
                }
                Button(message.actionTitle, action: onAction).buttonStyle(HintButtonStyle(primary: true))
            }
        }
        .padding(20).frame(width: 336, height: 168, alignment: .topLeading)
        .foregroundStyle(FocusTheme.ink)
        .background(LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 1), Color(red: 0.93, green: 0.95, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 28) }
                .buttonStyle(.plain).foregroundStyle(FocusTheme.secondary).padding(8).accessibilityLabel("关闭提示")
        }
        .padding(8)
    }
}

struct HintButtonStyle: ButtonStyle {
    var primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(primary ? .white : FocusTheme.secondary)
            .padding(.horizontal, 18).frame(height: 34)
            .background(primary ? FocusTheme.accent : FocusTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
