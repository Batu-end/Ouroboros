// Builds Resources/AppIcon.icns from a line-art source image.
//
//   swift Tools/MakeIcon.swift <source-image> [output.icns]
//
// The source is expected to be dark linework on a flat light background: the background is
// keyed out by luminance, the remaining ink is recolored, and the result is composited onto
// a dark rounded-square macOS icon canvas.
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: MakeIcon.swift <source-image> [output.icns]\n".utf8))
    exit(2)
}
let sourcePath = args[1]
let outputPath = args.count >= 3 ? args[2] : "Resources/AppIcon.icns"

guard let source = NSImage(contentsOfFile: sourcePath),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("✗ could not read image at \(sourcePath)\n".utf8))
    exit(1)
}

// MARK: - 1. Key the flat background out, keep the ink

let w = cg.width, h = cg.height
var gray = [UInt8](repeating: 0, count: w * h)
gray.withUnsafeMutableBytes { buf in
    let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
}

// The most common value is the paper/background level; JPEG noise sits just under it,
// so everything above a knee below that level is cut to fully transparent.
var histogram = [Int](repeating: 0, count: 256)
for value in gray { histogram[Int(value)] += 1 }
let background = Double(histogram.firstIndex(of: histogram.max()!)!)
let knee = background - 18            // noise floor: above this is paper, not ink
let darkest = Double(gray.min() ?? 0)
let range = max(knee - darkest, 1)

let ink = (r: 0.94, g: 0.96, b: 0.95)   // near-white, a hair cool

var rgba = [UInt8](repeating: 0, count: w * h * 4)
// Track the ink's bounding box so the figure can be cropped tight and fill the plate.
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = y * w + x
        let lum = Double(gray[i])
        let alpha = min(1.0, max(0.0, (knee - lum) / range) * 1.15)
        let a = UInt8(alpha * 255)
        rgba[i * 4 + 0] = UInt8(ink.r * Double(a))   // premultiplied
        rgba[i * 4 + 1] = UInt8(ink.g * Double(a))
        rgba[i * 4 + 2] = UInt8(ink.b * Double(a))
        rgba[i * 4 + 3] = a
        if alpha > 0.25 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}

let full: CGImage = rgba.withUnsafeMutableBytes { buf in
    CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}

let pad = 4
let crop = CGRect(x: max(0, minX - pad), y: max(0, minY - pad),
                  width: min(w, maxX - minX + pad * 2), height: min(h, maxY - minY + pad * 2))
let artwork = (crop.width > 1 && crop.height > 1 ? full.cropping(to: crop) : nil) ?? full
let artW = artwork.width, artH = artwork.height

// MARK: - 2. Composite the icon canvas

func renderIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // macOS app icons sit in a rounded square inset from the full canvas.
    let inset = s * 0.055
    let plate = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = plate.width * 0.2237
    let shape = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [CGColor(red: 0.13, green: 0.15, blue: 0.16, alpha: 1),
                                       CGColor(red: 0.05, green: 0.055, blue: 0.065, alpha: 1)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: plate.maxY),
                           end: CGPoint(x: 0, y: plate.minY), options: [])

    // Teal halo behind the figure, echoing the app's work accent.
    let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [CGColor(red: 0.21, green: 0.68, blue: 0.68, alpha: 0.28),
                                   CGColor(red: 0.21, green: 0.68, blue: 0.68, alpha: 0)] as CFArray,
                          locations: [0, 1])!
    ctx.setAlpha(size <= 64 ? 1.6 : 1.0)
    ctx.drawRadialGradient(halo, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                           endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s * 0.46, options: [])
    ctx.setAlpha(1.0)
    ctx.restoreGState()

    // The snake, scaled to fit the plate with margin, centered.
    // Below 64px the linework turns to mush, so the figure is drawn larger and the ink is
    // laid down twice to thicken faint strokes.
    let small = size <= 64
    let fill: CGFloat = small ? 0.90 : 0.80
    let scale = min(plate.width * fill / CGFloat(artW), plate.height * fill / CGFloat(artH))
    let drawn = CGRect(x: (s - CGFloat(artW) * scale) / 2,
                       y: (s - CGFloat(artH) * scale) / 2,
                       width: CGFloat(artW) * scale,
                       height: CGFloat(artH) * scale)
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.setShadow(offset: .zero, blur: s * 0.02,
                  color: CGColor(red: 0.21, green: 0.68, blue: 0.68, alpha: 0.55))
    ctx.interpolationQuality = .high
    ctx.draw(artwork, in: drawn)
    if small {
        ctx.draw(artwork, in: drawn)
        ctx.draw(artwork, in: drawn)
    }
    ctx.restoreGState()

    // Hairline rim so the plate reads against a dark desktop.
    ctx.addPath(shape)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(max(1, s * 0.004))
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - 3. Write the iconset and convert

let fm = FileManager.default
let iconset = NSTemporaryDirectory() + "Ouroboros-\(UUID().uuidString).iconset"
try fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let variants: [(name: String, size: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for variant in variants {
    let image = renderIcon(size: variant.size)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: variant.size, height: variant.size)
    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: URL(fileURLWithPath: "\(iconset)/\(variant.name).png"))
}

let convert = Process()
convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
convert.arguments = ["-c", "icns", iconset, "-o", outputPath]
try convert.run()
convert.waitUntilExit()
try? fm.removeItem(atPath: iconset)

guard convert.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("✗ iconutil failed\n".utf8))
    exit(1)
}
print("✓ wrote \(outputPath)")

// A 1024px preview, handy for the README.
if let preview = NSBitmapImageRep(cgImage: renderIcon(size: 1024))
    .representation(using: .png, properties: [:]) {
    try preview.write(to: URL(fileURLWithPath: "Resources/AppIcon-preview.png"))
    print("✓ wrote Resources/AppIcon-preview.png")
}
