import Foundation

struct DictionaryLookupResult {
    enum Path: String {
        case override
        case direct
        case suffix
        case redirect
        case none

        var displayName: String {
            switch self {
            case .override:
                return "Override"
            case .direct:
                return "Direct"
            case .suffix:
                return "Suffix"
            case .redirect:
                return "Redirect"
            case .none:
                return "None"
            }
        }
    }

    let word: String
    let normalizedKey: String
    let matchedKey: String?
    let meaning: String?
    let path: Path
}
