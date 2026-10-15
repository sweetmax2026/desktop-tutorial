import AppKit

// Some multi-display CUA captures contain a 1x window in a 2x white canvas.
// Normalize that observed top-left window region without rescaling its content.
guard CommandLine.arguments.count == 3,
      let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let bitmap = NSBitmapImageRep(data: data), let source = bitmap.cgImage,
      let crop = source.cropping(to: CGRect(x: 0, y: 0, width: 800, height: 600)),
      let png = NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:]) else {
    fatalError("Usage: normalize-capture.swift input output")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
