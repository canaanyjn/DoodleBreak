import SwiftUI

/// 手写按钮：主按钮 = 手画框 + 荧光笔底；普通 = 手画框；安静 = 只有铅笔字
struct InkButton: View {
    enum Kind { case primary, plain, quiet }

    var title: String
    var kind: Kind = .plain
    var size: CGFloat = 15
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        let seed = SketchCore.hash(title)
        Button(action: action) {
            Text(title)
                .font(Hand.font(size, bold: kind != .quiet))
                .foregroundStyle(kind == .quiet ? Ink.pencil : Ink.blue)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, kind == .quiet ? 4 : size * 0.95)
                .padding(.vertical, kind == .quiet ? 2 : size * 0.5)
                .background {
                    switch kind {
                    case .primary:
                        ZStack {
                            Highlight(seed: seed).padding(.horizontal, 2)
                            SketchBorder(seed: seed, radius: size)
                        }
                    case .plain:
                        SketchBorder(seed: seed, radius: size, width: 1.1)
                    case .quiet:
                        Squiggle(seed: seed, color: Ink.pencil, width: 0.9)
                            .frame(height: 5)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .offset(y: 3)
                            .opacity(hovered ? 1 : 0)
                    }
                }
                .contentShape(Rectangle())
                .rotationEffect(.degrees(hovered ? -1.8 : 0))
                .scaleEffect(hovered ? 1.05 : 1)
                .animation(.spring(duration: 0.25, bounce: 0.5), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// 豆豆的对话气泡（左侧带小尾巴）
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Hand.font(14.5))
            .foregroundStyle(Ink.blue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 22)
            .padding(.trailing, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BubbleDrawing())
            .animation(.easeInOut(duration: 0.3), value: text)
    }
}

private struct BubbleDrawing: View {
    var body: some View {
        Canvas { g, size in
            let tail: CGFloat = 10
            let r = CGRect(x: tail + 2, y: 3, width: size.width - tail - 5, height: size.height - 6)
            let box = Path(roundedRect: r, cornerRadius: min(16, r.height / 2))
            g.inkFill(box, color: .white.opacity(0.75), seed: 5, wobble: 1)
            g.ink(box, width: 1.3, seed: 6, wobble: 1)
            // 尾巴：先用纸色盖住框线，再画两笔
            let a = CGPoint(x: r.minX + 1, y: r.midY - 7)
            let b = CGPoint(x: r.minX + 1, y: r.midY + 5)
            let tip = CGPoint(x: 2, y: r.midY + 4)
            var cover = Path()
            cover.move(to: CGPoint(x: a.x + 2, y: a.y))
            cover.addLine(to: tip)
            cover.addLine(to: CGPoint(x: b.x + 2, y: b.y))
            cover.closeSubpath()
            g.fill(cover, with: .color(Ink.paper))
            g.ink(g.line(a, tip), width: 1.3, seed: 7, wobble: 0.6, overshoot: 0, passes: 1)
            g.ink(g.line(tip, b), width: 1.3, seed: 8, wobble: 0.6, overshoot: 0, passes: 1)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tilt: Double = 0

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Hand.font(23, bold: true))
                .foregroundStyle(Ink.blue)
            Text(label)
                .font(Hand.font(11.5))
                .foregroundStyle(Ink.pencil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(SketchBorder(seed: SketchCore.hash(label), radius: 8, width: 1.1, fill: .white.opacity(0.5)))
        .rotationEffect(.degrees(tilt))
    }
}

/// 最近 7 天：圆珠笔涂出来的柱子，今天用红笔
struct WeekChart: View {
    let days: [(label: String, count: Int, isToday: Bool)]

    var body: some View {
        let maxCount = max(1, days.map(\.count).max() ?? 1)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近 7 天起身次数")
                    .font(Hand.font(13, bold: true))
                    .foregroundStyle(Ink.blue)
                Spacer()
                Text("共 \(days.map(\.count).reduce(0, +)) 次")
                    .font(Hand.font(13, bold: true))
                    .foregroundStyle(Ink.red)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 2) {
                        Text(d.count > 0 ? "\(d.count)" : "")
                            .font(Hand.font(11, bold: true))
                            .foregroundStyle(d.isToday ? Ink.red : Ink.pencil)
                        Bar(isToday: d.isToday, seed: UInt64(i) &* 131 &+ 17)
                            .frame(height: max(6, 36 * CGFloat(d.count) / CGFloat(maxCount)))
                        Text(d.label)
                            .font(Hand.font(12, bold: d.isToday))
                            .foregroundStyle(d.isToday ? Ink.red : Ink.pencil)
                            .padding(.horizontal, 5)
                            .background {
                                if d.isToday {
                                    Canvas { g, size in
                                        g.ink(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1)),
                                              color: Ink.red, width: 1.1, seed: 99, wobble: 0.7, overshoot: 0.2, passes: 1)
                                    }
                                    .padding(-3)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)
        }
    }

    private struct Bar: View {
        let isToday: Bool
        let seed: UInt64

        var body: some View {
            Canvas { g, size in
                let r = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 1.5)
                let p = Path(r)
                let color = isToday ? Ink.red : Ink.blue
                g.scribble(p, color: color.opacity(isToday ? 0.6 : 0.4), spacing: 2.6, angle: 58, width: 0.8, seed: seed)
                g.ink(p, color: color, width: 1.1, seed: seed &+ 5, wobble: 0.6, overshoot: 0.04, passes: 1)
            }
        }
    }
}

