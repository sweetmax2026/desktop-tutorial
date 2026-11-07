import AppKit
import SwiftUI

// Renders only our own disposable test view, with no system notifications or real app guard.
@main @MainActor enum AutomaticCycleRender {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let suite = "pangpang.test.cycle-render.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var clock = Date()
        let store = PomodoroStore(defaults: defaults, now: { clock }, schedulesTimer: false)
        let blocker = AppBlockerStore(defaults: defaults, monitorsApplications: false)
        let wellbeing = WellbeingStore(defaults: defaults, schedulesTimer: false)
        store.saveUnifiedTask(name: "工作", focusMinutes: 25, presets: store.taskPresets)
        var settings = store.settings
        settings.autoStartBreak = true; settings.autoStartFocus = true
        store.updateSettings(settings)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 800, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let root = FocusFlowScreen(store: store, appBlocker: blocker, onTool: { _ in }, onHistory: {})
            .environment(\.colorScheme, .light).environmentObject(wellbeing)
        let view = NSHostingView(rootView: root)
        view.sizingOptions = []
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        window.contentView = view
        window.orderFront(nil)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func capture(_ name: String) throws {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No render surface") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode render") }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        try capture("ready-enabled")
        store.toggleAutomaticCycle()
        try capture("ready-disabled")
        store.toggleAutomaticCycle()
        store.startFocus()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        try capture("running-enabled")
        store.toggleAutomaticCycle()
        try capture("running-disabled")
        store.toggleAutomaticCycle()
        clock = store.endDate!; store.refreshForCurrentTime()
        try capture("rest-enabled")
        store.toggleAutomaticCycle()
        try capture("rest-disabled")
        // Render the same bubble component used by the real overlay, without faking a mouse event.
        let tooltipView = NSHostingView(rootView: AutomaticCycleTooltip(text: store.automaticCycleHelp)
            .padding(24).frame(width: 320, height: 160, alignment: .topLeading))
        tooltipView.sizingOptions = []
        tooltipView.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
        window.contentView = tooltipView
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        tooltipView.layoutSubtreeIfNeeded()
        let tooltipBitmap = tooltipView.bitmapImageRepForCachingDisplay(in: tooltipView.bounds)!
        tooltipView.cacheDisplay(in: tooltipView.bounds, to: tooltipBitmap)
        try tooltipBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("tooltip-disabled.png"))
        store.toggleAutomaticCycle()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        // The root component has value text; replace it to render the enabled copy.
        tooltipView.rootView = AutomaticCycleTooltip(text: store.automaticCycleHelp)
            .padding(24).frame(width: 320, height: 160, alignment: .topLeading)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        tooltipView.layoutSubtreeIfNeeded()
        let enabledBitmap = tooltipView.bitmapImageRepForCachingDisplay(in: tooltipView.bounds)!
        tooltipView.cacheDisplay(in: tooltipView.bounds, to: enabledBitmap)
        try enabledBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("tooltip-enabled.png"))
        for (section, filename) in [(SettingsSection.feedback, "settings-feedback"), (.updates, "settings-updates")] {
            let supportView = NSHostingView(rootView: FocusSettingsView(
                store: store, appBlocker: blocker, initialSection: section, onClose: {})
                .environment(\.colorScheme, .light).environmentObject(wellbeing))
            supportView.sizingOptions = []
            supportView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
            window.contentView = supportView
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            supportView.layoutSubtreeIfNeeded()
            let bitmap = supportView.bitmapImageRepForCachingDisplay(in: supportView.bounds)!
            supportView.cacheDisplay(in: supportView.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename + ".png"))
        }
        window.orderOut(nil)
        print("Rendered disposable native views at 800x600.")
    }
}
