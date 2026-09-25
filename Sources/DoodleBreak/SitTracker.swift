import AppKit
import Combine
import ServiceManagement

enum Phase: String, Codable {
    case sitting   // 坐着，倒计时中
    case onBreak   // 休息中
    case paused    // 用户手动暂停（开会/午休）
}

/// 吉祥物的心情，由坐了多久决定
enum Mood: String, CaseIterable, Hashable {
    case fresh, okay, tired, urgent, stretching, sleeping
}

struct Settings: Codable, Equatable {
    var sitMinutes = 45          // 坐多久提醒
    var breakMinutes = 3         // 休息多久
    var idleMinutes = 4          // 锁屏 / 睡眠多久算起身过
    var snoozeMinutes = 5        // 赖床一次延后多久
    var soundEnabled = true
    var overlayEnabled = true    // 全屏提醒；关掉则只发系统通知
    var showTimeInMenuBar = true
}

/// 当前这一轮的计时状态，存盘后 App 重启也能接着算
struct SessionState: Codable {
    var phase: Phase
    var sitStart: Date
    var pausedAt: Date?
    var snoozeCount: Int
    var extraSeconds: TimeInterval
    var lastSitLength: TimeInterval
    var lastAlive: Date   // App 最后一次确认自己活着的时间
}

struct DailyStats: Codable, Equatable {
    var day: String
    var standUps = 0
    var snoozes = 0
    var autoResets = 0                    // 靠"离开检测"自动记录的起身次数
    var longestSitSeconds: Double = 0
    var totalSitSeconds: Double = 0
}

@MainActor
final class SitTracker: ObservableObject {
    static let shared = SitTracker()

    /// 调试加速：设置环境变量 DOODLE_FAST=1 后，1 秒 = 1 分钟，且用独立的偏好存储，不污染正式数据
    static let speed: Double = ProcessInfo.processInfo.environment["DOODLE_FAST"] != nil ? 60 : 1
    static let isFast = speed > 1
    /// 坐够这么久（以"应用内秒"计）才算一次真正的起身
    static let minCountedSit: TimeInterval = 5 * 60

    @Published private(set) var phase: Phase = .sitting
    @Published private(set) var sitElapsed: TimeInterval = 0
    @Published private(set) var breakElapsed: TimeInterval = 0
    @Published private(set) var snoozeCount = 0
    @Published private(set) var extraSeconds: TimeInterval = 0
    @Published private(set) var lastSitLength: TimeInterval = 0
    @Published private(set) var stats: DailyStats
    @Published private(set) var history: [String: Int]
    @Published private(set) var quip: String = ""
    @Published private(set) var stretch: Stretch = Copy.stretches[0]
    @Published private(set) var breakTitle: String = Copy.breakTitles[0]
    @Published private(set) var launchAtLogin = false
    @Published var settings: Settings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private var timer: Timer?
    private var sitStart = Date()
    private var breakStart = Date()
    private var pausedAt: Date?
    private var lastTick = Date()
    // 离开判定只看两件事：屏幕锁了、电脑睡了
    private var isLocked = false
    private var isAsleep = false
    private var awaySince: Date?
    private var lastAwayHandledAt = Date.distantPast
    private var ticksSinceSave = 0
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var lastQuipAt = Date.distantPast
    private var lastQuipMood: Mood?

    init(defaults custom: UserDefaults? = nil) {
        defaults = custom ?? (Self.isFast ? UserDefaults(suiteName: "com.tcn.DoodleBreak.debug")! : .standard)
        settings = Self.load("settings", from: defaults) ?? Settings()
        stats = Self.load("stats", from: defaults) ?? DailyStats(day: Self.dayKey())
        history = Self.load("history", from: defaults) ?? [:]
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshQuip(force: true)
    }

    // MARK: - 派生状态

    var sitDuration: TimeInterval { Double(settings.sitMinutes) * 60 + extraSeconds }
    var breakDuration: TimeInterval { Double(settings.breakMinutes) * 60 }
    var sitRemaining: TimeInterval { max(0, sitDuration - sitElapsed) }
    var breakRemaining: TimeInterval { max(0, breakDuration - breakElapsed) }
    /// 锁屏 / 睡眠超过这么久（真实秒）才算起身过
    var idleThreshold: TimeInterval { Double(settings.idleMinutes) * 60 / Self.speed }

