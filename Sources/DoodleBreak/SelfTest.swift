import Foundation

/// `DoodleBreak --selftest`：用假时间模拟重启、锁屏、睡眠，检查计时是否符合预期
@MainActor
enum SelfTest {
    private static let suite = "com.tcn.DoodleBreak.selftest"
    private static var failures = 0

    static func run() -> Bool {
        let t0 = Date()
        let min: TimeInterval = 60

        // 用给定的存盘状态"启动"一个新的计时器
        func launch(_ st: SessionState?) -> SitTracker {
            UserDefaults().removePersistentDomain(forName: suite)
            let d = UserDefaults(suiteName: suite)!
            if let st { d.set(try! JSONEncoder().encode(st), forKey: "session") }
            let tr = SitTracker(defaults: d)
            tr.restoreSession(now: t0)
            return tr
        }
        func sitting(since: TimeInterval, alive: TimeInterval, phase: Phase = .sitting, pausedAt: Date? = nil) -> SessionState {
            SessionState(phase: phase, sitStart: t0.addingTimeInterval(-since), pausedAt: pausedAt,
                         snoozeCount: 0, extraSeconds: 0, lastSitLength: 0, lastAlive: t0.addingTimeInterval(-alive))
        }

        var tr = launch(nil)
        check("首次启动从 0 开始", tr.sitElapsed, 0)

        tr = launch(sitting(since: 20 * min, alive: 10))
        check("重启（关了 10 秒）接着算：已坐 20 分钟", tr.sitElapsed, 20 * min)
        check("重启不算起身", Double(tr.stats.standUps), 0)

        tr = launch(sitting(since: 30 * min, alive: 10 * min))
        check("关掉 10 分钟再打开：计时重置", tr.sitElapsed, 0)
        check("关掉 10 分钟再打开：算起身 1 次", Double(tr.stats.standUps), 1)

        tr = launch(sitting(since: 25 * min, alive: 5, phase: .paused, pausedAt: t0.addingTimeInterval(-5 * min)))
        check("暂停状态重启后仍是暂停", tr.phase == .paused ? 1 : 0, 1)

        tr = launch(sitting(since: 20 * min, alive: 5))
        for sec in stride(from: 1.0, through: 5 * min, by: 1) { tr.tick(now: t0.addingTimeInterval(sec)) }  // 和真实一样每秒走一下
        check("5 分钟不碰键鼠也不算离开：已坐 25 分钟", tr.sitElapsed, 25 * min)

        tr = launch(sitting(since: 20 * min, alive: 5))
        tr.awayBegan(locked: true, now: t0)
        tr.awayEnded(locked: true, now: t0.addingTimeInterval(1 * min))
        tr.tick(now: t0.addingTimeInterval(1 * min))
        check("锁屏 1 分钟：不重置，已坐 21 分钟", tr.sitElapsed, 21 * min)
        check("锁屏 1 分钟：不算起身", Double(tr.stats.standUps), 0)

        tr = launch(sitting(since: 20 * min, alive: 5))
        tr.awayBegan(locked: true, now: t0)
        tr.tick(now: t0.addingTimeInterval(3 * min))
        tr.awayEnded(locked: true, now: t0.addingTimeInterval(6 * min))
        tr.tick(now: t0.addingTimeInterval(6 * min))
        check("锁屏 6 分钟：计时重置", tr.sitElapsed, 0)
        check("锁屏 6 分钟：算起身 1 次", Double(tr.stats.standUps), 1)

        tr = launch(sitting(since: 20 * min, alive: 5))
        tr.awayBegan(locked: false, now: t0)
        tr.awayBegan(locked: true, now: t0)
        tr.awayEnded(locked: false, now: t0.addingTimeInterval(10 * min))
        check("睡眠醒来但还在锁屏界面：先不结算", Double(tr.stats.standUps), 0)
        tr.awayEnded(locked: true, now: t0.addingTimeInterval(10.5 * min))
        tr.tick(now: t0.addingTimeInterval(10.5 * min))
        check("睡 10 分钟后解锁：计时重置", tr.sitElapsed, 0)
        check("睡 10 分钟后解锁：算起身 1 次", Double(tr.stats.standUps), 1)

        tr = launch(sitting(since: 20 * min, alive: 5))
        tr.tick(now: t0)
        tr.tick(now: t0.addingTimeInterval(10 * min))
        check("没收到睡眠通知但时钟跳了 10 分钟：兜底重置", tr.sitElapsed, 0)

        tr = launch(nil)
        tr.settings.soundEnabled = false
        tr.settings.alternatingBreaks = true
        tr.settings.longBreakEvery = 3
        tr.settings.longBreakMinutes = 10
        check("交替模式从短休息开始", tr.breakDuration, 3 * min)
        for _ in 0..<2 {
            tr.applyPreview(phase: .onBreak, progress: 1)
            tr.finishBreak(early: false)
        }
        check("两次短休息后安排长休息", tr.breakDuration, 10 * min)
        let saved = SitTracker(defaults: UserDefaults(suiteName: suite)!)
        saved.restoreSession(now: Date())
        check("重启保留长休息轮次", saved.isLongBreak ? 1 : 0, 1)
        tr.applyPreview(phase: .onBreak, progress: 1)
        tr.finishBreak(early: false)
        check("长休息完成后重新从短休息开始", tr.breakDuration, 3 * min)
        tr.settings.alternatingBreaks = false
        check("固定模式保持原休息时长", tr.breakDuration, 3 * min)
        tr = launch(sitting(since: 50 * min, alive: 5))
        tr.settings.soundEnabled = false
        tr.settings.alternatingBreaks = true
        tr.settings.longBreakEvery = 2
        tr.applyPreview(phase: .onBreak, progress: 1)
        tr.finishBreak(early: false)
        tr.applyPreview(phase: .onBreak, progress: 0.2)
        let standUpsBeforeSkip = tr.stats.standUps
        let snoozesBeforeSkip = tr.stats.snoozes
        let skipAt = Date().addingTimeInterval(50 * min)
        tr.skipBreak(now: skipAt)
        check("跳过后回到计时状态", tr.phase == .sitting ? 1 : 0, 1)
        check("跳过保留累计久坐时间", tr.sitElapsed, 50 * min)
        check("跳过后等待完整提醒间隔", tr.sitRemaining, Double(tr.settings.sitMinutes) * min)
        check("跳过不增加起身次数", Double(tr.stats.standUps), Double(standUpsBeforeSkip))
        check("跳过不增加延后次数", Double(tr.stats.snoozes), Double(snoozesBeforeSkip))
        check("跳过长休息后仍应安排长休息", tr.isLongBreak ? 1 : 0, 1)
        let afterSkip = SitTracker(defaults: UserDefaults(suiteName: suite)!)
        afterSkip.restoreSession(now: skipAt.addingTimeInterval(10))
        check("重启保留跳过后的提醒时间", afterSkip.sitRemaining, Double(tr.settings.sitMinutes) * min - 10)
        check("重启保留跳过前的轮次", afterSkip.isLongBreak ? 1 : 0, 1)
        tr.tick(now: skipAt.addingTimeInterval(1))
        check("跳过后不会立即再次提醒", tr.phase == .sitting ? 1 : 0, 1)
        let remainingBefore = tr.sitRemaining
        tr.skipBreak(now: skipAt.addingTimeInterval(2))
        check("非休息状态忽略跳过操作", tr.sitRemaining, remainingBefore)

        let legacy = Data(#"{"sitMinutes":50,"breakMinutes":5,"idleMinutes":4,"snoozeMinutes":5,"soundEnabled":false,"overlayEnabled":true,"showTimeInMenuBar":true}"#.utf8)
        let oldSettings = try? JSONDecoder().decode(Settings.self, from: legacy)
        check("兼容旧设置并保留原间隔", Double(oldSettings?.sitMinutes ?? 0), 50)

        UserDefaults().removePersistentDomain(forName: suite)
        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        return failures == 0
    }

    private static func check(_ name: String, _ got: Double, _ want: Double) {
        let ok = abs(got - want) < 0.5
        if !ok { failures += 1 }
        print("\(ok ? "PASS" : "FAIL")  \(name)\(ok ? "" : "（得到 \(got)，期望 \(want)）")")
    }
}
