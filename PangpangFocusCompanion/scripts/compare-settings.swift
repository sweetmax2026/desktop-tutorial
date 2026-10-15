import AppKit

guard CommandLine.arguments.count == 4,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let implementation = NSImage(contentsOfFile: CommandLine.arguments[2]) else {
    fatalError("Usage: compare-settings reference capture output")
}
let canvas = NSImage(size: NSSize(width: 820, height: 500))
canvas.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 820, height: 500).fill()
NSGraphicsContext.current?.imageInterpolation = .high
// Remove the presentation-board margin from the approved panel, then fit without stretching.
let sourceCrop = NSRect(x: 58, y: 52, width: 1066, height: 1228)
func fit(_ image: NSImage, crop: NSRect, x: CGFloat) {
    let scale = min(410 / crop.width, 500 / crop.height)
    let size = NSSize(width: crop.width * scale, height: crop.height * scale)
    image.draw(in: NSRect(x: x + (410-size.width)/2, y: (500-size.height)/2,
                         width: size.width, height: size.height), from: crop,
               operation: .sourceOver, fraction: 1)
}
fit(source, crop: sourceCrop, x: 0)
fit(implementation, crop: NSRect(origin: .zero, size: implementation.size), x: 410)
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot render comparison") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
