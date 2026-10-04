import Foundation

/// Stored independently of translated text, so old settings remain compatible.
enum AppLanguage: String, Codable, CaseIterable {
    case system, simplifiedChinese, english
}

enum L10n {
    static var language: AppLanguage = .system
    static var isChinese: Bool {
        switch language {
        case .simplifiedChinese: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("zh") == true
        }
    }
    static func text(_ chinese: String, _ english: String) -> String {
        isChinese ? chinese : english
    }
}
