import AppKit
guard CommandLine.arguments.count == 4,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let capture = NSImage(contentsOfFile: CommandLine.arguments[2]) else { fatalError("reference capture output") }
let canvas = NSImage(size: NSSize(width: 1600, height: 627))
canvas.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1600, height: 627).fill()
NSGraphicsContext.current?.imageInterpolation = .high
func fit(_ image: NSImage, x: CGFloat) {
    let ratio = min(800 / image.size.width, 627 / image.size.height)
    let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
    image.draw(in: NSRect(x: x, y: 627 - size.height, width: size.width, height: size.height))
}
fit(source, x: 0); fit(capture, x: 800)
canvas.unlockFocus()
let png = NSBitmapImageRep(data: canvas.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
