import SwiftUI

/// 纸和笔的颜色
enum Ink {
    static let blue = Color(red: 0.13, green: 0.22, blue: 0.55)      // 蓝色圆珠笔
    static let red = Color(red: 0.80, green: 0.19, blue: 0.21)       // 红笔批注
    static let pencil = Color(red: 0.42, green: 0.43, blue: 0.48)    // 铅笔灰
    static let paper = Color(red: 0.988, green: 0.972, blue: 0.930)  // 米白纸
    static let paperShade = Color(red: 0.955, green: 0.935, blue: 0.885)
    static let rule = Color(red: 0.55, green: 0.70, blue: 0.88)      // 横线
    static let margin = Color(red: 0.90, green: 0.42, blue: 0.42)    // 红色页边线
    static let grain = Color(red: 0.45, green: 0.38, blue: 0.28)
    static let highlighter = Color(red: 1.0, green: 0.86, blue: 0.20)
    static let sticky = Color(red: 1.0, green: 0.925, blue: 0.56)
    static let tape = Color(red: 0.92, green: 0.89, blue: 0.80)
}

/// 手写字体：中文用翩翩体 / 手札体，英文标题用 Noteworthy
enum Hand {
    static func font(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "HanziPenSC-W5" : "HanziPenSC-W3", size: size)
    }
    static func title(_ size: CGFloat) -> Font { .custom("HannotateSC-W7", size: size) }
    static func latin(_ size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }
}

enum Format {
    static func mmss(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// "47 分钟" / "1 小时 05 分钟"
    static func minutes(_ t: TimeInterval) -> String {
        let m = max(0, Int(t / 60))
        if m < 60 { return "\(m) 分钟" }
        return "\(m / 60) 小时 \(String(format: "%02d", m % 60)) 分钟"
    }

    /// "52m" / "1h05m"
    static func shortMinutes(_ t: TimeInterval) -> String {
        let m = max(0, Int(t / 60))
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h\(String(format: "%02d", m % 60))m"
    }

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let notebookDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f
    }()
}

extension Array where Element: Equatable {
    /// 随机取一个，尽量不和上一个重复
    func randomElement(excluding last: Element?) -> Element? {
        guard count > 1, let last else { return randomElement() }
        return filter { $0 != last }.randomElement() ?? randomElement()
    }
}
