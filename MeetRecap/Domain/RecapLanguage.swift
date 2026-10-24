import Foundation

enum RecapLanguage: String, Codable, CaseIterable, Equatable, Sendable {
    case english = "ENGLISH"
    case arabic = "ARABIC"
    case urdu = "URDU"

    var displayName: String {
        switch self {
        case .english: "English"
        case .arabic: "العربية"
        case .urdu: "اردو"
        }
    }

    var instruction: String {
        switch self {
        case .english: "English"
        case .arabic: "Arabic"
        case .urdu: "Urdu"
        }
    }

    var isRtl: Bool {
        self != .english
    }
}
