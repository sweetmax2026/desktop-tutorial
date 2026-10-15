import AppKit

// Normalize selected board panels and native 2x captures to 800x600 each.
let args = CommandLine.arguments
guard args.count == 5,
      let source = NSImage(contentsOfFile: args[1]),
      let implementation = NSImage(contentsOfFile: args[2]),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("source implementation state output") }
let crops: [String: CGRect] = [
    "ready": CGRect(x: 113, y: 85, width: 596, height: 404),
    "running": CGRect(x: 792, y: 85, width: 597, height: 404),
    "completed": CGRect(x: 37, y: 594, width: 435, height: 328),
    "abandoned": CGRect(x: 535, y: 594, width: 428, height: 328),
    "rest": CGRect(x: 1037, y: 594, width: 428, height: 328)
]
guard let rect = crops[args[3]], let crop = cg.cropping(to: rect) else { fatalError("unknown state") }
let canvas = NSImage(size: NSSize(width: 1600, height: 600))
canvas.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1600, height: 600).fill()
NSGraphicsContext.current?.imageInterpolation = .high
NSImage(cgImage: crop, size: rect.size).draw(in: NSRect(x: 0, y: 0, width: 800, height: 600))
implementation.draw(in: NSRect(x: 800, y: 0, width: 800, height: 600))
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("comparison render") }
try png.write(to: URL(fileURLWithPath: args[4]))
