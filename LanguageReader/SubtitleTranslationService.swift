import Foundation

protocol AzureSubtitleCueTranslating {
    func translate(texts: [String], configuration: AzureTranslatorConfiguration) async throws -> [String]
}

protocol PublicSubtitleCueTranslating {
    func translate(texts: [String], sourceLanguage: String, targetLanguage: String) async throws -> [String]
}

enum SubtitleTranslationLoadResult: Equatable {
    case cached([TranslatedSubtitleCue])
    case translated([TranslatedSubtitleCue])
    case unavailable(String)
}

actor SubtitleTranslationService {
    static let unavailableMessage = "English subtitles unavailable right now."

    private let settingsStore: TranslationSettingsStore
    private let translator: AzureSubtitleCueTranslating
    private let publicTranslator: PublicSubtitleCueTranslating

    init(
        settingsStore: TranslationSettingsStore = TranslationSettingsStore(),
        translator: AzureSubtitleCueTranslating = AzureSubtitleCueTranslator(),
        publicTranslator: PublicSubtitleCueTranslating = PublicSubtitleCueTranslator()
    ) {
        self.settingsStore = settingsStore
        self.translator = translator
        self.publicTranslator = publicTranslator
    }

    func translateIfNeeded(
        sourceCues: [TimedSubtitleCue],
        cachedCues: [TranslatedSubtitleCue]?,
        sourceLanguage: String? = nil,
        targetLanguage: String = "en"
    ) async -> SubtitleTranslationLoadResult {
        guard !sourceCues.isEmpty else {
            return .unavailable(Self.unavailableMessage)
        }

        if let compatible = SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues) {
            return .cached(compatible)
        }

        let requestedSourceLanguage = LanguageTextHeuristics.canonicalLanguageCode(sourceLanguage)
        let configuredSourceLanguage = LanguageTextHeuristics.canonicalLanguageCode(settingsStore.sourceLanguage)
        let resolvedSourceLanguage = requestedSourceLanguage.isEmpty
            ? configuredSourceLanguage
            : requestedSourceLanguage
        let resolvedTargetLanguage = LanguageTextHeuristics.canonicalLanguageCode(targetLanguage)
        let resolvedTargetLanguageCode = resolvedTargetLanguage.isEmpty ? "en" : resolvedTargetLanguage

        if let configuration = settingsStore.configuration() {
            let englishConfiguration = AzureTranslatorConfiguration(
                endpoint: configuration.endpoint,
                region: configuration.region,
                apiKey: configuration.apiKey,
                sourceLanguage: resolvedSourceLanguage,
                targetLanguage: resolvedTargetLanguageCode
            )

            if let translated = await translateWithAzure(
                sourceCues: sourceCues,
                configuration: englishConfiguration,
                sourceLanguage: resolvedSourceLanguage
            ) {
                return .translated(translated)
            }
        }

        if let translated = await translateWithPublicFallback(
            sourceCues: sourceCues,
            sourceLanguage: resolvedSourceLanguage,
            targetLanguage: resolvedTargetLanguageCode
        ) {
            return .translated(translated)
        }

        return .unavailable(Self.unavailableMessage)
    }

    private func makeTranslatedCues(
        sourceCues: [TimedSubtitleCue],
        translatedTexts: [String],
        sourceLanguage: String
    ) -> [TranslatedSubtitleCue]? {
        let translatedCues = zip(sourceCues, translatedTexts).map { sourceCue, translatedText in
            let text = usableTranslation(
                translatedText,
                source: sourceCue.sourceText,
                sourceLanguage: sourceLanguage
            )
            return TranslatedSubtitleCue(
                startTime: sourceCue.startTime,
                duration: sourceCue.duration,
                translatedText: text
            )
        }

        guard translatedCues.isEmpty == false else {
            return nil
        }

        guard translatedCues.allSatisfy({ !$0.translatedText.isEmpty }) else {
            return nil
        }

        return translatedCues
    }

    private func usableTranslation(
        _ translatedText: String,
        source: String,
        sourceLanguage: String
    ) -> String {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard LanguageTextHeuristics.isReadableEnglishTranslation(
            trimmed,
            source: source,
            sourceLanguage: sourceLanguage
        ) else {
            return ""
        }

        return trimmed
    }

    private func translateWithAzure(
        sourceCues: [TimedSubtitleCue],
        configuration: AzureTranslatorConfiguration,
        sourceLanguage: String
    ) async -> [TranslatedSubtitleCue]? {
        do {
            let translatedTexts = try await translator.translate(
                texts: sourceCues.map(\.sourceText),
                configuration: configuration
            )
            guard translatedTexts.count == sourceCues.count else {
                return nil
            }

            return makeTranslatedCues(
                sourceCues: sourceCues,
                translatedTexts: translatedTexts,
                sourceLanguage: sourceLanguage
            )
        } catch {
            return nil
        }
    }

    private func translateWithPublicFallback(
        sourceCues: [TimedSubtitleCue],
        sourceLanguage: String,
        targetLanguage: String
    ) async -> [TranslatedSubtitleCue]? {
        do {
            let translatedTexts = try await publicTranslator.translate(
                texts: sourceCues.map(\.sourceText),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            guard translatedTexts.count == sourceCues.count else {
                return nil
            }

            return makeTranslatedCues(
                sourceCues: sourceCues,
                translatedTexts: translatedTexts,
                sourceLanguage: sourceLanguage
            )
        } catch {
            return nil
        }
    }
}

