import Foundation

enum DocumentImportMode: String, Codable, CaseIterable, Sendable {
    case manual
    case smartPack
    case autoTopUp
}

enum AutoImportTrigger: String, Sendable {
    case appLaunch
    case libraryEntry
    case backgroundRefresh
}

enum AutoImportSettings {
    static let autoTopUpEnabledKey = "auto_import.enabled.v1"
    static let backgroundRefreshEnabledKey = "auto_import.background_refresh_enabled.v1"
    static let lastAutoTopUpAttemptAtKey = "auto_import.last_attempt_at.v1"
    static let lastAutoTopUpSuccessAtKey = "auto_import.last_success_at.v1"
    static let lastAutoTopUpBatchIDKey = "auto_import.last_batch_id.v1"

    static let defaultAutoTopUpEnabled = true
    static let defaultBackgroundRefreshEnabled = false
    static let defaultCooldownHours = 24
    static let defaultUnreadThreshold = 3
    static let defaultPackDays = 3
    static let defaultLessonsPerDay = 2
    static let defaultValidationBudget = 30
    static let defaultValidationConcurrency = 4

    static var smartPackTargetCount: Int {
        defaultPackDays * defaultLessonsPerDay
    }
}
