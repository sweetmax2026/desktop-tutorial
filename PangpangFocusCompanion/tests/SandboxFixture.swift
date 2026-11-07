import AppKit

// Disposable target for real hide/unhide tests; never target a user's apps.
@main @MainActor enum SandboxFixture {
    static var window: NSWindow!
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 320, height: 100),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Pang Sandbox Test Fixture"
        window.contentView = NSTextField(labelWithString: "专注守护测试窗口，20秒后自动退出")
        window.makeKeyAndOrderFront(nil)
        for delay in [4.0, 10.0, 16.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { app.unhide(nil); window.orderFrontRegardless() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { app.terminate(nil) }
        app.run()
    }
}
