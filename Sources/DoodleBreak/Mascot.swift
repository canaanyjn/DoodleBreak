import SwiftUI

/// 吉祥物「豆豆」：用圆珠笔画在纸上的小豆子，坐在椅子上，久坐越久越蔫
struct Mascot: View {
    var mood: Mood
    var size: CGFloat = 80

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, sz in
                MascotDrawing(mood: mood, s: size, t: t).draw(g, sz)
            }
        }
        .frame(width: size * 1.2, height: size * 1.1)
    }
}

struct MascotDrawing {
    let mood: Mood
    let s: CGFloat
    let t: Double

    func draw(_ g: GraphicsContext, _ size: CGSize) {
        let cx = size.width / 2
        // 线条"沸腾"：每秒换 5 次笔迹，循环 3 帧，像逐帧手绘动画
        let boil = UInt64(Int(t * 5) % 3) &* 977
        func sd(_ k: UInt64) -> UInt64 { k &* 7_919 &+ boil }
        let lw = max(1.15, s / 48)
        let amp = max(0.55, s / 80)
        let sc = max(0.6, s / 80)
        let ink = Ink.blue

        func pen(_ p: Path, _ k: UInt64, color: Color = Ink.blue, width: CGFloat? = nil, passes: Int = 2, overshoot: CGFloat = 0.07) {
            g.ink(p, color: color, width: width ?? lw, seed: sd(k), wobble: amp, scale: sc, overshoot: overshoot, passes: passes)
        }
        func dot(_ c: CGPoint, r: CGFloat, _ k: UInt64, color: Color = Ink.blue) {
            g.inkFill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), color: color, seed: sd(k), wobble: amp * 0.3)
        }

        let sitting = mood != .stretching
        let squash: CGFloat = mood == .tired ? 0.9 : (mood == .sleeping ? 0.93 : 1)
        let breath = CGFloat(sin(t * 2.2)) * 0.02
        let shake: CGFloat = mood == .urgent ? CGFloat(sin(t * 30)) * s * 0.014 : 0
        let bob: CGFloat = mood == .stretching ? CGFloat(abs(sin(t * 3.4))) * s * 0.08 : 0
        let seatY = s * 0.72
        let bw = s * 0.62
        let bh = s * 0.54 * squash * (1 + breath)
        let body: CGRect = sitting
            ? CGRect(x: cx - bw / 2 + shake, y: seatY - bh + s * 0.03, width: bw, height: bh)
            : CGRect(x: cx - bw / 2, y: s * 0.80 - bh - bob, width: bw, height: bh)
        let bodyPath = Path(roundedRect: body, cornerRadius: min(bw, bh) * 0.47)

        // ── 1. 椅背 / 地面
        if sitting {
            // 梯背椅：两根立柱 + 顶横档 + 一根中横档（被身体挡住大半）
            let postTop = s * 0.12
            for (i, sgn) in [CGFloat(-1), 1].enumerated() {
                pen(g.line(CGPoint(x: cx + sgn * s * 0.35, y: postTop), CGPoint(x: cx + sgn * s * 0.35, y: seatY)),
                    11 + UInt64(i), overshoot: 0)
            }
            let rail = CGRect(x: cx - s * 0.35, y: postTop + s * 0.01, width: s * 0.70, height: s * 0.075)
            g.inkFill(Path(roundedRect: rail, cornerRadius: s * 0.02), color: Ink.paper, seed: sd(16), wobble: amp * 0.5)
            g.scribble(Path(rail), color: ink.opacity(0.3), spacing: max(2, s / 32), angle: -20,
                       width: lw * 0.45, seed: sd(9), wobble: amp * 0.3, scale: sc)
            pen(Path(roundedRect: rail, cornerRadius: s * 0.02), 17)
            pen(g.line(CGPoint(x: cx - s * 0.35, y: s * 0.36), CGPoint(x: cx + s * 0.35, y: s * 0.36)), 18,
                width: lw * 0.9, passes: 1, overshoot: 0)
            for (i, dx) in [-s * 0.27, s * 0.27].enumerated() {
                pen(g.line(CGPoint(x: cx + dx, y: seatY + s * 0.07), CGPoint(x: cx + dx, y: s * 0.99)),
                    12 + UInt64(i), color: Ink.pencil, width: lw * 0.8, passes: 1, overshoot: 0)
            }
        } else {
            let gy = s * 1.0
            let sw = s * (0.46 - bob / s * 1.2)
            g.scribble(Path(ellipseIn: CGRect(x: cx - sw / 2, y: gy - s * 0.035, width: sw, height: s * 0.07)),
                       color: Ink.pencil.opacity(0.45), spacing: max(1.8, s / 40), angle: 10, width: lw * 0.45, seed: sd(14))
            pen(g.line(CGPoint(x: cx - s * 0.46, y: gy), CGPoint(x: cx + s * 0.46, y: gy)), 15,
                color: Ink.pencil, width: lw * 0.8, passes: 1, overshoot: 0)
        }

        // ── 2. 身体
        g.inkFill(bodyPath, color: Ink.paper, seed: sd(1), wobble: amp)
        var shade = g
        shade.clip(to: bodyPath)
        shade.clip(to: Path(ellipseIn: body.offsetBy(dx: bw * 0.40, dy: bh * 0.46).insetBy(dx: -bw * 0.1, dy: -bh * 0.1)))
        shade.stroke(Path(SketchCore.scribble(in: body, angleDegrees: 62, spacing: max(2.2, s / 30), seed: sd(2),
                                              amplitude: amp * 0.4, scale: sc)),
                     with: .color(ink.opacity(0.2)), lineWidth: lw * 0.5)
        pen(bodyPath, 3, width: lw * 1.15)
        if mood == .urgent {
            let halo = body.insetBy(dx: -s * 0.04, dy: -s * 0.04)
            pen(Path(roundedRect: halo, cornerRadius: min(halo.width, halo.height) * 0.47), 4,
                color: Ink.red, width: lw * 0.8, passes: 1, overshoot: 0.15)
        }

        // ── 3. 椅面 + 腿脚
        if sitting {
            let seat = CGRect(x: cx - s * 0.43, y: seatY, width: s * 0.86, height: s * 0.075)
            let seatPath = Path(roundedRect: seat, cornerRadius: s * 0.025)
            g.inkFill(seatPath, color: Ink.paper, seed: sd(20), wobble: amp * 0.6)
            g.scribble(seatPath, color: ink.opacity(0.28), spacing: max(2, s / 32), angle: 15,
                       width: lw * 0.45, seed: sd(21), wobble: amp * 0.3, scale: sc)
            pen(seatPath, 22)
            for (i, dx) in [-s * 0.37, s * 0.37].enumerated() {
                pen(g.line(CGPoint(x: cx + dx, y: seat.maxY), CGPoint(x: cx + dx * 1.03, y: s * 1.06)),
                    23 + UInt64(i), passes: 1, overshoot: 0)
            }
            let kick = mood == .fresh || mood == .okay ? CGFloat(sin(t * 4)) * s * 0.025 : 0
            for (i, sgn) in [CGFloat(-1), 1].enumerated() {
                let top = CGPoint(x: cx + sgn * s * 0.12 + shake, y: seatY + s * 0.04)
                let foot = CGPoint(x: cx + sgn * s * 0.14 + shake + (i == 0 ? kick : -kick), y: seatY + s * 0.20)
                pen(g.line(top, foot), 30 + UInt64(i), overshoot: 0)
                shoe(g, at: foot, dir: sgn, seed: sd(32 + UInt64(i)), amp: amp, lw: lw)
            }
        } else {
            for (i, sgn) in [CGFloat(-1), 1].enumerated() {
                let top = CGPoint(x: cx + sgn * s * 0.1, y: body.maxY - s * 0.03)
                let foot = CGPoint(x: cx + sgn * s * 0.15, y: body.maxY + s * 0.12)
                pen(g.line(top, foot), 30 + UInt64(i), overshoot: 0)
                shoe(g, at: foot, dir: sgn, seed: sd(32 + UInt64(i)), amp: amp, lw: lw)
            }
        }

        // ── 4. 手臂
        for (i, sgn) in [CGFloat(-1), 1].enumerated() {
            var p = Path()
            let hand: CGPoint
            if sitting {
                let shoulder = CGPoint(x: body.midX + sgn * (bw / 2 - s * 0.02), y: body.midY + s * 0.02)
                hand = CGPoint(x: body.midX + sgn * (bw / 2 + s * 0.07), y: seatY - s * 0.01)
                p.move(to: shoulder)
                p.addQuadCurve(to: hand, control: CGPoint(x: body.midX + sgn * (bw / 2 + s * 0.09), y: body.midY + s * 0.05))
            } else {
                let swing = CGFloat(sin(t * 3.4 + Double(i))) * s * 0.03
                let shoulder = CGPoint(x: cx + sgn * (bw / 2 - s * 0.04), y: body.minY + bh * 0.36)
                hand = CGPoint(x: cx + sgn * (s * 0.47 + swing), y: body.minY - s * 0.12)
                p.move(to: shoulder)
                p.addQuadCurve(to: hand, control: CGPoint(x: cx + sgn * (bw / 2 + s * 0.13), y: body.minY + bh * 0.12))
            }
            pen(p, 40 + UInt64(i), overshoot: 0)
            let hr = s * 0.03
            g.inkFill(Path(ellipseIn: CGRect(x: hand.x - hr, y: hand.y - hr, width: 2 * hr, height: 2 * hr)),
                      color: Ink.paper, seed: sd(42 + UInt64(i)), wobble: amp * 0.3)
            pen(Path(ellipseIn: CGRect(x: hand.x - hr, y: hand.y - hr, width: 2 * hr, height: 2 * hr)),
                44 + UInt64(i), width: lw * 0.9, passes: 1)
        }

        // ── 5. 脸
        let eyeY = body.midY - bh * 0.08
        let eyeDX = bw * 0.17
        let mouthY = body.midY + bh * 0.15
        let fx = body.midX
        let blink = t.truncatingRemainder(dividingBy: 4.1) < 0.15 && (mood == .fresh || mood == .okay)

        for (i, sgn) in [CGFloat(-1), 1].enumerated() {
            let e = CGPoint(x: fx + sgn * eyeDX, y: eyeY)
            let k = 50 + UInt64(i) * 5
            switch mood {
            case .fresh, .okay:
                if blink {
                    pen(g.line(CGPoint(x: e.x - s * 0.035, y: e.y), CGPoint(x: e.x + s * 0.035, y: e.y)), k, passes: 1, overshoot: 0)
                } else {
                    g.inkFill(Path(ellipseIn: CGRect(x: e.x - s * 0.028, y: e.y - s * 0.04, width: s * 0.056, height: s * 0.08)),
                              color: ink, seed: sd(k), wobble: amp * 0.3)
                }
            case .tired:
                pen(g.line(CGPoint(x: e.x - s * 0.042, y: e.y - s * 0.004), CGPoint(x: e.x + s * 0.042, y: e.y + sgn * s * 0.01)),
                    k, passes: 1, overshoot: 0)
                var lid = Path()
                lid.addArc(center: CGPoint(x: e.x, y: e.y), radius: s * 0.024, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                g.inkFill(lid, color: ink, seed: sd(k + 1), wobble: amp * 0.2)
                var bag = Path()
                bag.move(to: CGPoint(x: e.x - s * 0.03, y: e.y + s * 0.045))
                bag.addQuadCurve(to: CGPoint(x: e.x + s * 0.03, y: e.y + s * 0.045), control: CGPoint(x: e.x, y: e.y + s * 0.07))
                pen(bag, k + 2, color: Ink.pencil, width: lw * 0.6, passes: 1, overshoot: 0)
            case .urgent:
                let r = s * 0.05
                pen(Path(ellipseIn: CGRect(x: e.x - r, y: e.y - r, width: 2 * r, height: 2 * r)), k, width: lw * 0.9, passes: 1)
                let jit = CGFloat(sin(t * 23 + Double(i))) * s * 0.008
                dot(CGPoint(x: e.x + jit, y: e.y + s * 0.005), r: s * 0.017, k + 1)
            case .stretching:
                var p = Path()
                p.move(to: CGPoint(x: e.x - s * 0.042, y: e.y + s * 0.018))
                p.addLine(to: CGPoint(x: e.x, y: e.y - s * 0.028))
                p.addLine(to: CGPoint(x: e.x + s * 0.042, y: e.y + s * 0.018))
                pen(p, k, width: lw * 1.1, passes: 1, overshoot: 0)
            case .sleeping:
                var p = Path()
                p.move(to: CGPoint(x: e.x - s * 0.042, y: e.y))
                p.addQuadCurve(to: CGPoint(x: e.x + s * 0.042, y: e.y), control: CGPoint(x: e.x, y: e.y + s * 0.04))
                pen(p, k, passes: 1, overshoot: 0)
            }
        }

        // 嘴
        switch mood {
        case .fresh, .okay:
            let w = mood == .fresh ? s * 0.075 : s * 0.055
            var p = Path()
            p.move(to: CGPoint(x: fx - w, y: mouthY))
            p.addQuadCurve(to: CGPoint(x: fx + w, y: mouthY), control: CGPoint(x: fx, y: mouthY + (mood == .fresh ? s * 0.08 : s * 0.035)))
            pen(p, 60, overshoot: 0)
        case .tired:
            var p = Path()
            p.move(to: CGPoint(x: fx - s * 0.07, y: mouthY + s * 0.01))
            for i in 1...6 {
                p.addLine(to: CGPoint(x: fx - s * 0.07 + s * 0.14 * CGFloat(i) / 6, y: mouthY + (i % 2 == 0 ? s * 0.01 : -s * 0.012)))
            }
            pen(p, 60, passes: 1, overshoot: 0)
        case .urgent:
            let r = CGRect(x: fx - s * 0.035, y: mouthY - s * 0.03, width: s * 0.07, height: s * 0.09)
            g.inkFill(Path(ellipseIn: r), color: ink.opacity(0.85), seed: sd(60), wobble: amp * 0.3)
        case .stretching:
            var p = Path()
            p.move(to: CGPoint(x: fx - s * 0.09, y: mouthY - s * 0.02))
            p.addLine(to: CGPoint(x: fx + s * 0.09, y: mouthY - s * 0.02))
            p.addQuadCurve(to: CGPoint(x: fx - s * 0.09, y: mouthY - s * 0.02), control: CGPoint(x: fx, y: mouthY + s * 0.14))
            p.closeSubpath()
            g.scribble(p, color: Ink.red.opacity(0.55), spacing: max(1.6, s / 45), angle: 30, width: lw * 0.5, seed: sd(61))
            pen(p, 62, overshoot: 0.05)
        case .sleeping:
            let r = CGRect(x: fx - s * 0.02, y: mouthY - s * 0.01, width: s * 0.04, height: s * 0.035)
            pen(Path(ellipseIn: r), 60, width: lw * 0.8, passes: 1)
        }

        // 腮红：红笔涂两团
        if mood == .fresh || mood == .okay || mood == .stretching {
            for (i, sgn) in [CGFloat(-1), 1].enumerated() {
                let c = CGPoint(x: fx + sgn * bw * 0.32, y: mouthY - s * 0.02)
                let r = s * 0.045
                g.scribble(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: 2 * r, height: 1.4 * r)),
                           color: Ink.red.opacity(0.5), spacing: max(1.5, s / 50), angle: 70, width: lw * 0.5,
                           seed: sd(70 + UInt64(i)), wobble: amp * 0.3)
            }
        }

        // ── 6. 小道具
        func handText(_ text: String, _ at: CGPoint, _ size: CGFloat, _ color: Color, rotate: Double = 0) {
            var c = g
            c.translateBy(x: at.x, y: at.y)
            c.rotate(by: .degrees(rotate))
            c.draw(Text(text).font(Hand.font(size, bold: true)).foregroundColor(color), at: .zero)
        }
        func sparkle(_ c: CGPoint, _ r: CGFloat, _ k: UInt64, color: Color = Ink.blue) {
            pen(g.line(CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x + r, y: c.y)), k, color: color, width: lw * 0.8, passes: 1, overshoot: 0)
            pen(g.line(CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x, y: c.y + r)), k + 1, color: color, width: lw * 0.8, passes: 1, overshoot: 0)
        }

        switch mood {
        case .fresh:
            sparkle(CGPoint(x: body.maxX + s * 0.06, y: body.minY + s * 0.02), s * 0.05, 80)
            sparkle(CGPoint(x: body.maxX + s * 0.13, y: body.minY + s * 0.12), s * 0.028, 82)
        case .okay:
            let y = body.minY - s * 0.02 + CGFloat(sin(t * 2)) * s * 0.02
            handText("♪", CGPoint(x: body.maxX + s * 0.08, y: y), s * 0.2, Ink.blue, rotate: 12)
        case .tired:
            let fall = CGFloat((t * 0.7).truncatingRemainder(dividingBy: 1)) * s * 0.07
            let d = CGPoint(x: body.maxX + s * 0.02, y: body.minY + s * 0.1 + fall)
            var p = Path()
            p.move(to: CGPoint(x: d.x, y: d.y - s * 0.065))
            p.addQuadCurve(to: CGPoint(x: d.x + s * 0.032, y: d.y + s * 0.005), control: CGPoint(x: d.x + s * 0.028, y: d.y - s * 0.028))
            p.addQuadCurve(to: CGPoint(x: d.x - s * 0.032, y: d.y + s * 0.005), control: CGPoint(x: d.x, y: d.y + s * 0.06))
            p.addQuadCurve(to: CGPoint(x: d.x, y: d.y - s * 0.065), control: CGPoint(x: d.x - s * 0.028, y: d.y - s * 0.028))
            g.inkFill(p, color: Ink.paper, seed: sd(84), wobble: amp * 0.3)
            pen(p, 85, width: lw * 0.85, passes: 1, overshoot: 0.05)
        case .urgent:
            let pulse = 1 + 0.12 * abs(sin(t * 8))
            handText("!!", CGPoint(x: body.maxX + s * 0.1, y: body.minY - s * 0.02), s * 0.26 * pulse, Ink.red, rotate: 10)
        case .stretching:
            sparkle(CGPoint(x: cx - s * 0.2, y: s * 0.07), s * 0.04, 86)
            sparkle(CGPoint(x: cx + s * 0.24, y: s * 0.03), s * 0.03, 88)
            for (i, sgn) in [CGFloat(-1), 1].enumerated() {
                var p = Path()
                let c = CGPoint(x: cx + sgn * s * 0.5, y: body.minY + s * 0.02)
                p.addArc(center: c, radius: s * 0.1, startAngle: .degrees(sgn < 0 ? 160 : -20),
                         endAngle: .degrees(sgn < 0 ? 200 : 20), clockwise: false)
                pen(p, 90 + UInt64(i), color: Ink.pencil, width: lw * 0.7, passes: 1, overshoot: 0)
            }
        case .sleeping:
            let ph = CGFloat(t.truncatingRemainder(dividingBy: 2.4) / 2.4)
            var c = g
            c.opacity = Double(1 - ph)
            c.draw(Text("z").font(Hand.font(s * 0.17, bold: true)).foregroundColor(Ink.pencil),
                   at: CGPoint(x: body.maxX + s * 0.04 + ph * s * 0.05, y: body.minY + s * 0.02 - ph * s * 0.12))
            c.draw(Text("Z").font(Hand.font(s * 0.24, bold: true)).foregroundColor(Ink.pencil),
                   at: CGPoint(x: body.maxX + s * 0.14 + ph * s * 0.06, y: body.minY - s * 0.1 - ph * s * 0.14))
        }
    }

    private func shoe(_ g: GraphicsContext, at foot: CGPoint, dir: CGFloat, seed: UInt64, amp: CGFloat, lw: CGFloat) {
        let r = CGRect(x: foot.x - s * 0.05 + dir * s * 0.02, y: foot.y - s * 0.02, width: s * 0.1, height: s * 0.05)
        g.inkFill(Path(ellipseIn: r), color: Ink.blue.opacity(0.9), seed: seed, wobble: amp * 0.3)
    }
}
