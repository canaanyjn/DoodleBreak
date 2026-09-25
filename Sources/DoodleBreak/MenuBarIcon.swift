import AppKit

/// 菜单栏小图标：一个手画的圈，剩余时间越少圈越短，中间的点越来越大
@MainActor
enum MenuBarIcon {
    private static var cache: [Int: NSImage] = [:]

    static func image(progress: Double, phase: Phase) -> NSImage {
        let key: Int
        switch phase {
        case .onBreak: key = -1
        case .paused: key = -2
        case .sitting: key = Int((min(1, max(0, progress)) * 100).rounded())
        }
        if let cached = cache[key] { return cached }
        let img = draw(key)
        cache[key] = img
        return img
    }

    private static func draw(_ key: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            let c = CGPoint(x: 9, y: 9)
            let R: CGFloat = 6.4

            func stroke(_ path: CGPath, seed: UInt64, width: CGFloat, alpha: CGFloat, overshoot: CGFloat = 0.12) {
                cg.addPath(SketchCore.wobble(path, seed: seed, amplitude: 0.45, scale: 0.25, overshoot: overshoot))
                cg.setStrokeColor(NSColor.black.withAlphaComponent(alpha).cgColor)
                cg.setLineWidth(width)
                cg.strokePath()
            }

            let circle = CGPath(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R), transform: nil)
            switch key {
            case -1: // 休息中：一个小人举起双手（圈 + 两道斜线）
                stroke(circle, seed: 3, width: 1.5, alpha: 1)
                let arms = CGMutablePath()
                arms.move(to: CGPoint(x: 5.2, y: 7)); arms.addLine(to: CGPoint(x: 1.6, y: 2.4))
                arms.move(to: CGPoint(x: 12.8, y: 7)); arms.addLine(to: CGPoint(x: 16.4, y: 2.4))
                stroke(arms, seed: 4, width: 1.5, alpha: 1, overshoot: 0)
                // ^ ^ 眼睛
                let eyes = CGMutablePath()
                eyes.move(to: CGPoint(x: 6.6, y: 9.4)); eyes.addLine(to: CGPoint(x: 7.5, y: 8.3)); eyes.addLine(to: CGPoint(x: 8.4, y: 9.4))
                eyes.move(to: CGPoint(x: 9.6, y: 9.4)); eyes.addLine(to: CGPoint(x: 10.5, y: 8.3)); eyes.addLine(to: CGPoint(x: 11.4, y: 9.4))
                stroke(eyes, seed: 5, width: 1.0, alpha: 1, overshoot: 0)
            case -2: // 暂停：圈里两道竖线
                stroke(circle, seed: 3, width: 1.3, alpha: 0.9)
                let bars = CGMutablePath()
                bars.move(to: CGPoint(x: 7.4, y: 6.2)); bars.addLine(to: CGPoint(x: 7.4, y: 11.8))
                bars.move(to: CGPoint(x: 10.6, y: 6.2)); bars.addLine(to: CGPoint(x: 10.6, y: 11.8))
                stroke(bars, seed: 6, width: 1.6, alpha: 1, overshoot: 0)
            default:
                let p = Double(key) / 100
                stroke(circle, seed: 3, width: 1.0, alpha: 0.4)
                let left = 1 - p   // 和弹窗一致：圈显示剩余时间
                if left > 0.01 {
                    let arc = CGMutablePath()
                    arc.addArc(center: c, radius: R, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * left, clockwise: false)
                    stroke(arc, seed: 7, width: 2.3, alpha: 1, overshoot: 0)
                }
                let d = 1.8 + 3.0 * p
                cg.setFillColor(NSColor.black.withAlphaComponent(0.4 + 0.6 * p).cgColor)
                cg.fillEllipse(in: CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d))
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
