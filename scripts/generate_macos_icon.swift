import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let size: CGFloat
}

let specs: [IconSpec] = [
    .init(filename: "icon_16x16.png", size: 16),
    .init(filename: "icon_16x16@2x.png", size: 32),
    .init(filename: "icon_32x32.png", size: 32),
    .init(filename: "icon_32x32@2x.png", size: 64),
    .init(filename: "icon_128x128.png", size: 128),
    .init(filename: "icon_128x128@2x.png", size: 256),
    .init(filename: "icon_256x256.png", size: 256),
    .init(filename: "icon_256x256@2x.png", size: 512),
    .init(filename: "icon_512x512.png", size: 512),
    .init(filename: "icon_512x512@2x.png", size: 1024),
]

func makeOutputImage(canvasSize: CGFloat, source: NSImage) -> NSImage? {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return nil }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let canvasRect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    let tileRect = canvasRect.insetBy(dx: canvasSize * 0.08, dy: canvasSize * 0.08)
    let radius = canvasSize * 0.225
    let path = NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius)

    let sourceSize = source.size
    guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

    let squareSide = min(sourceSize.width, sourceSize.height)
    let cropRect = CGRect(
        x: (sourceSize.width - squareSide) / 2,
        y: (sourceSize.height - squareSide) / 2,
        width: squareSide,
        height: squareSide
    )

    context.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.12)
    shadow.shadowBlurRadius = canvasSize * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -canvasSize * 0.015)
    shadow.set()
    NSColor(calibratedWhite: 1.0, alpha: 0.02).setFill()
    path.fill()
    context.restoreGState()

    context.saveGState()
    path.addClip()
    source.draw(in: tileRect, from: cropRect, operation: .sourceOver, fraction: 1.0)

    let glossRect = CGRect(
        x: tileRect.minX,
        y: tileRect.midY,
        width: tileRect.width,
        height: tileRect.height * 0.42
    )
    let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: radius, yRadius: radius)
    NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
    glossPath.fill()
    context.restoreGState()

    context.saveGState()
    NSColor(calibratedWhite: 1.0, alpha: 0.32).setStroke()
    path.lineWidth = max(2, canvasSize * 0.006)
    path.stroke()
    context.restoreGState()

    return image
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: generate_macos_icon.swift <source_png> <output_iconset_dir>\n", stderr)
    exit(1)
}

let sourcePath = arguments[1]
let outputDir = arguments[2]
let fileManager = FileManager.default

guard let source = NSImage(contentsOfFile: sourcePath) else {
    fputs("Unable to load source image: \(sourcePath)\n", stderr)
    exit(2)
}

try? fileManager.removeItem(atPath: outputDir)
try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for spec in specs {
    guard let rendered = makeOutputImage(canvasSize: spec.size, source: source),
          let tiff = rendered.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(spec.filename)\n", stderr)
        exit(3)
    }

    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(spec.filename)
    try pngData.write(to: url)
}

print("Generated macOS-style iconset at: \(outputDir)")