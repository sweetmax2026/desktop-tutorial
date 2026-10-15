import AppKit

// Separate the authored sprite atlas into equal, unscaled transparent face assets.
let args = CommandLine.arguments
guard args.count == 4, let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let board = NSImage(contentsOfFile: args[2]),
      let boardCG = board.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("atlas reference project") }
let root = URL(fileURLWithPath: args[3])
for (index, name) in ["calm", "relaxed", "neutral", "sad", "irritated"].enumerated() {
    let centerX = 225 + 383 * index
    guard let crop = cg.cropping(to: CGRect(x: centerX - 192, y: 203, width: 384, height: 384)) else { fatalError("crop") }
    let rep = NSBitmapImageRep(cgImage: crop)
    try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Resources/mood-\(name).png"))
}
for (index, name) in ["mood", "meditation"].enumerated() {
    let half = boardCG.width / 2
    let crop = boardCG.cropping(to: CGRect(x: index * half, y: 0, width: half, height: boardCG.height))!
    try NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("design/reference-\(name)-v3.png"))
}
