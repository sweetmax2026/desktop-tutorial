import AppKit

// Compare the selected visual and a native CUA capture at the same logical density.
guard CommandLine.arguments.count == 4,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let implementation = NSImage(contentsOfFile: CommandLine.arguments[2]) else {
    fatalError("Usage: compare-focus.swift reference capture output")
}
let canvas = NSImage(size: NSSize(width: 1600, height: 600))
canvas.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
source.draw(in: NSRect(x: 0, y: 0, width: 800, height: 600))
implementation.draw(in: NSRect(x: 800, y: 0, width: 800, height: 600))
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot render comparison") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
