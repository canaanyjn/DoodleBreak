import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 全屏休息提醒：每块屏幕一个无边框窗口，盖在所有东西上面
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?

    var isShowing: Bool { !windows.isEmpty }

    func show(tracker: SitTracker) {
        hide(animated: false)
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: false)
            w.level = .screenSaver
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: BreakOverlayView(tracker: tracker))
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)
        }
        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        let ws = windows
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.7
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for w in ws { w.animator().alphaValue = 1 }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak tracker] event in
            guard event.keyCode == 53 else { return event }   // Esc = 赖床
            MainActor.assumeIsolated { tracker?.snooze() }
            return nil
        }
    }

    func hide(animated: Bool = true) {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        let ws = windows
        windows = []
        guard !ws.isEmpty else { return }
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                for w in ws { w.animator().alphaValue = 0 }
            }, completionHandler: {
                Task { @MainActor in
                    for w in ws { w.orderOut(nil) }
                }
            })
        } else {
            for w in ws { w.orderOut(nil) }
        }
    }
}
