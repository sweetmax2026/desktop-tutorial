import AppKit
import SwiftUI

@main
@MainActor
enum HintSurfacePreview {
    static var window: NSWindow!
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 768, height: 512), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: HintBoard())
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

struct HintBoard: View {
    @State private var result = ""
    var body: some View {
        ZStack {
            FocusTheme.background
            VStack(spacing: 64) {
                HStack(spacing: 2) {
                    BubbleView(message: BubbleMessage(text: "SeaTalk 已暂时隐藏", actionTitle: "知道了", action: .dismiss, detail: "休息或暂停时可正常使用。"), onAction: { result = "已关闭守护提示" }, onDismiss: { result = "已关闭守护提示" })
                    BubbleView(message: BubbleMessage(text: "留一分钟，回来呼吸", actionTitle: "开始冥想", action: .startMeditation, detail: "和 \(AppBrand.name) 一起，慢慢吸气、呼气。", symbol: "leaf.fill"), onAction: { result = "已请求开始冥想" }, onDismiss: { result = "已略过冥想" })
                }
                HStack(spacing: 16) {
                    Text("今日收获").font(.system(size: 18, weight: .bold))
                    HStack(spacing: 8) { FocusPaw(size: 44).rotationEffect(.degrees(-10)); FocusPaw(size: 44).rotationEffect(.degrees(8)) }
                    Text("2 轮 · 50 分钟").font(.system(size: 15, weight: .semibold)).foregroundStyle(FocusTheme.secondary)
                    Spacer()
                    Button("查看记录  ›") { result = "已请求查看记录" }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary)
                }.padding(.horizontal, 30).frame(width: 688, height: 74)
                    .background(FocusTheme.shelf, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(alignment: .topTrailing) { FocusCat(size: 100, asset: "pangpang-home-peek-v1").offset(y: -94).padding(.trailing, 6) }
            }.padding(.top, 14)
            Text(result).font(.caption).offset(y: 218).accessibilityIdentifier("preview.result")
        }.foregroundStyle(FocusTheme.ink).frame(width: 768, height: 512).environment(\.colorScheme, .light)
    }
}