struct PublicSubtitleCueTranslator: PublicSubtitleCueTranslating {
    private static let maxBatchItems = 18
    private static let maxBatchCharacters = 1_600

    private let translator: PublicSentenceTranslating

    init(translator: PublicSentenceTranslating = PublicWebTranslatorClient()) {
        self.translator = translator
    }

    func translate(texts: [String], sourceLanguage: String, targetLanguage: String) async throws -> [String] {
        let trimmedTexts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !trimmedTexts.isEmpty else { return [] }

        var translated: [String] = []
        var startIndex = 0

        while startIndex < trimmedTexts.count {
            let chunk = nextChunk(from: trimmedTexts, startIndex: startIndex)
            let translatedChunk = try await translateChunk(
                Array(trimmedTexts[chunk]),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            translated.append(contentsOf: translatedChunk)
            startIndex = chunk.upperBound
        }

        return translated
    }

    private func nextChunk(from texts: [String], startIndex: Int) -> Range<Int> {
        var endIndex = startIndex
        var characterCount = 0

        while endIndex < texts.count {
            let nextCount = texts[endIndex].count
            let proposed = characterCount + nextCount

            if endIndex > startIndex,
               (endIndex - startIndex) >= Self.maxBatchItems || proposed > Self.maxBatchCharacters {
                break
            }

            characterCount = proposed
            endIndex += 1
        }

        return startIndex..<endIndex
    }

    private func translateChunk(
        _ texts: [String],
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> [String] {
        guard texts.count > 1 else {
            let translated = try await translator.translate(
                text: texts[0],
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            return [translated]
        }

        let joined = joinedChunk(texts)
        let translated = try await translator.translate(
            text: joined,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        let split = splitChunk(translated, expectedCount: texts.count)
        if split.count == texts.count {
            return split
        }

        var fallback: [String] = []
        fallback.reserveCapacity(texts.count)
        for text in texts {
            let translatedText = try await translator.translate(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            fallback.append(translatedText)
        }
        return fallback
    }

    private func joinedChunk(_ texts: [String]) -> String {
        texts.enumerated().map { index, text in
            if index == 0 {
                return text
            }
            return "\(separator(for: index))\n\(text)"
        }
        .joined(separator: "\n")
    }

    private func splitChunk(_ text: String, expectedCount: Int) -> [String] {
        var parts: [String] = [text]
        for index in 1..<expectedCount {
            let marker = separator(for: index)
            parts = parts.flatMap { segment in
                segment.components(separatedBy: marker)
            }
        }

        return parts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func separator(for index: Int) -> String {
        "__LRSEP_\(index)__"
    }
}

struct AzureSubtitleCueTranslator: AzureSubtitleCueTranslating {
    private static let maxArrayElements = 1_000
    private static let maxRequestCharacters = 45_000

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(texts: [String], configuration: AzureTranslatorConfiguration) async throws -> [String] {
        let trimmedTexts = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmedTexts.isEmpty == false else { return [] }

        var translated: [String] = []
        var startIndex = 0

        while startIndex < trimmedTexts.count {
            let chunk = nextChunk(from: trimmedTexts, startIndex: startIndex)
            let translatedChunk = try await translateChunk(
                Array(trimmedTexts[chunk.range]),
                configuration: configuration
            )
            translated.append(contentsOf: translatedChunk)
            startIndex = chunk.range.upperBound
        }

        return translated
    }

    private func nextChunk(from texts: [String], startIndex: Int) -> (range: Range<Int>, characterCount: Int) {
        var endIndex = startIndex
        var characterCount = 0

        while endIndex < texts.count {
            let nextText = texts[endIndex]
            let nextCount = nextText.count
            let nextTotal = characterCount + nextCount

            if endIndex > startIndex,
               (endIndex - startIndex) >= Self.maxArrayElements || nextTotal > Self.maxRequestCharacters {
                break
            }

            characterCount = nextTotal
            endIndex += 1
        }

        return (startIndex..<endIndex, characterCount)
    }

    private func translateChunk(
        _ texts: [String],
        configuration: AzureTranslatorConfiguration
    ) async throws -> [String] {
        do {
            let translated = try await performTranslation(
                texts: texts,
                configuration: configuration,
                sourceLanguage: normalizedLanguageCode(configuration.sourceLanguage)
            )

            if shouldRetryWithAutoDetect(
                sourceTexts: texts,
                translatedTexts: translated,
                configuration: configuration
            ) {
                return try await performTranslation(
                    texts: texts,
                    configuration: configuration,
                    sourceLanguage: nil
                )
            }

            return translated
        } catch let error as AzureTranslatorClient.ClientError where shouldRetryWithoutSource(error, configuration: configuration) {
            return try await performTranslation(
                texts: texts,
                configuration: configuration,
                sourceLanguage: nil
            )
        }
    }

    private func performTranslation(
        texts: [String],
        configuration: AzureTranslatorConfiguration,
        sourceLanguage: String?
    ) async throws -> [String] {
        guard var components = URLComponents(
            url: configuration.endpoint.appendingPathComponent("translate"),
            resolvingAgainstBaseURL: false
        ) else {
            throw AzureTranslatorClient.ClientError.invalidEndpoint
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: configuration.targetLanguage)
        ]
        if let sourceLanguage {
            queryItems.append(URLQueryItem(name: "from", value: sourceLanguage))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw AzureTranslatorClient.ClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(configuration.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        if let region = configuration.region, !region.isEmpty {
            request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(texts.map(SubtitleTranslateRequestBody.init))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureTranslatorClient.ClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = parseServiceError(data: data) {
                throw AzureTranslatorClient.ClientError.serviceError(message)
            }
            throw AzureTranslatorClient.ClientError.serviceError("Translation request failed (\(httpResponse.statusCode)).")
        }

        return try parseTranslations(data: data)
    }

    private func normalizedLanguageCode(_ value: String) -> String? {
        let canonical = LanguageTextHeuristics.canonicalLanguageCode(value)
        return canonical.isEmpty ? nil : canonical
    }

    private func shouldRetryWithoutSource(
        _ error: AzureTranslatorClient.ClientError,
        configuration: AzureTranslatorConfiguration
    ) -> Bool {
        guard normalizedLanguageCode(configuration.sourceLanguage) != nil else {
            return false
        }

        guard case .serviceError(let message) = error else {
            return false
        }

        let normalized = message.lowercased()
        if normalized.contains("(400)") || normalized.contains("failed (400)") {
            return true
        }

        if normalized.contains("source language")
            || normalized.contains("language code")
            || normalized.contains("from language")
            || normalized.contains("from parameter")
            || normalized.contains("translation from") {
            return true
        }

        return normalized.contains("from") && normalized.contains("language")
    }

    private func shouldRetryWithAutoDetect(
        sourceTexts: [String],
        translatedTexts: [String],
        configuration: AzureTranslatorConfiguration
    ) -> Bool {
        guard normalizedLanguageCode(configuration.sourceLanguage) != nil else {
            return false
        }

        let sourceContainsKannada = sourceTexts.contains { containsKannadaScript(in: $0) }
        guard sourceContainsKannada else {
            return false
        }

        let allUnchanged = zip(sourceTexts, translatedTexts).allSatisfy { sourceText, translatedText in
            sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(translatedText.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }

        return allUnchanged
    }

    private func parseTranslations(data: Data) throws -> [String] {
        let items = try JSONDecoder().decode([SubtitleTranslateResponseBody].self, from: data)
        let translations = items.map { item in
            item.translations.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        guard translations.isEmpty == false else {
            throw AzureTranslatorClient.ClientError.emptyResponse
        }
        return translations
    }

    private func parseServiceError(data: Data) -> String? {
        guard
            let payload = try? JSONDecoder().decode(SubtitleTranslateErrorPayload.self, from: data),
            !payload.error.message.isEmpty
        else {
            return nil
        }
        return payload.error.message
    }

    private func containsKannadaScript(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0C80...0x0CFF).contains(Int(scalar.value))
        }
    }
}

private struct SubtitleTranslateRequestBody: Encodable {
    let text: String

    init(text: String) {
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case text = "Text"
    }
}

private struct SubtitleTranslateResponseBody: Decodable {
    let translations: [SubtitleTranslateResponseText]
}

private struct SubtitleTranslateResponseText: Decodable {
    let text: String
}

private struct SubtitleTranslateErrorPayload: Decodable {
    let error: SubtitleTranslateErrorDetail
}

private struct SubtitleTranslateErrorDetail: Decodable {
    let code: Int
    let message: String
}
