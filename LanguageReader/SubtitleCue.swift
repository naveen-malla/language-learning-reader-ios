import Foundation

struct TimedSubtitleCue: Codable, Equatable, Sendable, Identifiable {
    let startTime: Double
    let duration: Double
    let sourceText: String

    init(
        startTime: Double,
        duration: Double,
        sourceText: String
    ) {
        self.startTime = max(0, startTime)
        self.duration = max(0, duration)
        self.sourceText = sourceText
    }

    var id: String {
        "\(startTime)-\(duration)-\(sourceText)"
    }

    var endTime: Double {
        startTime + duration
    }
}

struct TranslatedSubtitleCue: Codable, Equatable, Sendable, Identifiable {
    let startTime: Double
    let duration: Double
    let translatedText: String

    init(
        startTime: Double,
        duration: Double,
        translatedText: String
    ) {
        self.startTime = max(0, startTime)
        self.duration = max(0, duration)
        self.translatedText = translatedText
    }

    var id: String {
        "\(startTime)-\(duration)-\(translatedText)"
    }

    var endTime: Double {
        startTime + duration
    }
}

enum SubtitleCueCoder {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, from rawValue: String?) -> T? {
        guard let rawValue, let data = rawValue.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }
}
