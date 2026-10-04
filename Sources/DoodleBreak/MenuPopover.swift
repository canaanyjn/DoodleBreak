import SwiftUI

/// 点菜单栏图标弹出的主界面：一页横线笔记本
struct MenuPopover: View {
    @EnvironmentObject var tracker: SitTracker
    @State private var showSettings: Bool
    static let height: CGFloat = 720

    init(showSettings: Bool = false) {
        _showSettings = State(initialValue: showSettings)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if showSettings {
                ScrollView {
                    SettingsView().padding(.top, 4).padding(.bottom, 8)
                }
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
                Text(L10n.text("已坐 \(Format.minutes(tracker.sitElapsed)) · 预计 \(Format.clock.string(from: tracker.expectedBreakAt)) \(tracker.breakKind)", "Sitting for \(Format.minutes(tracker.sitElapsed)) · \(tracker.breakKind) at \(Format.clock.string(from: tracker.expectedBreakAt))"))
            case .onBreak:
                Text(L10n.text("刚才坐了 \(Format.minutes(tracker.lastSitLength))。\(tracker.stretch.text)", "You sat for \(Format.minutes(tracker.lastSitLength)). \(tracker.stretch.text)"))
            case .paused:
                Text(L10n.text("暂停期间不计时，回来记得点「继续」", "Timer paused. Resume when you return."))
            }
        }
        .font(Hand.font(13))
        .foregroundStyle(Ink.pencil)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(tracker.stats.standUps)", label: L10n.text("今日起身", "Breaks today"), tilt: -1.2)
            StatTile(value: "\(tracker.stats.snoozes)", label: L10n.text("今日延后", "Postponed"), tilt: 0.8)
            StatTile(value: Format.shortMinutes(tracker.stats.longestSitSeconds), label: L10n.text("最长连坐", "Longest sit"), tilt: -0.5)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
        HStack(spacing: 10) {
            switch tracker.phase {
            case .sitting:
                InkButton(title: L10n.text("现在休息", "Take a break"), kind: .primary, size: 14) { tracker.beginBreak() }
                InkButton(title: L10n.text("暂停", "Pause"), size: 14) { tracker.pause() }
                InkButton(title: L10n.text("刚动过", "Just moved"), size: 14) { tracker.resetSit() }
            case .onBreak:
                InkButton(title: L10n.text("动完啦", "Done"), kind: .primary, size: 14) { tracker.finishBreak(early: true) }
                InkButton(title: Copy.snoozeLabel(count: tracker.snoozeCount, minutes: tracker.settings.snoozeMinutes),
                          size: 14) { tracker.snooze() }
            case .paused:
                InkButton(title: L10n.text("继续", "Resume"), kind: .primary, size: 14) { tracker.resume() }
                InkButton(title: L10n.text("重新计时", "Reset timer"), size: 14) { tracker.resetSit() }
            }
        }
        if tracker.phase == .onBreak {
            InkButton(title: L10n.text("跳过本次", "Skip this break"), kind: .quiet, size: 13) { tracker.skipBreak() }
                .help(L10n.text("\(tracker.settings.sitMinutes) 分钟后再提醒，不计为完成休息", "Remind again in \(tracker.settings.sitMinutes) min. Does not count as a break."))
        }
        }
    }

    private var footer: some View {
        HStack {
            InkButton(title: showSettings ? L10n.text("← 返回", "← Back") : L10n.text("设置", "Settings"), kind: .quiet, size: 13) { showSettings.toggle() }
            Spacer()
            Text(L10n.text("坐久了，起来走走", "Time to stretch"))
                .font(Hand.font(11))
                .foregroundStyle(Ink.pencil.opacity(0.6))
            Spacer()
            InkButton(title: L10n.text("退出", "Quit"), kind: .quiet, size: 13) { NSApp.terminate(nil) }
        }
        .padding(.top, 4)
    }
}

