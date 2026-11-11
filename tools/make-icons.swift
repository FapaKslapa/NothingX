import AppKit
import Foundation

let red = CGColor(red: 0xD7 / 255, green: 0x19 / 255, blue: 0x21 / 255, alpha: 1)

func pngData(size: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext, CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func squircle(center: CGPoint, half: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n: CGFloat = 5, steps = 160
    for k in 0..<steps {
        let t = CGFloat(k) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let p = CGPoint(x: center.x + half * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n),
                        y: center.y + half * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n))
        k == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func xBar(_ ctx: CGContext, center: CGPoint, length: CGFloat, thickness: CGFloat, angle: CGFloat, u: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle)
    let rect = CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness)
    let path = CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * u), blur: 30 * u, color: CGColor(gray: 0, alpha: 0.5))
    ctx.addPath(path)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient([CGColor(gray: 1, alpha: 0.98), CGColor(gray: 0.78, alpha: 0.9)], [0, 1]),
                           start: CGPoint(x: 0, y: thickness / 2), end: CGPoint(x: 0, y: -thickness / 2), options: [])
    ctx.restoreGState()
}

func drawAppIcon(_ ctx: CGContext, _ size: CGFloat) {
    let u = size / 1024
    let center = CGPoint(x: size / 2, y: size / 2)
    let body = squircle(center: center, half: 412 * u)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 26 * u, color: CGColor(gray: 0, alpha: 0.4))
    ctx.addPath(body)
    ctx.setFillColor(CGColor(gray: 0.05, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawRadialGradient(gradient([CGColor(gray: 0.30, alpha: 1), CGColor(gray: 0.09, alpha: 1), CGColor(gray: 0.02, alpha: 1)], [0, 0.55, 1]),
                           startCenter: CGPoint(x: size * 0.36, y: size * 0.74), startRadius: 0,
                           endCenter: CGPoint(x: size * 0.5, y: size * 0.5), endRadius: 620 * u, options: .drawsAfterEndLocation)
    ctx.restoreGState()
    ctx.addPath(body)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.16))
    ctx.setLineWidth(3 * u)
    ctx.strokePath()
    let length = 500 * u, thickness = 104 * u
    xBar(ctx, center: center, length: length, thickness: thickness, angle: .pi / 4, u: u)
    xBar(ctx, center: center, length: length, thickness: thickness, angle: -.pi / 4, u: u)
    ctx.setFillColor(red)
    ctx.fillEllipse(in: CGRect(x: center.x - 38 * u, y: center.y - 38 * u, width: 76 * u, height: 76 * u))
}

func drawGlyph(_ ctx: CGContext, _ size: CGFloat) {
    let inset = size * 0.2
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(size * 0.15)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: inset, y: inset)); ctx.addLine(to: CGPoint(x: size - inset, y: size - inset))
    ctx.move(to: CGPoint(x: inset, y: size - inset)); ctx.addLine(to: CGPoint(x: size - inset, y: inset))
    ctx.strokePath()
}

let fm = FileManager.default
let iconset = "build/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try pngData(size: base, draw: drawAppIcon).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base).png"))
    try pngData(size: base * 2, draw: drawAppIcon).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base)@2x.png"))
}
try pngData(size: 18, draw: drawGlyph).write(to: URL(fileURLWithPath: "Resources/MenuBarIcon.png"))
try pngData(size: 36, draw: drawGlyph).write(to: URL(fileURLWithPath: "Resources/MenuBarIcon@2x.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try task.run(); task.waitUntilExit()
print(task.terminationStatus == 0 ? "Icons written to Resources/" : "iconutil failed")
