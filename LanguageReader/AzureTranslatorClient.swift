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
        guard var components = URLComponents(
            url: configuration.endpoint.appendingPathComponent("translate"),
            resolvingAgainstBaseURL: false
        ) else {
            throw ClientError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "from", value: configuration.sourceLanguage),
            URLQueryItem(name: "to", value: configuration.targetLanguage)
        ]
        guard let url = components.url else {
            throw ClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue(configuration.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(configuration.region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
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
