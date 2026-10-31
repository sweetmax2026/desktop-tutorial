import AppKit
import SwiftUI

private final class StatisticsHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) { super.init(rootView: rootView); sizingOptions = [] }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
}

/// Dedicated preview bundle and disposable focus domain: all records are fixtures.
@main @MainActor
enum StatisticsSurfacePreview {
    static var delegate: StatisticsPreviewDelegate?
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        delegate = StatisticsPreviewDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class StatisticsPreviewDelegate: NSObject, NSApplicationDelegate {
    private let suite = "pangpang.test.statistics.\(UUID().uuidString)"
    private var window: NSWindow!
    private var store: PomodoroStore!
    private var wellbeing: WellbeingStore!
    private var clock = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaults = UserDefaults(suiteName: suite)!
        store = PomodoroStore(defaults: defaults, now: { [unowned self] in clock }, schedulesTimer: false)
        for (dayOffset, rounds) in [1, 2, 3, 1, 2, 1, 3].enumerated() {
            let day = calendar.date(byAdding: .day, value: dayOffset - 6, to: today)!
            for index in 0..<rounds {
                clock = calendar.date(byAdding: .hour, value: [9, 10, 14][index], to: day)!
                store.draftTask = ["阅读一章", "写作", "整理资料"][index]
                store.draftCategory = index == 0 ? "学习" : "工作"
                store.startFocus()
                clock = clock.addingTimeInterval(1500)
                store.refreshForCurrentTime()
                if let record = store.latestCompleted { store.updateNote(id: record.id, note: "完成了本轮计划，记下三个要点。") }
                store.resetToReady()
            }
        }
        let meditations = (0..<5).map { calendar.date(byAdding: .day, value: -$0, to: today)!.addingTimeInterval(11 * 3600) }
        let moods = (0..<4).map { index in
            MoodEntry(id: UUID(), createdAt: calendar.date(byAdding: .day, value: -index, to: today)!.addingTimeInterval(10 * 3600),
                      emoji: "", name: index == 0 ? "还不错" : "很平静", note: "今天给自己留了一段安静的时间。")
        }
        UserDefaults.standard.register(defaults: [
            "pangpang.meditation.times": try! JSONEncoder().encode([MeditationTime]()),
            "pangpang.meditation.completions": try! JSONEncoder().encode(meditations),
            "pangpang.mood.entries": try! JSONEncoder().encode(moods)
        ])
        wellbeing = WellbeingStore()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.minSize = NSSize(width: 800, height: 600)
        window.title = "Pāng 大师 · 统计设计预览（示例数据）"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        showStatistics()
        let menu = NSMenu()
        let application = NSMenuItem()
        application.submenu = NSMenu()
        application.submenu!.addItem(withTitle: "退出统计预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(application)
        let previews = NSMenuItem(title: "预览", action: nil, keyEquivalent: "")
        previews.submenu = NSMenu(title: "预览")
        for (title, action, key) in [("标准 800×600", #selector(standardSize), "1"),
                                     ("宽屏 1100×760", #selector(wideSize), "2"),
                                     ("空记录", #selector(emptyRecords), "3"),
                                     ("恢复示例记录", #selector(restoreRecords), "4")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; previews.submenu!.addItem(item)
        }
        menu.addItem(previews)
        NSApp.mainMenu = menu
        standardSize()
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showStatistics(empty: Bool = false) {
        let previewStore = empty ? PomodoroStore(defaults: UserDefaults(suiteName: suite + ".empty")!, schedulesTimer: false) : store!
        let content = StatisticsView(pomodoro: previewStore, wellbeing: wellbeing,
                                     onBack: { [weak self] in self?.showHome() }, onClose: { [weak self] in self?.window.close() },
                                     initialPeriod: .week)
        window.contentView = StatisticsHostingView(rootView: content)
    }
    private func showHome() {
        window.contentView = StatisticsHostingView(rootView:
            VStack(spacing: 24) {
                Text("已返回专注").font(.title)
                Text("独立预览 · 示例数据").foregroundStyle(.secondary)
                Button("回到数据统计") { [weak self] in self?.showStatistics() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity))
    }
    @objc private func standardSize() { window.setFrame(NSRect(origin: window.frame.origin, size: NSSize(width: 800, height: 600)), display: true) }
    @objc private func wideSize() { window.setFrame(NSRect(origin: window.frame.origin, size: NSSize(width: 1100, height: 760)), display: true); window.center() }
    @objc private func emptyRecords() { showStatistics(empty: true) }
    @objc private func restoreRecords() { showStatistics() }
    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        UserDefaults.standard.removePersistentDomain(forName: suite + ".empty")
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