    var progress: Double {
        switch phase {
        case .sitting, .paused: return sitDuration > 0 ? min(1, sitElapsed / sitDuration) : 0
        case .onBreak: return breakDuration > 0 ? min(1, breakElapsed / breakDuration) : 0
        }
    }

    var mood: Mood {
        switch phase {
        case .paused: return .sleeping
        case .onBreak: return .stretching
        case .sitting:
            let p = progress
            if p < 0.4 { return .fresh }
            if p < 0.72 { return .okay }
            if p < 0.95 { return .tired }
            return .urgent
        }
    }

    var menuBarText: String {
        switch phase {
        case .sitting:
            let m = Int((sitRemaining / 60).rounded(.up))
            return m <= 0 ? "起身!" : "\(m)m"
        case .onBreak: return "休息 " + Format.mmss(breakRemaining)
        case .paused: return "暂停"
        }
    }

    /// 预计提醒时刻（真实时间）
    var expectedBreakAt: Date { Date().addingTimeInterval(sitRemaining / Self.speed) }

    /// 最近 7 天的起身次数，用于小柱状图
    var lastSevenDays: [(label: String, count: Int, isToday: Bool)] {
        let cal = Calendar.current
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        return (0..<7).reversed().map { back in
            let date = cal.date(byAdding: .day, value: -back, to: Date())!
            let key = Self.dayKey(date)
            let count = back == 0 ? stats.standUps : (history[key] ?? 0)
            return (labels[cal.component(.weekday, from: date) - 1], count, back == 0)
        }
    }

    // MARK: - 生命周期

