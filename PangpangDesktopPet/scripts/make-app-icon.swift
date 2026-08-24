import AppKit

guard CommandLine.arguments.count == 4,
      let side = Int(CommandLine.arguments[3]),
      let pet = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fputs("Usage: make-app-icon.swift <pet.png> <output.png> <side>\n", stderr)
    exit(1)
}

let size = CGFloat(side)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let inset = size * 0.045
let circleRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
NSColor(calibratedRed: 0.66, green: 0.83, blue: 0.94, alpha: 1).setFill()
NSBezierPath(ovalIn: circleRect).fill()
NSColor(calibratedRed: 0.48, green: 0.69, blue: 0.83, alpha: 1).setStroke()
let border = NSBezierPath(ovalIn: circleRect.insetBy(dx: size * 0.008, dy: size * 0.008))
border.lineWidth = max(1, size * 0.022)
border.stroke()

let petSide = size * 0.78
let petRect = NSRect(x: (size - petSide) / 2, y: (size - petSide) / 2, width: petSide, height: petSide)
pet.draw(in: petRect, from: NSRect(origin: .zero, size: pet.size), operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
