import AppKit
import Foundation

let sourceURL = URL(fileURLWithPath: "/Users/ko/Downloads/image.png.png")
let outputDirectory = URL(
    fileURLWithPath: "/Users/ko/Desktop/SoundBar/MacVolumeHUD/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)
let sizes: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Failed to load source icon at \(sourceURL.path)")
}

let backgroundColor = NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)

func drawSquareIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    backgroundColor.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let imageSize = sourceImage.size
    let scale = min(size / imageSize.width, size / imageSize.height)
    let drawWidth = imageSize.width * scale
    let drawHeight = imageSize.height * scale
    let drawRect = NSRect(
        x: (size - drawWidth) / 2,
        y: (size - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    )

    sourceImage.draw(
        in: drawRect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: false,
        hints: [
            .interpolation: NSImageInterpolation.high,
        ]
    )

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GenerateAppIcon", code: 1)
    }
    try pngData.write(to: url)
}

for entry in sizes {
    let image = drawSquareIcon(size: CGFloat(entry.pixels))
    try writePNG(image, to: outputDirectory.appendingPathComponent(entry.filename))
}
