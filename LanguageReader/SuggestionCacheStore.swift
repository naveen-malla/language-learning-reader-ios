import Foundation

actor SuggestionCacheStore {
    struct TrustedChannel: Codable, Sendable {
        let channelID: String
        let channelTitle: String?
        let discoveredAt: Date
    }

    private enum ValidationStatus: String, Codable, Sendable {
        case valid
        case invalid
    }

    private struct CachedSuggestion: Codable, Sendable {
        let videoID: String
        let title: String
        let channelTitle: String
        let channelID: String?
        let category: String
        let durationSeconds: Int
        let thumbnailURLString: String?
        let publishedAt: Date?
    }

    private struct ValidationRecord: Codable, Sendable {
        let status: ValidationStatus
        let checkedAt: Date
        let suggestion: CachedSuggestion?
    }

    private struct State: Codable, Sendable {
        var cachedSuggestions: [CachedSuggestion]
        var lastRefreshAt: Date?
        var validations: [String: ValidationRecord]
        var consecutiveDiscoveryFailures: Int
        var nextRetryAt: Date?
        var trustedChannels: [TrustedChannel]

        static let empty = State(
            cachedSuggestions: [],
            lastRefreshAt: nil,
            validations: [:],
            consecutiveDiscoveryFailures: 0,
            nextRetryAt: nil,
            trustedChannels: []
        )
    }

    private struct StoredState: Codable, Sendable {
        var states: [String: State]

        static let empty = StoredState(states: [:])
    }

    static let shared = SuggestionCacheStore()

    private let defaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date
    private var storedState: StoredState

    private let suggestionCacheTTL: TimeInterval = 8 * 60 * 60
    private let validationSuccessTTL: TimeInterval = 24 * 60 * 60
    private let validationFailureTTL: TimeInterval = 12 * 60 * 60

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "youtube.discovery.cache.v1",
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(StoredState.self, from: data) {
            self.storedState = decoded
        } else if let data = defaults.data(forKey: storageKey),
                  let legacyState = try? JSONDecoder().decode(State.self, from: data) {
            self.storedState = StoredState(states: [SupportedLanguage.legacyDefault.rawValue: legacyState])
        } else {
            self.storedState = .empty
        }
    }

    func clear() {
        storedState = .empty
        defaults.removeObject(forKey: storageKey)
    }

    func cachedSuggestions(
        language: SupportedLanguage = .legacyDefault,
        includeExpired: Bool = false
    ) -> [YouTubeSuggestedVideo] {
        let state = state(for: language)
        let current = now()
        if !includeExpired,
           let lastRefreshAt = state.lastRefreshAt,
           current.timeIntervalSince(lastRefreshAt) > suggestionCacheTTL {
            return []
        }

        return state.cachedSuggestions.compactMap(Self.materializeSuggestion)
    }

    func cachedValidation(
        for videoID: String,
        language: SupportedLanguage = .legacyDefault
    ) -> YouTubeSuggestedVideo?? {
        let state = state(for: language)
        guard let record = state.validations[videoID] else {
            return nil
        }

        let age = now().timeIntervalSince(record.checkedAt)
        switch record.status {
        case .valid:
            guard age <= validationSuccessTTL,
                  let suggestion = record.suggestion.flatMap(Self.materializeSuggestion) else {
                return nil
            }
            return .some(suggestion)
        case .invalid:
            guard age <= validationFailureTTL else {
                return nil
            }
            return .some(nil)
        }
    }

    func storeValidationSuccess(
        _ suggestion: YouTubeSuggestedVideo,
        language: SupportedLanguage = .legacyDefault
    ) {
        var state = state(for: language)
        state.validations[suggestion.videoID] = ValidationRecord(
            status: .valid,
            checkedAt: now(),
            suggestion: Self.cacheSuggestion(from: suggestion)
        )
        updateState(state, for: language)
    }

    func storeValidationFailure(
        videoID: String,
        language: SupportedLanguage = .legacyDefault
    ) {
        var state = state(for: language)
        state.validations[videoID] = ValidationRecord(
            status: .invalid,
            checkedAt: now(),
            suggestion: nil
        )
        updateState(state, for: language)
    }

    func saveSuggestions(
        _ suggestions: [YouTubeSuggestedVideo],
        language: SupportedLanguage = .legacyDefault
    ) {
        var state = state(for: language)
        state.cachedSuggestions = suggestions.map(Self.cacheSuggestion)
        state.lastRefreshAt = now()
        pruneStaleValidationRecords(&state)
        updateState(state, for: language)
    }

    func shouldBackoff(language: SupportedLanguage = .legacyDefault) -> Bool {
        let state = state(for: language)
        guard let nextRetryAt = state.nextRetryAt else { return false }
        return now() < nextRetryAt
    }

    func recordDiscoverySuccess(language: SupportedLanguage = .legacyDefault) {
        var state = state(for: language)
        state.consecutiveDiscoveryFailures = 0
        state.nextRetryAt = nil
        updateState(state, for: language)
    }

    func recordDiscoveryFailure(language: SupportedLanguage = .legacyDefault) {
        var state = state(for: language)
        state.consecutiveDiscoveryFailures += 1
        let exponent = min(state.consecutiveDiscoveryFailures, 4)
        let delayMinutes = min(80, Int(pow(2.0, Double(exponent - 1))) * 10)
        state.nextRetryAt = now().addingTimeInterval(TimeInterval(delayMinutes * 60))
        updateState(state, for: language)
    }

    func lastRefreshDate(language: SupportedLanguage = .legacyDefault) -> Date? {
        state(for: language).lastRefreshAt
    }

    func nextRetryDate(language: SupportedLanguage = .legacyDefault) -> Date? {
        state(for: language).nextRetryAt
    }

    func addTrustedChannel(
        channelID: String?,
        channelTitle: String?,
        language: SupportedLanguage = .legacyDefault
    ) {
        guard let channelID = normalizedChannelID(channelID) else { return }
        var state = state(for: language)

        if let index = state.trustedChannels.firstIndex(where: { $0.channelID == channelID }) {
            state.trustedChannels[index] = TrustedChannel(
                channelID: channelID,
                channelTitle: channelTitle ?? state.trustedChannels[index].channelTitle,
                discoveredAt: now()
            )
        } else {
            state.trustedChannels.append(
                TrustedChannel(
                    channelID: channelID,
                    channelTitle: channelTitle,
                    discoveredAt: now()
                )
            )
        }
        updateState(state, for: language)
    }

    func trustedChannelIDs(language: SupportedLanguage = .legacyDefault) -> [String] {
        state(for: language).trustedChannels.map(\.channelID)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(storedState) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func pruneStaleValidationRecords(_ state: inout State) {
        let current = now()
        state.validations = state.validations.filter { _, record in
            switch record.status {
            case .valid:
                return current.timeIntervalSince(record.checkedAt) <= validationSuccessTTL
            case .invalid:
                return current.timeIntervalSince(record.checkedAt) <= validationFailureTTL
            }
        }
    }

    private func state(for language: SupportedLanguage) -> State {
        storedState.states[language.rawValue] ?? .empty
    }

    private func updateState(_ state: State, for language: SupportedLanguage) {
        storedState.states[language.rawValue] = state
        persist()
    }

    private func normalizedChannelID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cacheSuggestion(from suggestion: YouTubeSuggestedVideo) -> CachedSuggestion {
        CachedSuggestion(
            videoID: suggestion.videoID,
            title: suggestion.title,
            channelTitle: suggestion.channelTitle,
            channelID: suggestion.channelID,
            category: suggestion.category,
            durationSeconds: suggestion.durationSeconds,
            thumbnailURLString: suggestion.thumbnailURL?.absoluteString,
            publishedAt: suggestion.publishedAt
        )
    }

    private static func materializeSuggestion(_ suggestion: CachedSuggestion) -> YouTubeSuggestedVideo? {
        let thumbnailURL = suggestion.thumbnailURLString.flatMap(URL.init(string:))
        return YouTubeSuggestedVideo(
            videoID: suggestion.videoID,
            title: suggestion.title,
            channelTitle: suggestion.channelTitle,
            channelID: suggestion.channelID,
            category: suggestion.category,
            durationSeconds: suggestion.durationSeconds,
            thumbnailURL: thumbnailURL,
            publishedAt: suggestion.publishedAt
        )
    }
}
