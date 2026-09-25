import SwiftUI

/// 点菜单栏图标弹出的主界面：一页横线笔记本
struct MenuPopover: View {
    @EnvironmentObject var tracker: SitTracker
    @State private var showSettings: Bool
    static let height: CGFloat = 670

    init(showSettings: Bool = false) {
        _showSettings = State(initialValue: showSettings)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if showSettings {
                SettingsView()
                    .padding(.top, 4)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 4) {
                    Mascot(mood: .fresh, size: 64)
                    SpeechBubble(text: "改完记得回来看看我，也记得起来走走～")
                }
                .padding(.bottom, 6)
            } else {
                HStack(alignment: .center, spacing: 6) {
                    Mascot(mood: tracker.mood, size: 70)
                    SpeechBubble(text: tracker.quip)
                }
                RingTimer()
                caption
                statsRow
                WeekChart(days: tracker.lastSevenDays)
                    .padding(.top, 2)
                actions
                    .padding(.top, 2)
                Spacer(minLength: 0)
            }
            footer
        }
        .padding(.leading, 30)
        .padding(.trailing, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        // 固定高度：菜单栏窗口在内容高度变化时不会重新贴齐菜单栏，切到设置页会把顶部顶出屏幕
        .frame(width: 340, height: Self.height, alignment: .top)
        .background(PaperBackground(lineSpacing: 26, firstLine: 44, marginX: 20))
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Doodle Break")
                .font(Hand.latin(19))
                .foregroundStyle(Ink.blue)
            Spacer()
            Text(Format.notebookDate.string(from: Date()))
                .font(Hand.font(12.5))
                .foregroundStyle(Ink.pencil)
        }
    }

    private var caption: some View {
        Group {
            switch tracker.phase {
            case .sitting:
                Text("已坐 \(Format.minutes(tracker.sitElapsed)) · 预计 \(Format.clock.string(from: tracker.expectedBreakAt)) 喊你起来")
            case .onBreak:
                Text("刚才坐了 \(Format.minutes(tracker.lastSitLength))。\(tracker.stretch.text)")
            case .paused:
                Text("暂停期间不计时，回来记得点「继续」")
            }
        }
        .font(Hand.font(13))
        .foregroundStyle(Ink.pencil)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(tracker.stats.standUps)", label: "今日起身", tilt: -1.2)
            StatTile(value: "\(tracker.stats.snoozes)", label: "今日赖床", tilt: 0.8)
            StatTile(value: Format.shortMinutes(tracker.stats.longestSitSeconds), label: "最长连坐", tilt: -0.5)
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 10) {
            switch tracker.phase {
            case .sitting:
                InkButton(title: "现在休息", kind: .primary, size: 14) { tracker.beginBreak() }
                InkButton(title: "暂停", size: 14) { tracker.pause() }
                InkButton(title: "刚动过", size: 14) { tracker.resetSit() }
            case .onBreak:
                InkButton(title: "动完啦", kind: .primary, size: 14) { tracker.finishBreak(early: true) }
                InkButton(title: Copy.snoozeLabel(count: tracker.snoozeCount, minutes: tracker.settings.snoozeMinutes),
                          size: 14) { tracker.snooze() }
            case .paused:
                InkButton(title: "继续", kind: .primary, size: 14) { tracker.resume() }
                InkButton(title: "重新计时", size: 14) { tracker.resetSit() }
            }
        }
    }

    private var footer: some View {
        HStack {
            InkButton(title: showSettings ? "← 返回" : "设置", kind: .quiet, size: 13) { showSettings.toggle() }
            Spacer()
            Text("坐久了，起来走走")
                .font(Hand.font(11))
                .foregroundStyle(Ink.pencil.opacity(0.6))
            Spacer()
            InkButton(title: "退出", kind: .quiet, size: 13) { NSApp.terminate(nil) }
        }
        .padding(.top, 4)
    }
}

struct SettingsView: View {
    @EnvironmentObject var tracker: SitTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(Hand.title(20))
                .foregroundStyle(Ink.blue)
                .padding(.horizontal, 6)
                .background(Highlight(seed: 31).padding(.horizontal, -4))
            HandStepper(title: "每坐多久提醒", value: $tracker.settings.sitMinutes, range: 10...120, step: 5, unit: "分钟")
            HandStepper(title: "每次休息多久", value: $tracker.settings.breakMinutes, range: 1...15, step: 1, unit: "分钟")
            HandStepper(title: "锁屏/睡眠多久算起身", value: $tracker.settings.idleMinutes, range: 2...15, step: 1, unit: "分钟")
            HandStepper(title: "赖床一次延后", value: $tracker.settings.snoozeMinutes, range: 3...15, step: 1, unit: "分钟")
            Squiggle(seed: 77, color: Ink.pencil.opacity(0.6), width: 0.9)
                .frame(height: 6)
                .padding(.vertical, 2)
            HandCheckbox(title: "全屏休息提醒", hint: "不勾就只发系统通知", isOn: $tracker.settings.overlayEnabled)
            HandCheckbox(title: "提示音", hint: nil, isOn: $tracker.settings.soundEnabled)
            HandCheckbox(title: "菜单栏显示倒计时", hint: nil, isOn: $tracker.settings.showTimeInMenuBar)
            HandCheckbox(title: "开机自动启动", hint: "建议先把 App 放进「应用程序」文件夹",
                         isOn: Binding(get: { tracker.launchAtLogin }, set: { tracker.setLaunchAtLogin($0) }))
        }
    }
}
