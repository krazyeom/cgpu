import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case en = "en"
    case ko = "ko"
    
    public var displayName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        }
    }
    
    public var toggleTargetName: String {
        switch self {
        case .en: return "KO"
        case .ko: return "EN"
        }
    }
}

public struct L10n {
    public static func tr(_ en: String, _ ko: String, for lang: AppLanguage) -> String {
        return lang == .en ? en : ko
    }
}