struct SettingsView: View {
    @EnvironmentObject var tracker: SitTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("设置", "Settings"))
                .font(Hand.title(20))
                .foregroundStyle(Ink.blue)
                .padding(.horizontal, 6)
                .background(Highlight(seed: 31).padding(.horizontal, -4))
            Picker(L10n.text("语言", "Language"), selection: Binding(
                get: { tracker.settings.language ?? .system },
                set: { tracker.settings.language = $0 })) {
                Text(L10n.text("跟随系统", "System default")).tag(AppLanguage.system)
                Text("简体中文").tag(AppLanguage.simplifiedChinese)
                Text("English").tag(AppLanguage.english)
            }
            .font(Hand.font(14))
            HandCheckbox(title: L10n.text("短休息与长休息交替", "Alternate short & long breaks"), hint: L10n.text("完成若干次休息后，多休息一会儿", "Take a longer break every few rounds"), isOn: Binding(
                get: { tracker.settings.alternatingBreaks == true },
                set: { tracker.settings.alternatingBreaks = $0 }))
            if tracker.settings.alternatingBreaks == true {
                HandStepper(title: L10n.text("每几轮安排长休息", "Long break every"), value: Binding(
                    get: { tracker.settings.longBreakEvery ?? 4 },
                    set: { tracker.settings.longBreakEvery = $0 }), range: 2...6, step: 1, unit: L10n.text("轮", "rounds"))
                HandStepper(title: L10n.text("长休息时长", "Long break length"), value: Binding(
                    get: { tracker.settings.longBreakMinutes ?? 10 },
                    set: { tracker.settings.longBreakMinutes = $0 }), range: 5...30, step: 1, unit: L10n.text("分钟", "min"))
                Text(L10n.text("下一次：\(tracker.breakKind) · \(Int(tracker.breakDuration / 60)) 分钟。长休息不会短于普通休息。", "Next: \(tracker.breakKind), \(Int(tracker.breakDuration / 60)) min. Never shorter than a regular break."))
                    .font(Hand.font(12)).foregroundStyle(Ink.pencil)
            }
            HandStepper(title: L10n.text("每坐多久提醒", "Remind me every"), value: $tracker.settings.sitMinutes, range: 10...120, step: 5, unit: L10n.text("分钟", "min"))
            HandStepper(title: L10n.text("每次休息多久", "Short / regular break"), value: $tracker.settings.breakMinutes, range: 1...15, step: 1, unit: L10n.text("分钟", "min"))
            HandStepper(title: L10n.text("锁屏/睡眠多久算起身", "Away time to reset"), value: $tracker.settings.idleMinutes, range: 2...15, step: 1, unit: L10n.text("分钟", "min"))
            HandStepper(title: L10n.text("稍后提醒延后", "Postpone by"), value: $tracker.settings.snoozeMinutes, range: 3...15, step: 1, unit: L10n.text("分钟", "min"))
            Squiggle(seed: 77, color: Ink.pencil.opacity(0.6), width: 0.9)
                .frame(height: 6)
                .padding(.vertical, 2)
            HandCheckbox(title: L10n.text("全屏休息提醒", "Full-screen reminders"), hint: L10n.text("不勾就只发系统通知", "Otherwise, send a notification"), isOn: $tracker.settings.overlayEnabled)
            HandCheckbox(title: L10n.text("提示音", "Sound"), hint: nil, isOn: $tracker.settings.soundEnabled)
            HandCheckbox(title: L10n.text("菜单栏显示倒计时", "Menu bar countdown"), hint: nil, isOn: $tracker.settings.showTimeInMenuBar)
            HandCheckbox(title: L10n.text("开机自动启动", "Launch at login"), hint: L10n.text("建议先把 App 放进「应用程序」文件夹", "Keep the app in Applications"),
                         isOn: Binding(get: { tracker.launchAtLogin }, set: { tracker.setLaunchAtLogin($0) }))
        }
    }
}
