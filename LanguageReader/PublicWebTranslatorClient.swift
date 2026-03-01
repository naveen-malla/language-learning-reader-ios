import Foundation

protocol PublicSentenceTranslating {
    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String
}

struct PublicWebTranslatorClient: PublicSentenceTranslating {
    enum ClientError: Error {
        case invalidRequest
        case invalidResponse
        case emptyResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClientError.emptyResponse
        }

        let source = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else {
            throw ClientError.invalidRequest
        }

        guard var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else {
            throw ClientError.invalidRequest
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "sl", value: source.isEmpty ? "auto" : source),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components.url else {
            throw ClientError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClientError.invalidResponse
        }

        let translated = try parseTranslation(data: data)
        guard !translated.isEmpty else {
            throw ClientError.emptyResponse
        }
        return translated
    }

    func parseTranslation(data: Data) throws -> String {
        let payload = try JSONSerialization.jsonObject(with: data)
        guard let root = payload as? [Any], let sentenceChunks = root.first as? [Any] else {
            throw ClientError.invalidResponse
        }

        let parts = sentenceChunks.compactMap { chunk -> String? in
            guard let tuple = chunk as? [Any], let value = tuple.first as? String else { return nil }
            return value
        }

        let text = parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ClientError.emptyResponse
        }
        return text
    }
}
