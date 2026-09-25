import AppKit
import SwiftUI

@main
struct DoodleBreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var tracker = SitTracker.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPopover()
                .environmentObject(tracker)
        } label: {
            MenuBarLabel(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var tracker: SitTracker

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(progress: tracker.progress, phase: tracker.phase))
            if tracker.settings.showTimeInMenuBar {
                Text(tracker.menuBarText).monospacedDigit()
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let args = CommandLine.arguments

        // 调试用：把界面渲染成 PNG 后退出
        if let i = args.firstIndex(of: "--preview"), args.count > i + 1 {
            PreviewRenderer.run(outputDir: args[i + 1])
            exit(0)
        }

        // 调试用：跑计时逻辑自测（用独立的存储，不碰真实数据）
        if args.contains("--selftest") {
            exit(SelfTest.run() ? 0 : 1)
        }

        // 调试用：2 秒后打印自己拥有的窗口（状态栏图标也是窗口）然后退出
        if args.contains("--diag") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                for w in NSApp.windows {
                    print("window: \(type(of: w)) level=\(w.level.rawValue) visible=\(w.isVisible) frame=\(w.frame)")
                }
                exit(0)
            }
        }

        Notifier.shared.setup()
        SitTracker.shared.start()

        if args.contains("--demo-break") {
            SitTracker.shared.beginBreak()
        }
    }
}
