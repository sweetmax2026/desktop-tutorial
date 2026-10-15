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

// Notification Center always wraps an app icon in its own rounded-square tile.
// Keep pangpang transparent here and enlarge her inside the safe area, so the
// system tile is the only visible container instead of a square inside a square.
let sourcePetRect = NSRect(
    x: pet.size.width * 0.23,
    y: pet.size.height * 0.08,
    width: pet.size.width * 0.60,
    height: pet.size.height * 0.83
)
let petRect = NSRect(
    x: size * 0.13,
    y: size * 0.04,
    width: size * 0.74,
    height: size * 0.92
)
NSGraphicsContext.current?.saveGraphicsState()
let petShadow = NSShadow()
petShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
petShadow.shadowBlurRadius = size * 0.018
petShadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
petShadow.set()
pet.draw(in: petRect, from: sourcePetRect, operation: .sourceOver, fraction: 1)
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
