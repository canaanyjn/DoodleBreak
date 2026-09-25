import SwiftUI

// MARK: - 在 Canvas 里用"笔"画

extension GraphicsContext {
    /// 圆珠笔描线：主笔画 + 一道更淡的复描，模拟笔尖出墨不均
    func ink(_ path: Path, color: Color = Ink.blue, width: CGFloat = 1.6, seed: UInt64,
             wobble: CGFloat = 1.1, scale: CGFloat = 1, overshoot: CGFloat = 0.07, passes: Int = 2) {
        for i in 0..<passes {
            let w = SketchCore.wobble(path.cgPath, seed: seed &+ UInt64(i) &* 7919,
                                      amplitude: wobble * (i == 0 ? 1 : 0.75), scale: scale, overshoot: overshoot)
            stroke(Path(w), with: .color(color.opacity(i == 0 ? 0.92 : 0.38)),
                   style: StrokeStyle(lineWidth: i == 0 ? width : width * 0.6, lineCap: .round, lineJoin: .round))
        }
    }

    /// 用抖过的轮廓填色（纸色填充可以挡住后面的线）
    func inkFill(_ path: Path, color: Color, seed: UInt64, wobble: CGFloat = 1, scale: CGFloat = 1) {
        fill(Path(SketchCore.wobble(path.cgPath, seed: seed, amplitude: wobble, scale: scale, overshoot: 0, drift: 0)),
             with: .color(color))
    }

    /// 在形状里来回涂阴影
    func scribble(_ clip: Path, color: Color, spacing: CGFloat, angle: CGFloat = 60, width: CGFloat = 0.9,
                  seed: UInt64, wobble: CGFloat = 0.5, scale: CGFloat = 1) {
        var c = self
        c.clip(to: clip)
        let p = SketchCore.scribble(in: clip.boundingRect.insetBy(dx: -2, dy: -2), angleDegrees: angle,
                                    spacing: spacing, seed: seed, amplitude: wobble, scale: scale)
        c.stroke(Path(p), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }
}

// MARK: - 纸

/// 横线笔记本纸：米白底 + 纸纹 + 浅蓝横线 + 红色页边线
struct PaperBackground: View {
    var lineSpacing: CGFloat = 24
    var firstLine: CGFloat = 24
    var marginX: CGFloat? = 16
    var seed: UInt64 = 7

    var body: some View {
        Canvas(opaque: true) { g, size in
            g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.paper))
            var rng = SeededRandom(seed)
            let n = Int(size.width * size.height / 110)
            for _ in 0..<n {
                let r = CGRect(x: rng.cg(0, size.width), y: rng.cg(0, size.height), width: rng.cg(0.6, 1.6), height: 0.7)
                g.fill(Path(r), with: .color(Ink.grain.opacity(rng.range(0.03, 0.08))))
            }
            var y = firstLine
            while y < size.height {
                g.stroke(g.line(CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)),
                         with: .color(Ink.rule.opacity(0.42)), lineWidth: 0.7)
                y += lineSpacing
            }
            if let m = marginX {
                for dx: CGFloat in [0, 2.4] {
                    g.stroke(g.line(CGPoint(x: m + dx, y: 0), CGPoint(x: m + dx, y: size.height)),
                             with: .color(Ink.margin.opacity(0.45)), lineWidth: 0.7)
                }
            }
        }
    }
}

// MARK: - 装饰件

/// 随手画的圆角框
struct SketchBorder: View {
    var seed: UInt64
    var radius: CGFloat = 10
    var color: Color = Ink.blue
    var width: CGFloat = 1.3
    var fill: Color? = nil
    var wobble: CGFloat = 1.0

    var body: some View {
        Canvas { g, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            let p = Path(roundedRect: r, cornerRadius: min(radius, r.height / 2))
            if let fill { g.inkFill(p, color: fill, seed: seed, wobble: wobble) }
            g.ink(p, color: color, width: width, seed: seed, wobble: wobble)
        }
    }
}

/// 荧光笔划过的一道
struct Highlight: View {
    var seed: UInt64
    var color: Color = Ink.highlighter

    var body: some View {
        Canvas { g, size in
            var rng = SeededRandom(seed)
            let h = size.height
            let cap = h * 0.32
            var p = Path()
            p.move(to: CGPoint(x: cap, y: h * 0.56 + rng.cg(-2, 2)))
            p.addLine(to: CGPoint(x: size.width - cap, y: h * 0.46 + rng.cg(-2, 2)))
            var m = g
            m.blendMode = .multiply
            for i in 0..<2 {
                let w = SketchCore.wobble(p.cgPath, seed: seed &+ UInt64(i) &* 13, amplitude: 1.2, overshoot: 0, drift: 0)
                m.stroke(Path(w), with: .color(color.opacity(0.48)),
                         style: StrokeStyle(lineWidth: h * (i == 0 ? 0.66 : 0.5), lineCap: .round))
            }
        }
    }
}

/// 一小段半透明胶带
struct Tape: View {
    var seed: UInt64 = 3

    var body: some View {
        Canvas { g, size in
            var rng = SeededRandom(seed)
            var p = Path()
            let w = size.width, h = size.height
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: w, y: 0))
            // 右边撕口
            var y: CGFloat = 0
            while y < h {
                y = min(h, y + rng.cg(3, 6))
                p.addLine(to: CGPoint(x: w - rng.cg(0, 4), y: y))
            }
            p.addLine(to: CGPoint(x: 0, y: h))
            // 左边撕口
            y = h
            while y > 0 {
                y = max(0, y - rng.cg(3, 6))
                p.addLine(to: CGPoint(x: rng.cg(0, 4), y: y))
            }
            p.closeSubpath()
            g.fill(p, with: .color(Ink.tape.opacity(0.78)))
            g.stroke(p, with: .color(Ink.grain.opacity(0.12)), lineWidth: 0.5)
        }
    }
}

/// 手写字下面的波浪下划线
struct Squiggle: View {
    var seed: UInt64
    var color: Color = Ink.red
    var width: CGFloat = 1.3

    var body: some View {
        Canvas { g, size in
            var p = Path()
            let steps = max(4, Int(size.width / 7))
            p.move(to: CGPoint(x: 1, y: size.height / 2))
            for i in 1...steps {
                let x = 1 + (size.width - 2) * CGFloat(i) / CGFloat(steps)
                p.addLine(to: CGPoint(x: x, y: size.height / 2 + (i % 2 == 0 ? -1 : 1) * size.height * 0.28))
            }
            g.ink(p, color: color, width: width, seed: seed, wobble: 0.6, overshoot: 0, passes: 1)
        }
    }
}
