// 生成 App 图标：一张横线便签纸，上面用圆珠笔画着举手欢呼的豆豆
// 与 App 共用 SketchCore.swift 的手抖笔触
// 用法: makeicon <输出.icns> [预览.png]
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: makeicon <out.icns> [preview.png]")
    exit(1)
}

let inkBlue = CGColor(srgbRed: 0.13, green: 0.22, blue: 0.55, alpha: 1)
let inkRed = CGColor(srgbRed: 0.80, green: 0.19, blue: 0.21, alpha: 1)
let pencil = CGColor(srgbRed: 0.42, green: 0.43, blue: 0.48, alpha: 1)
let paper = CGColor(srgbRed: 0.988, green: 0.972, blue: 0.930, alpha: 1)

func render(px: Int) -> Data {
    let S = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.clear(CGRect(x: 0, y: 0, width: S, height: S))
    // 翻转成 y 向下，和 SwiftUI 一致
    cg.translateBy(x: 0, y: S)
    cg.scaleBy(x: 1, y: -1)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    let u = S / 1024
    let sc = S / 180   // 笔触尺度
    func ink(_ p: CGPath, _ color: CGColor, _ width: CGFloat, _ seed: UInt64, amp: CGFloat = 5, overshoot: CGFloat = 0.07, passes: Int = 2) {
        for i in 0..<passes {
            cg.addPath(SketchCore.wobble(p, seed: seed &+ UInt64(i) &* 7919, amplitude: amp * u * (i == 0 ? 1 : 0.7),
                                         scale: sc, overshoot: overshoot))
            cg.setStrokeColor(color.copy(alpha: i == 0 ? 0.95 : 0.4)!)
            cg.setLineWidth(max(0.8, (i == 0 ? width : width * 0.6) * u))
            cg.strokePath()
        }
    }
    func fill(_ p: CGPath, _ color: CGColor, _ seed: UInt64) {
        cg.addPath(SketchCore.wobble(p, seed: seed, amplitude: 3 * u, scale: sc, overshoot: 0, drift: 0))
        cg.setFillColor(color)
        cg.fillPath()
    }
    func scribble(_ clip: CGPath, _ color: CGColor, spacing: CGFloat, angle: CGFloat, width: CGFloat, _ seed: UInt64) {
        cg.saveGState()
        cg.addPath(clip); cg.clip()
        cg.addPath(SketchCore.scribble(in: clip.boundingBox.insetBy(dx: -4, dy: -4), angleDegrees: angle,
                                       spacing: spacing * u, seed: seed, amplitude: 2 * u, scale: sc))
        cg.setStrokeColor(color)
        cg.setLineWidth(max(0.6, width * u))
        cg.strokePath()
        cg.restoreGState()
    }
    func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
        let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); return p
    }

    // ── 纸片
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 10 * u), blur: 30 * u, color: CGColor(gray: 0, alpha: 0.3))
    cg.addPath(tilePath); cg.setFillColor(paper); cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(tilePath); cg.clip()
    // 横线
    var y = tile.minY + 150 * u
    while y < tile.maxY {
        cg.addPath(line(CGPoint(x: tile.minX, y: y), CGPoint(x: tile.maxX, y: y)))
        cg.setStrokeColor(CGColor(srgbRed: 0.55, green: 0.70, blue: 0.88, alpha: 0.55))
        cg.setLineWidth(max(0.5, 4 * u)); cg.strokePath()
        y += 86 * u
    }
    // 红色页边线
    for dx: CGFloat in [0, 12] {
        cg.addPath(line(CGPoint(x: tile.minX + 150 * u + dx * u, y: tile.minY), CGPoint(x: tile.minX + 150 * u + dx * u, y: tile.maxY)))
        cg.setStrokeColor(CGColor(srgbRed: 0.90, green: 0.42, blue: 0.42, alpha: 0.55))
        cg.setLineWidth(max(0.5, 4 * u)); cg.strokePath()
    }
    // 荧光笔一道
    cg.saveGState()
    cg.setBlendMode(.multiply)
    let hl = line(CGPoint(x: 260 * u, y: 745 * u), CGPoint(x: 800 * u, y: 715 * u))
    cg.addPath(SketchCore.wobble(hl, seed: 5, amplitude: 4 * u, scale: sc, overshoot: 0, drift: 0))
    cg.setStrokeColor(CGColor(srgbRed: 1.0, green: 0.86, blue: 0.2, alpha: 0.6))
    cg.setLineWidth(110 * u); cg.strokePath()
    cg.restoreGState()
    cg.restoreGState()

    // ── 豆豆（举手欢呼）
    let cx = 545 * u
    let s = 560 * u
    let bw = s * 0.62, bh = s * 0.54
    let body = CGRect(x: cx - bw / 2, y: 330 * u, width: bw, height: bh)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: bh * 0.47, cornerHeight: bh * 0.47, transform: nil)

    // 地面 + 腿
    for (i, sgn) in [CGFloat(-1), 1].enumerated() {
        let top = CGPoint(x: cx + sgn * s * 0.1, y: body.maxY - 10 * u)
        let foot = CGPoint(x: cx + sgn * s * 0.15, y: body.maxY + s * 0.1)
        ink(line(top, foot), inkBlue, 16, 41 + UInt64(i), overshoot: 0)
        fill(CGPath(ellipseIn: CGRect(x: foot.x - s * 0.05 + sgn * s * 0.02, y: foot.y - s * 0.02, width: s * 0.1, height: s * 0.05), transform: nil), inkBlue, 43 + UInt64(i))
    }
    // 身体
    fill(bodyPath, paper, 1)
    cg.saveGState()
    cg.addPath(bodyPath); cg.clip()
    cg.addEllipse(in: body.offsetBy(dx: bw * 0.34, dy: bh * 0.40).insetBy(dx: -bw * 0.1, dy: -bh * 0.1)); cg.clip()
    cg.addPath(SketchCore.scribble(in: body, angleDegrees: 62, spacing: 22 * u, seed: 2, amplitude: 2 * u, scale: sc))
    cg.setStrokeColor(inkBlue.copy(alpha: 0.35)!); cg.setLineWidth(max(0.6, 7 * u)); cg.strokePath()
    cg.restoreGState()
    ink(bodyPath, inkBlue, 20, 3)
    // 手臂
    for (i, sgn) in [CGFloat(-1), 1].enumerated() {
        let shoulder = CGPoint(x: cx + sgn * (bw / 2 - s * 0.04), y: body.minY + bh * 0.36)
        let hand = CGPoint(x: cx + sgn * s * 0.47, y: body.minY - s * 0.12)
        let p = CGMutablePath()
        p.move(to: shoulder)
        p.addQuadCurve(to: hand, control: CGPoint(x: cx + sgn * (bw / 2 + s * 0.13), y: body.minY + bh * 0.12))
        ink(p, inkBlue, 16, 50 + UInt64(i), overshoot: 0)
        let hr = s * 0.032
        let hc = CGPath(ellipseIn: CGRect(x: hand.x - hr, y: hand.y - hr, width: 2 * hr, height: 2 * hr), transform: nil)
        fill(hc, paper, 52 + UInt64(i))
        ink(hc, inkBlue, 14, 54 + UInt64(i), passes: 1)
    }
    // 眼睛 ^ ^
    let eyeY = body.midY - bh * 0.08
    for (i, sgn) in [CGFloat(-1), 1].enumerated() {
        let e = CGPoint(x: cx + sgn * bw * 0.17, y: eyeY)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: e.x - s * 0.045, y: e.y + s * 0.02))
        p.addLine(to: CGPoint(x: e.x, y: e.y - s * 0.03))
        p.addLine(to: CGPoint(x: e.x + s * 0.045, y: e.y + s * 0.02))
        ink(p, inkBlue, 18, 60 + UInt64(i), overshoot: 0, passes: 1)
    }
    // 大笑的嘴
    let mouthY = body.midY + bh * 0.15
    let m = CGMutablePath()
    m.move(to: CGPoint(x: cx - s * 0.09, y: mouthY - s * 0.02))
    m.addLine(to: CGPoint(x: cx + s * 0.09, y: mouthY - s * 0.02))
    m.addQuadCurve(to: CGPoint(x: cx - s * 0.09, y: mouthY - s * 0.02), control: CGPoint(x: cx, y: mouthY + s * 0.14))
    m.closeSubpath()
    scribble(m, inkRed.copy(alpha: 0.6)!, spacing: 12, angle: 30, width: 6, 70)
    ink(m, inkBlue, 16, 71, overshoot: 0.05)
    // 腮红
    for (i, sgn) in [CGFloat(-1), 1].enumerated() {
        let c = CGPoint(x: cx + sgn * bw * 0.32, y: mouthY - s * 0.02)
        let r = s * 0.05
        scribble(CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: 2 * r, height: 1.4 * r), transform: nil),
                 inkRed.copy(alpha: 0.55)!, spacing: 11, angle: 70, width: 6, 80 + UInt64(i))
    }
    // 闪光
    for (k, (c, r)) in [(CGPoint(x: 420 * u, y: 225 * u), 30 * u), (CGPoint(x: 690 * u, y: 195 * u), 24 * u)].enumerated() {
        ink(line(CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x + r, y: c.y)), inkBlue, 12, 90 + UInt64(k) * 2, overshoot: 0, passes: 1)
        ink(line(CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x, y: c.y + r)), inkBlue, 12, 91 + UInt64(k) * 2, overshoot: 0, passes: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DoodleBreak-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"), (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"), (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in sizes {
    try! render(px: px).write(to: tmp.appendingPathComponent(name))
}
if args.count >= 3 {
    try! render(px: 512).write(to: URL(fileURLWithPath: args[2]))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", tmp.path, "-o", args[1]]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: tmp)
exit(p.terminationStatus)
