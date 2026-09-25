import CoreGraphics
import Foundation

/// 可复现的随机数（同一个 seed 永远画出同一条线）
struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed ^ 0x2545F4914F6CDD1D }

    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }

    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
    mutating func cg(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat(range(Double(a), Double(b))) }
}

/// 手绘笔触引擎：把规整的几何路径变成"圆珠笔随手画"的样子
/// 只依赖 CoreGraphics，App 和图标生成脚本共用
enum SketchCore {
    static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }

    struct Polyline {
        var points: [CGPoint]
        var closed: Bool
    }

    /// 把路径拆成等距采样的折线
    static func flatten(_ path: CGPath, step: CGFloat) -> [Polyline] {
        var result: [Polyline] = []
        var current: [CGPoint] = []
        var start = CGPoint.zero
        var last = CGPoint.zero

        func flush(closed: Bool) {
            if current.count > 1 { result.append(Polyline(points: current, closed: closed)) }
            current = []
        }
        func sample(count n: Int, _ f: (CGFloat) -> CGPoint) {
            for i in 1...max(1, n) { current.append(f(CGFloat(i) / CGFloat(max(1, n)))) }
        }
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(b.x - a.x, b.y - a.y) }

        path.applyWithBlock { el in
            let e = el.pointee
            switch e.type {
            case .moveToPoint:
                flush(closed: false)
                last = e.points[0]; start = last; current = [last]
            case .addLineToPoint:
                let p = e.points[0], p0 = last
                if current.isEmpty { current = [p0] }
                sample(count: Int(ceil(dist(p0, p) / step))) { t in
                    CGPoint(x: p0.x + (p.x - p0.x) * t, y: p0.y + (p.y - p0.y) * t)
                }
                last = p
            case .addQuadCurveToPoint:
                let c = e.points[0], p = e.points[1], p0 = last
                if current.isEmpty { current = [p0] }
                sample(count: max(2, Int(ceil((dist(p0, c) + dist(c, p)) / step)))) { t in
                    let m = 1 - t
                    return CGPoint(x: m * m * p0.x + 2 * m * t * c.x + t * t * p.x,
                                   y: m * m * p0.y + 2 * m * t * c.y + t * t * p.y)
                }
                last = p
            case .addCurveToPoint:
                let c1 = e.points[0], c2 = e.points[1], p = e.points[2], p0 = last
                if current.isEmpty { current = [p0] }
                sample(count: max(2, Int(ceil((dist(p0, c1) + dist(c1, c2) + dist(c2, p)) / step)))) { t in
                    let m = 1 - t
                    let a = m * m * m, b = 3 * m * m * t, c = 3 * m * t * t, d = t * t * t
                    return CGPoint(x: a * p0.x + b * c1.x + c * c2.x + d * p.x,
                                   y: a * p0.y + b * c1.y + c * c2.y + d * p.y)
                }
                last = p
            case .closeSubpath:
                if dist(last, start) > 0.01 {
                    let p0 = last
                    sample(count: Int(ceil(dist(p0, start) / step))) { t in
                        CGPoint(x: p0.x + (start.x - p0.x) * t, y: p0.y + (start.y - p0.y) * t)
                    }
                }
                flush(closed: true)
                last = start
            @unknown default:
                break
            }
        }
        flush(closed: false)
        return result
    }

    /// 核心：给路径加上手抖
    /// - amplitude: 抖动幅度（点）
    /// - scale: 笔画尺度，越大抖动越"慢"（大图标用）
    /// - overshoot: 闭合图形收笔时多画出去的比例，像随手画圈没对齐
    static func wobble(_ path: CGPath, seed: UInt64, amplitude: CGFloat, scale: CGFloat = 1,
                       overshoot: CGFloat = 0.07, drift: CGFloat = 1) -> CGPath {
        let out = CGMutablePath()
        var rng = SeededRandom(seed)
        for line in flatten(path, step: 2.5 * max(0.4, scale)) {
            var pts = line.points
            if line.closed, pts.count > 3 {
                pts.removeLast()
                let shift = Int(rng.range(0, Double(pts.count)))
                pts = Array(pts[shift...] + pts[..<shift])
                let extra = Int(CGFloat(pts.count) * overshoot)
                pts += Array(pts.prefix(extra + 1))
            }
            var total: CGFloat = 0
            for i in 1..<pts.count { total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }

            let k = Double(1 / max(0.2, scale))
            let f = [rng.range(0.035, 0.06) * k, rng.range(0.11, 0.17) * k, rng.range(0.28, 0.42) * k]
            let px = [rng.range(0, 6.3), rng.range(0, 6.3), rng.range(0, 6.3)]
            let py = [rng.range(0, 6.3), rng.range(0, 6.3), rng.range(0, 6.3)]
            let driftAngle = rng.range(0, 6.3)
            let driftLen = Double(amplitude * 1.6 * drift)

            var s: Double = 0
            var noisy: [CGPoint] = []
            noisy.reserveCapacity(pts.count)
            for i in pts.indices {
                if i > 0 { s += Double(hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
                let nx = 0.62 * sin(s * f[0] + px[0]) + 0.28 * sin(s * f[1] + px[1]) + 0.10 * sin(s * f[2] + px[2])
                let ny = 0.62 * sin(s * f[0] + py[0]) + 0.28 * sin(s * f[1] + py[1]) + 0.10 * sin(s * f[2] + py[2])
                let d = driftLen * s / Double(max(1, total))
                noisy.append(CGPoint(x: pts[i].x + CGFloat(nx) * amplitude + CGFloat(cos(driftAngle) * d),
                                     y: pts[i].y + CGFloat(ny) * amplitude + CGFloat(sin(driftAngle) * d)))
            }
            addSmooth(noisy, to: out)
        }
        return out
    }

    static func addSmooth(_ pts: [CGPoint], to out: CGMutablePath) {
        guard pts.count > 1 else { return }
        out.move(to: pts[0])
        guard pts.count > 2 else { out.addLine(to: pts[1]); return }
        for i in 1..<(pts.count - 1) {
            let m = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            out.addQuadCurve(to: m, control: pts[i])
        }
        out.addLine(to: pts[pts.count - 1])
    }

    /// 圆珠笔来回涂的阴影线（之字形），调用方负责裁剪到形状内
    static func scribble(in rect: CGRect, angleDegrees: CGFloat, spacing: CGFloat, seed: UInt64,
                         amplitude: CGFloat = 0.5, scale: CGFloat = 1) -> CGPath {
        var rng = SeededRandom(seed)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = hypot(rect.width, rect.height) / 2 + spacing
        let a = angleDegrees * .pi / 180
        let ca = cos(a), sa = sin(a)
        var pts: [CGPoint] = []
        var k = -r
        var i = 0
        while k <= r {
            let u = (i % 2 == 0 ? -r : r) + rng.cg(-spacing, spacing)
            pts.append(CGPoint(x: c.x + u * ca - k * sa, y: c.y + u * sa + k * ca))
            k += spacing * rng.cg(0.8, 1.2)
            i += 1
        }
        let p = CGMutablePath()
        p.addLines(between: pts)
        return wobble(p, seed: seed &+ 1, amplitude: amplitude, scale: scale, overshoot: 0, drift: 0)
    }
}
