import AppKit

guard CommandLine.arguments.count == 4,
      let side = Int(CommandLine.arguments[3]),
      let pet = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fputs("Usage: make-icon-foreground.swift <pet.png> <output.png> <side>\n", stderr)
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

// Crop only the transparent margins from the original portrait, then keep the
// full seated silhouette. These bounds match the desktop pet: smaller head,
// visible shoulders, paws, and tail.
let sourceRect = NSRect(
    x: pet.size.width * 0.23,
    y: pet.size.height * 0.08,
    width: pet.size.width * 0.60,
    height: pet.size.height * 0.83
)
let destinationRect = NSRect(
    x: size * 0.18,
    y: size * 0.11,
    width: size * 0.64,
    height: size * 0.78
)
pet.draw(in: destinationRect, from: sourceRect, operation: .sourceOver, fraction: 1)

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
