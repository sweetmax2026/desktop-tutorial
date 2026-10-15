import AppKit
// Normalize the two selected mock screens and two native screenshots to
// equal 800x600 viewports. Keep the original screenshots untouched.
guard CommandLine.arguments.count == 5 else { fatalError("source timing guard output") }
func read(_ path: String) -> CGImage {
    let image = NSImage(contentsOfFile: path)!
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
let source = read(CommandLine.arguments[1])
let timing = read(CommandLine.arguments[2])
let guardPage = read(CommandLine.arguments[3])
let canvas = NSImage(size: NSSize(width: 1600, height: 1200))
canvas.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1600, height: 1200).fill()
NSGraphicsContext.current?.imageInterpolation = .high
let panels = [CGRect(x: 21, y: 22, width: 976, height: 734), CGRect(x: 1024, y: 22, width: 976, height: 734)]
for index in 0..<2 {
    let crop = source.cropping(to: panels[index])!
    NSImage(cgImage: crop, size: NSSize(width: 800, height: 600)).draw(in: NSRect(x: index * 800, y: 600, width: 800, height: 600))
    let actual = [timing, guardPage][index]
    NSImage(cgImage: actual, size: NSSize(width: 800, height: 600)).draw(in: NSRect(x: index * 800, y: 0, width: 800, height: 600))
}
canvas.unlockFocus()
try NSBitmapImageRep(data: canvas.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[4]))
