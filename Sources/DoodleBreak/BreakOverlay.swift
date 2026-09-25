import SwiftUI

/// 全屏休息：屏幕变暗，一页笔记本"啪"地贴到桌面上
struct BreakOverlayView: View {
    @ObservedObject var tracker: SitTracker
    @State private var appeared: Bool

    private let pageSize = CGSize(width: 620, height: 780)

    init(tracker: SitTracker, animateIn: Bool = true) {
        self.tracker = tracker
        _appeared = State(initialValue: !animateIn)
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(1, (geo.size.height - 60) / pageSize.height, (geo.size.width - 60) / pageSize.width)
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.13).opacity(0.62)
                page
                    .frame(width: pageSize.width, height: pageSize.height)
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 16)
                    .rotationEffect(.degrees(appeared ? -1.2 : -6))
                    .offset(y: appeared ? 0 : 80)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.35)) { appeared = true }
        }
    }

    private var page: some View {
        ZStack(alignment: .top) {
            PaperBackground(lineSpacing: 30, firstLine: 64, marginX: 54, seed: 11)
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Doodle Break")
                        .font(Hand.latin(20))
                        .foregroundStyle(Ink.blue)
                    Spacer()
                    Text("\(Format.notebookDate.string(from: Date())) · \(Format.clock.string(from: Date()))")
                        .font(Hand.font(14))
                        .foregroundStyle(Ink.pencil)
                }

                Mascot(mood: .stretching, size: 138)

                Text(tracker.breakTitle)
                    .font(Hand.title(38))
                    .foregroundStyle(Ink.blue)
                    .padding(.horizontal, 14)
                    .background(Highlight(seed: SketchCore.hash(tracker.breakTitle)).padding(.vertical, 4))

                Text("你已经连续坐了 \(Format.minutes(tracker.lastSitLength))，站起来给屁股放个假")
                    .font(Hand.font(17))
                    .foregroundStyle(Ink.pencil)

                StickyNote(text: tracker.stretch.text) { tracker.shuffleStretch() }
                    .padding(.top, 10)

                HStack(spacing: 34) {
                    BreakRing(remaining: tracker.breakRemaining, progress: tracker.progress)
                    VStack(alignment: .leading, spacing: 14) {
                        InkButton(title: "我动完啦 ✓", kind: .primary, size: 18) { tracker.finishBreak(early: true) }
                        InkButton(title: Copy.snoozeLabel(count: tracker.snoozeCount, minutes: tracker.settings.snoozeMinutes),
                                  size: 15) { tracker.snooze() }
                    }
                }
                .padding(.top, 8)

                Text("按 Esc 也能赖床，不过我会记在小本本上")
                    .font(Hand.font(13))
                    .foregroundStyle(Ink.pencil.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(.leading, 76)
            .padding(.trailing, 40)
            .padding(.top, 26)

            // 左上、右上两段胶带
            Tape(seed: 21)
                .frame(width: 120, height: 34)
                .rotationEffect(.degrees(-38))
                .offset(x: -pageSize.width / 2 + 20, y: -4)
            Tape(seed: 22)
                .frame(width: 120, height: 34)
                .rotationEffect(.degrees(36))
                .offset(x: pageSize.width / 2 - 20, y: -4)
        }
    }
}

/// 黄色便利贴，写着这次的拉伸动作
struct StickyNote: View {
    let text: String
    let onShuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("试试这个：")
                .font(Hand.font(14))
                .foregroundStyle(Ink.pencil)
            Text(text)
                .font(Hand.font(21, bold: true))
                .foregroundStyle(Ink.blue)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                InkButton(title: "换一个 ↻", kind: .quiet, size: 14, action: onShuffle)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 400, alignment: .leading)
        .background(
            Canvas { g, size in
                var rng = SeededRandom(9)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size.width, y: rng.cg(0, 2)))
                p.addLine(to: CGPoint(x: size.width - rng.cg(0, 2), y: size.height))
                p.addLine(to: CGPoint(x: rng.cg(0, 2), y: size.height - rng.cg(0, 3)))
                p.closeSubpath()
                g.fill(p, with: .color(Ink.sticky))
                // 底部一点卷边的阴影
                g.fill(Path(CGRect(x: 0, y: size.height - 10, width: size.width, height: 10)),
                       with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.05)]),
                                             startPoint: CGPoint(x: 0, y: size.height - 10),
                                             endPoint: CGPoint(x: 0, y: size.height)))
            }
            .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 5)
        )
        .overlay(alignment: .top) {
            Tape(seed: 5)
                .frame(width: 90, height: 26)
                .rotationEffect(.degrees(-3))
                .offset(y: -13)
        }
        .rotationEffect(.degrees(1.8))
        .animation(.easeInOut(duration: 0.25), value: text)
    }
}

struct BreakRing: View {
    let remaining: TimeInterval
    let progress: Double

    var body: some View {
        ZStack {
            Canvas { g, size in
                RingDrawing.draw(g, size: size, progress: 1 - progress, color: Ink.blue, lineWidth: 3.2, seed: 777)
            }
            VStack(spacing: 0) {
                Text(Format.mmss(remaining))
                    .font(Hand.font(30, bold: true))
                    .foregroundStyle(Ink.blue)
                    .monospacedDigit()
                Text("休息")
                    .font(Hand.font(12))
                    .foregroundStyle(Ink.pencil)
            }
        }
        .frame(width: 138, height: 138)
    }
}
