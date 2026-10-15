import AppKit
guard CommandLine.arguments.count == 3,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let crop = cg.cropping(to: CGRect(x: 0, y: 0, width: 800, height: 600)) else { fatalError("capture output") }
let png = NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
