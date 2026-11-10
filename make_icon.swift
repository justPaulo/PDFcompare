// Generates a .iconset folder of PNGs. Usage: make_icon <output-dir>
import AppKit

func roundedRect(_ ctx: CGContext, _ r: CGRect, _ radius: CGFloat) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
}

func drawIcon(_ ctx: CGContext, size: CGFloat) {
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)
    let cs = CGColorSpaceCreateDeviceRGB()

    // Background squircle with gradient
    ctx.saveGState()
    roundedRect(ctx, CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    ctx.clip()
    let colors = [CGColor(red: 0.22, green: 0.25, blue: 0.82, alpha: 1),
                  CGColor(red: 0.38, green: 0.66, blue: 1.0, alpha: 1)] as CFArray
    if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    }
    ctx.restoreGState()

    func page(center: CGPoint, angle: CGFloat, accent: CGColor) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        let r = CGRect(x: -155, y: -205, width: 310, height: 410)
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        roundedRect(ctx, r, 24)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        let widths: [CGFloat] = [210, 170, 230, 190, 150, 200]
        for i in 0..<6 {
            let y = 140 - CGFloat(i) * 62
            let line = CGRect(x: -110, y: y, width: widths[i], height: 20)
            if i == 2 {
                ctx.setFillColor(accent.copy(alpha: 0.25) ?? accent)
                roundedRect(ctx, line.insetBy(dx: -12, dy: -12), 16)
                ctx.fillPath()
                ctx.setFillColor(accent)
            } else {
                ctx.setFillColor(CGColor(gray: 0.82, alpha: 1))
            }
            roundedRect(ctx, line, 10)
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    page(center: CGPoint(x: 400, y: 540), angle: 0.10,
         accent: CGColor(red: 0.90, green: 0.12, blue: 0.15, alpha: 1))
    page(center: CGPoint(x: 624, y: 510), angle: -0.08,
         accent: CGColor(red: 0.08, green: 0.65, blue: 0.27, alpha: 1))
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make_icon <output-dir>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (px, name) in specs {
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let img = ({ drawIcon(ctx, size: CGFloat(px)); return ctx.makeImage() })(),
          let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])
    else { fatalError("failed to render \(name)") }
    try png.write(to: outDir.appendingPathComponent(name + ".png"))
}
