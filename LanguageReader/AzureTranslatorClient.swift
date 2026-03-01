import Foundation

protocol AzureSentenceTranslating {
    func translate(text: String, configuration: AzureTranslatorConfiguration) async throws -> String
}

struct AzureTranslatorClient: AzureSentenceTranslating {
    enum ClientError: Error, LocalizedError {
        case invalidEndpoint
        case invalidResponse
        case emptyResponse
        case serviceError(String)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Invalid translator endpoint."
            case .invalidResponse:
                return "Unexpected translator response."
            case .emptyResponse:
                return "Translator returned an empty response."
            case .serviceError(let message):
                return message
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(text: String, configuration: AzureTranslatorConfiguration) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClientError.emptyResponse
        }

        do {
            let translated = try await performTranslation(
                text: trimmed,
                configuration: configuration,
                sourceLanguage: normalizedLanguageCode(configuration.sourceLanguage)
            )

            if shouldRetryWithAutoDetect(
                sourceText: trimmed,
                translatedText: translated,
                configuration: configuration
            ) {
                return try await performTranslation(
                    text: trimmed,
                    configuration: configuration,
                    sourceLanguage: nil
                )
            }

            return translated
        } catch let error as ClientError where shouldRetryWithoutSource(error, configuration: configuration) {
            return try await performTranslation(
                text: trimmed,
                configuration: configuration,
                sourceLanguage: nil
            )
        }
    }

    private func performTranslation(
        text: String,
        configuration: AzureTranslatorConfiguration,
        sourceLanguage: String?
    ) async throws -> String {
        guard var components = URLComponents(
            url: configuration.endpoint.appendingPathComponent("translate"),
            resolvingAgainstBaseURL: false
        ) else {
            throw ClientError.invalidEndpoint
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
            throw ClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue(configuration.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        if let region = configuration.region, !region.isEmpty {
            request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([TranslateRequestBody(text: text)])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = parseServiceError(data: data) {
                throw ClientError.serviceError(message)
            }
            throw ClientError.serviceError("Translation request failed (\(httpResponse.statusCode)).")
        }

        let translated = try parseTranslation(data: data)
        guard !translated.isEmpty else {
            throw ClientError.emptyResponse
        }
        return translated
    }

    private func normalizedLanguageCode(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func shouldRetryWithoutSource(
        _ error: ClientError,
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
        sourceText: String,
        translatedText: String,
        configuration: AzureTranslatorConfiguration
    ) -> Bool {
        guard normalizedLanguageCode(configuration.sourceLanguage) != nil else {
            return false
        }

        guard configuration.sourceLanguage.caseInsensitiveCompare(configuration.targetLanguage) != .orderedSame else {
            return false
        }

        guard sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(translatedText.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame else {
            return false
        }

        return containsKannadaScript(in: sourceText)
    }

    private func containsKannadaScript(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0C80...0x0CFF).contains(Int(scalar.value))
        }
    }

    func parseTranslation(data: Data) throws -> String {
        let items = try JSONDecoder().decode([TranslateResponseBody].self, from: data)
        guard let first = items.first, let translation = first.translations.first?.text else {
            throw ClientError.emptyResponse
        }
        return translation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parseServiceError(data: Data) -> String? {
        guard
            let payload = try? JSONDecoder().decode(TranslateErrorPayload.self, from: data),
            !payload.error.message.isEmpty
        else {
            return nil
        }
        return payload.error.message
    }
}

private struct TranslateRequestBody: Encodable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case text = "Text"
    }
}

private struct TranslateResponseBody: Decodable {
    let translations: [TranslateResponseText]
}

private struct TranslateResponseText: Decodable {
    let text: String
}

private struct TranslateErrorPayload: Decodable {
    let error: TranslateErrorDetail
}

private struct TranslateErrorDetail: Decodable {
    let code: Int
    let message: String
}