/// 圆珠笔画的倒计时圈
enum RingDrawing {
    static func draw(_ g: GraphicsContext, size: CGSize, progress p: Double, color: Color, lineWidth: CGFloat, seed: UInt64) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) / 2 - 13
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi - .pi / 2
            let r0 = R + 6, r1 = R + (i % 3 == 0 ? 12 : 9)
            let p0 = CGPoint(x: c.x + r0 * CGFloat(cos(a)), y: c.y + r0 * CGFloat(sin(a)))
            let p1 = CGPoint(x: c.x + r1 * CGFloat(cos(a)), y: c.y + r1 * CGFloat(sin(a)))
            g.ink(g.line(p0, p1), color: Ink.pencil, width: i % 3 == 0 ? 1.3 : 0.9, seed: seed &+ UInt64(i), wobble: 0.4, overshoot: 0, passes: 1)
        }
        g.ink(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)),
              color: Ink.pencil.opacity(0.55), width: 0.9, seed: seed &+ 100, wobble: 1.1, overshoot: 0.05, passes: 1)
        guard p > 0.003 else { return }
        var arc = Path()
        arc.addArc(center: c, radius: R, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * p), clockwise: false)
        g.ink(arc, color: color, width: lineWidth, seed: seed &+ 200, wobble: 1.2, overshoot: 0)
        g.ink(arc, color: color, width: lineWidth * 0.55, seed: seed &+ 300, wobble: 1.9, overshoot: 0, passes: 1)
        let a = (-90 + 360 * p) * .pi / 180
        let e = CGPoint(x: c.x + R * CGFloat(cos(a)), y: c.y + R * CGFloat(sin(a)))
        g.fill(Path(ellipseIn: CGRect(x: e.x - lineWidth * 0.9, y: e.y - lineWidth * 0.9,
                                      width: lineWidth * 1.8, height: lineWidth * 1.8)), with: .color(color))
    }
}

/// 弹窗里的大倒计时
struct RingTimer: View {
    @EnvironmentObject var tracker: SitTracker

    private var ringColor: Color {
        switch tracker.phase {
        case .sitting: return tracker.progress > 0.85 ? Ink.red : Ink.blue
        case .onBreak: return Ink.blue
        case .paused: return Ink.pencil
        }
    }

    private var mainText: String {
        switch tracker.phase {
        case .sitting, .paused: return Format.mmss(tracker.sitRemaining)
        case .onBreak: return Format.mmss(tracker.breakRemaining)
        }
    }

    private var subText: String {
        switch tracker.phase {
        case .sitting: return tracker.snoozeCount > 0 ? "已赖床 \(tracker.snoozeCount) 次" : "距离起身"
        case .onBreak: return "休息中 · 动一动"
        case .paused: return "已暂停"
        }
    }

    var body: some View {
        // 圆环和中间的大数字一致：都显示剩余时间，像厨房计时器一样越用越少
        let p = 1 - tracker.progress
        ZStack {
            Canvas { g, size in
                RingDrawing.draw(g, size: size, progress: p, color: ringColor, lineWidth: 3.4, seed: 4242)
            }
            VStack(spacing: 0) {
                Text(mainText)
                    .font(Hand.font(42, bold: true))
                    .foregroundStyle(ringColor == Ink.pencil ? Ink.pencil : Ink.blue)
                    .monospacedDigit()
                Text(subText)
                    .font(Hand.font(13.5))
                    .foregroundStyle(tracker.snoozeCount > 0 && tracker.phase == .sitting ? Ink.red : Ink.pencil)
            }
        }
        .frame(width: 176, height: 176)
    }
}

/// 设置里的"－ 45 分钟 ＋"
struct HandStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Hand.font(14))
                .foregroundStyle(Ink.blue)
            Spacer()
            RoundInk(symbol: "−", seed: SketchCore.hash(title + "-")) {
                value = max(range.lowerBound, value - step)
            }
            .opacity(value <= range.lowerBound ? 0.35 : 1)
            Text("\(value) \(unit)")
                .font(Hand.font(14, bold: true))
                .foregroundStyle(Ink.red)
                .frame(minWidth: 62)
            RoundInk(symbol: "+", seed: SketchCore.hash(title + "+")) {
                value = min(range.upperBound, value + step)
            }
            .opacity(value >= range.upperBound ? 0.35 : 1)
        }
    }
}

private struct RoundInk: View {
    let symbol: String
    let seed: UInt64
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(Hand.font(15, bold: true))
                .foregroundStyle(Ink.blue)
                .frame(width: 24, height: 24)
                .background(Canvas { g, size in
                    g.ink(Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)),
                          width: 1.1, seed: seed, wobble: 0.6, overshoot: 0.15, passes: 1)
                })
                .contentShape(Circle())
                .scaleEffect(hovered ? 1.12 : 1)
                .animation(.spring(duration: 0.2), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// 手画勾选框
struct HandCheckbox: View {
    let title: String
    let hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Canvas { g, size in
                    let seed = SketchCore.hash(title)
                    let r = CGRect(origin: .zero, size: size).insetBy(dx: 7, dy: 7)
                    g.ink(Path(r), width: 1.2, seed: seed, wobble: 0.6, overshoot: 0.1, passes: 1)
                    if isOn {
                        var p = Path()
                        p.move(to: CGPoint(x: r.minX + 2, y: r.midY))
                        p.addLine(to: CGPoint(x: r.midX - 1, y: r.maxY - 1))
                        p.addLine(to: CGPoint(x: r.maxX + 5, y: r.minY - 5.5))
                        g.ink(p, color: Ink.red, width: 2, seed: seed &+ 1, wobble: 0.6, overshoot: 0)
                    }
                }
                .frame(width: 28, height: 28)
                .padding(-4)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(Hand.font(14)).foregroundStyle(Ink.blue)
                    if let hint {
                        Text(hint).font(Hand.font(11)).foregroundStyle(Ink.pencil)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