    func start() {
        guard timer == nil else { return }
        let now = Date()
        restoreSession(now: now)
        lastTick = now
        observeAway()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - 重启续算

    func saveSession(now: Date = Date()) {
        let state = SessionState(phase: phase, sitStart: sitStart, pausedAt: pausedAt, snoozeCount: snoozeCount,
                                 extraSeconds: extraSeconds, lastSitLength: lastSitLength, lastAlive: now)
        Self.save(state, "session", to: defaults)
    }

    /// 启动时接上次的进度：关掉的时间不到阈值就接着算，超过就当你起来过了
    func restoreSession(now: Date) {
        defer { saveSession(now: now) }
        guard let st: SessionState = Self.load("session", from: defaults), st.sitStart <= now else {
            sitStart = now
            return
        }
        let offFor = now.timeIntervalSince(st.lastAlive)
        snoozeCount = st.snoozeCount
        extraSeconds = st.extraSeconds
        lastSitLength = st.lastSitLength

        if offFor >= idleThreshold {
            // App 没在运行的这段时间足够长（多半是关机 / 睡眠 / 退出后离开了），算起身
            if st.phase == .sitting {
                let length = max(0, st.lastAlive.timeIntervalSince(st.sitStart) * Self.speed)
                endSit(length: length, countsAsStandUp: length >= Self.minCountedSit, auto: true)
            } else if st.phase == .onBreak {
                endSit(length: st.lastSitLength, countsAsStandUp: true, auto: false)
            }
            snoozeCount = 0
            extraSeconds = 0
            phase = .sitting
            sitStart = now
            announce("你离开了 \(Format.minutes(offFor * Self.speed))，计时已重置")
            return
        }

        switch st.phase {
        case .sitting:
            phase = .sitting
            sitStart = st.sitStart
        case .paused:
            phase = .paused
            sitStart = st.sitStart
            pausedAt = st.pausedAt ?? st.lastAlive
        case .onBreak:
            // 休息到一半重启：算这次休息完成了
            endSit(length: st.lastSitLength, countsAsStandUp: true, auto: false)
            phase = .sitting
            sitStart = now
        }
        sitElapsed = max(0, now.timeIntervalSince(sitStart) * Self.speed)
        refreshQuip(force: true)
    }

    // MARK: - 离开检测：锁屏 + 睡眠

    private func observeAway() {
        let dnc = DistributedNotificationCenter.default()
        let ws = NSWorkspace.shared.notificationCenter
        func on(_ c: NotificationCenter, _ name: String, _ block: @escaping @MainActor (SitTracker) -> Void) {
            let o = c.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if let self { block(self) } }
            }
            observers.append((c, o))
        }
        on(dnc, "com.apple.screenIsLocked") { $0.awayBegan(locked: true) }
        on(dnc, "com.apple.screenIsUnlocked") { $0.awayEnded(locked: true) }
        on(ws, NSWorkspace.willSleepNotification.rawValue) { $0.awayBegan(locked: false) }
        on(ws, NSWorkspace.didWakeNotification.rawValue) { $0.awayEnded(locked: false) }
        on(NotificationCenter.default, NSApplication.willTerminateNotification.rawValue) { $0.saveSession() }
    }

    func awayBegan(locked: Bool, now: Date = Date()) {
        if locked { isLocked = true } else { isAsleep = true }
        if awaySince == nil { awaySince = now }
        saveSession(now: now)
    }

    func awayEnded(locked: Bool, now: Date = Date()) {
        if locked { isLocked = false } else { isAsleep = false }
        guard !isLocked, !isAsleep, let since = awaySince else { return }
        awaySince = nil
        handleReturn(awayFrom: since, now: now)
    }

    /// 回到电脑前：离开够久就算起身，不够就当没发生
    private func handleReturn(awayFrom since: Date, now: Date) {
        lastAwayHandledAt = now
        lastTick = now
        let awayFor = now.timeIntervalSince(since)
        guard awayFor >= idleThreshold else { return }
        switch phase {
        case .sitting:
            let length = max(0, since.timeIntervalSince(sitStart) * Self.speed)
            endSit(length: length, countsAsStandUp: length >= Self.minCountedSit, auto: true)
            sitStart = now
            sitElapsed = 0
            announce("欢迎回来！你离开了 \(Format.minutes(awayFor * Self.speed))，计时已重置")
        case .onBreak:
            finishBreak(early: true)
        case .paused:
            break
        }
        saveSession(now: now)
    }

    func tick(now: Date = Date()) {
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now
        rolloverDayIfNeeded()

        // 兜底：没收到睡眠通知但时钟跳了一大截，也按"睡过了"处理
        if gap >= idleThreshold + 1, awaySince == nil, now.timeIntervalSince(lastAwayHandledAt) > 10 {
            handleReturn(awayFrom: now.addingTimeInterval(-gap), now: now)
        }

        switch phase {
        case .sitting:
            sitElapsed = max(0, now.timeIntervalSince(sitStart) * Self.speed)
            // 锁屏 / 睡眠中不弹提醒，等你回来再说
            if awaySince == nil && sitElapsed >= sitDuration { beginBreak() }

        case .onBreak:
            breakElapsed = now.timeIntervalSince(breakStart) * Self.speed
            if breakElapsed >= breakDuration { finishBreak(early: false) }

        case .paused:
            break
        }
        ticksSinceSave += 1
        if ticksSinceSave >= 15 {
            ticksSinceSave = 0
            saveSession(now: now)
        }
        refreshQuip(force: false)
    }

    // MARK: - 用户操作

    func beginBreak() {
        guard phase != .onBreak else { return }
        if phase == .paused { pausedAt = nil }
        lastSitLength = sitElapsed
        phase = .onBreak
        breakStart = Date()
        breakElapsed = 0
        stretch = Copy.stretches.randomElement(excluding: stretch) ?? Copy.stretches[0]
        breakTitle = Copy.breakTitles.randomElement(excluding: breakTitle) ?? Copy.breakTitles[0]
        if settings.soundEnabled { Sounds.play("Glass") }
        if settings.overlayEnabled {
            OverlayController.shared.show(tracker: self)
        } else {
            Notifier.shared.notify(title: breakTitle,
                                   body: "你已经坐了 \(Format.minutes(lastSitLength))。\(stretch.text)")
        }
        saveSession()
        refreshQuip(force: true)
    }

    func finishBreak(early: Bool) {
        guard phase == .onBreak else { return }
        OverlayController.shared.hide()
        endSit(length: lastSitLength, countsAsStandUp: true, auto: false)
        phase = .sitting
        let now = Date()
        sitStart = now
        sitElapsed = 0
        breakElapsed = 0
        saveSession(now: now)
        if settings.soundEnabled { Sounds.play("Pop") }
        announce(early ? "动完啦？真棒，新一轮开始" : "休息结束，欢迎回来")
    }

    func snooze() {
        guard phase == .onBreak else { return }
        OverlayController.shared.hide()
        snoozeCount += 1
        stats.snoozes += 1
        persist()
        phase = .sitting
        sitElapsed = Date().timeIntervalSince(sitStart) * Self.speed
        let base = Double(settings.sitMinutes) * 60
        extraSeconds = max(0, sitElapsed + Double(settings.snoozeMinutes) * 60 - base)
        saveSession()
        announce(Copy.snoozeQuip(count: snoozeCount, minutes: settings.snoozeMinutes))
    }

    func shuffleStretch() {
        stretch = Copy.stretches.randomElement(excluding: stretch) ?? stretch
    }

    func pause() {
        guard phase == .sitting else { return }
        pausedAt = Date()
        phase = .paused
        saveSession()
        refreshQuip(force: true)
    }

    func resume() {
        guard phase == .paused, let p = pausedAt else { return }
        let now = Date()
        sitStart = sitStart.addingTimeInterval(now.timeIntervalSince(p))
        pausedAt = nil
        lastTick = now
        phase = .sitting
        saveSession(now: now)
        refreshQuip(force: true)
    }

    /// "我刚活动过"：重新计时
    func resetSit() {
        if phase == .onBreak { OverlayController.shared.hide() }
        pausedAt = nil
        let length = phase == .onBreak ? lastSitLength : sitElapsed
        endSit(length: length, countsAsStandUp: length >= Self.minCountedSit, auto: false)
        phase = .sitting
        sitStart = Date()
        lastTick = sitStart
        sitElapsed = 0
        breakElapsed = 0
        saveSession()
        announce("好嘞，重新计时")
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            announce("开机启动设置失败：\(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// 仅供 --preview 渲染截图使用
    func applyPreview(phase: Phase, progress: Double, snoozes: Int = 0) {
        self.phase = phase
        snoozeCount = snoozes
        extraSeconds = 0
        switch phase {
        case .sitting, .paused:
            sitElapsed = sitDuration * progress
        case .onBreak:
            breakElapsed = breakDuration * progress
            lastSitLength = 47 * 60
        }
        stats = DailyStats(day: Self.dayKey(), standUps: 5, snoozes: 2, autoResets: 1,
                           longestSitSeconds: 52 * 60, totalSitSeconds: 4 * 3600)
        let cal = Calendar.current
        history = Dictionary(uniqueKeysWithValues: (1...6).map { back in
            (Self.dayKey(cal.date(byAdding: .day, value: -back, to: Date())!), [3, 7, 4, 6, 2, 8][back - 1])
        })
        refreshQuip(force: true)
    }

    // MARK: - 内部

    private func endSit(length: TimeInterval, countsAsStandUp: Bool, auto: Bool) {
        stats.totalSitSeconds += length
        stats.longestSitSeconds = max(stats.longestSitSeconds, length)
        if countsAsStandUp {
            stats.standUps += 1
            if auto { stats.autoResets += 1 }
        }
        snoozeCount = 0
        extraSeconds = 0
        persist()
    }

    private func announce(_ text: String) {
        quip = text
        lastQuipAt = Date()
        lastQuipMood = nil
    }

    private func refreshQuip(force: Bool) {
        let now = Date()
        let m = mood
        let since = now.timeIntervalSince(lastQuipAt)
        guard force || (m != lastQuipMood && since > 20) || since > 180 else { return }
        quip = Copy.quips(for: m, snoozeCount: snoozeCount).randomElement(excluding: quip) ?? quip
        lastQuipMood = m
        lastQuipAt = now
    }

    private func rolloverDayIfNeeded() {
        let today = Self.dayKey()
        guard stats.day != today else { return }
        history[stats.day] = stats.standUps
        // 只保留最近 60 天
        let cutoff = Self.dayKey(Calendar.current.date(byAdding: .day, value: -60, to: Date())!)
        history = history.filter { $0.key >= cutoff }
        stats = DailyStats(day: today)
        persist()
    }

    private func persist() {
        Self.save(settings, "settings", to: defaults)
        Self.save(stats, "stats", to: defaults)
        Self.save(history, "history", to: defaults)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    private static func load<T: Decodable>(_ key: String, from d: UserDefaults) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, _ key: String, to d: UserDefaults) {
        if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) }
    }
}
