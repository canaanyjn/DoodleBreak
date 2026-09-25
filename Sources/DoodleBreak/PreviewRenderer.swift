import AppKit
import SwiftUI

/// `DoodleBreak --preview <目录>`：把各个界面离屏渲染成 PNG，方便不开 App 就看效果
@MainActor
enum PreviewRenderer {
    static func run(outputDir: String) {
        let dir = URL(fileURLWithPath: outputDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tracker = SitTracker.shared

        tracker.applyPreview(phase: .sitting, progress: 0.62)
        save(MenuPopover().environmentObject(tracker), "popover.png", scale: 2, dir)
        save(MenuPopover(showSettings: true).environmentObject(tracker), "popover-settings.png", scale: 2, dir)

        tracker.applyPreview(phase: .sitting, progress: 0.97, snoozes: 2)
        save(MenuPopover().environmentObject(tracker), "popover-urgent.png", scale: 2, dir)

        tracker.applyPreview(phase: .onBreak, progress: 0.3)
        save(MenuPopover().environmentObject(tracker), "popover-break.png", scale: 2, dir)

        let fakeDesktop = LinearGradient(colors: [Color(red: 0.35, green: 0.45, blue: 0.62), Color(red: 0.62, green: 0.50, blue: 0.58)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
        save(ZStack { fakeDesktop; BreakOverlayView(tracker: tracker, animateIn: false) }.frame(width: 1440, height: 900),
             "overlay.png", scale: 1, dir)

        let moods = HStack(spacing: 18) {
            ForEach(Mood.allCases, id: \.self) { m in
                VStack(spacing: 2) {
                    Mascot(mood: m, size: 100)
                    Text(m.rawValue).font(Hand.font(14)).foregroundStyle(Ink.pencil)
                }
            }
        }
        .padding(30)
        .background(PaperBackground(lineSpacing: 28, firstLine: 30, marginX: 14))
        save(moods, "moods.png", scale: 2, dir)

        let icons = HStack(spacing: 14) {
            ForEach([0.0, 0.3, 0.62, 0.95], id: \.self) { p in
                Image(nsImage: MenuBarIcon.image(progress: p, phase: .sitting))
            }
            Image(nsImage: MenuBarIcon.image(progress: 0, phase: .onBreak))
            Image(nsImage: MenuBarIcon.image(progress: 0, phase: .paused))
        }
        .padding(10)
        .background(Color.white)
        save(icons, "menubar-icons.png", scale: 6, dir)

        print("preview written to \(dir.path)")
    }

    private static func save<V: View>(_ view: V, _ name: String, scale: CGFloat, _ dir: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage else {
            print("render failed: \(name)")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: dir.appendingPathComponent(name))
    }
}
