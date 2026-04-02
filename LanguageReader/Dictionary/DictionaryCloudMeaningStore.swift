import Foundation

struct CachedWordMeaning {
    let languageCode: String
    let normalizedKey: String
    let meaning: String
    let source: String
    let updatedAt: Date
}

final class DictionaryCloudMeaningStore {
    private let fileURL: URL?
    private var entries: [String: CachedWordMeaning]
    private let queue = DispatchQueue(label: "com.languagereader.dictionary.cloud-cache", attributes: .concurrent)
    private let isoFormatter = ISO8601DateFormatter()

    init(fileURL: URL?, entries: [CachedWordMeaning] = []) {
        self.fileURL = fileURL
        self.entries = Dictionary(uniqueKeysWithValues: entries.map { (Self.makeKey(languageCode: $0.languageCode, normalizedKey: $0.normalizedKey), $0) })
        if let fileURL, self.entries.isEmpty {
            self.entries = Self.loadEntries(from: fileURL)
        }
    }

    func lookup(normalizedKey: String, languageCode: String) -> String? {
        let key = Self.makeKey(languageCode: languageCode, normalizedKey: normalizedKey)
        return queue.sync {
            entries[key]?.meaning
        }
    }

    func setMeaning(normalizedKey: String, languageCode: String, meaning: String, source: String) {
        let normalizedLanguage = Self.normalizeLanguage(languageCode)
        let normalizedWord = normalizedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedLanguage.isEmpty, !normalizedWord.isEmpty, !cleanedMeaning.isEmpty else {
            return
        }

        let key = Self.makeKey(languageCode: normalizedLanguage, normalizedKey: normalizedWord)
        let entry = CachedWordMeaning(
            languageCode: normalizedLanguage,
            normalizedKey: normalizedWord,
            meaning: cleanedMeaning.replacingOccurrences(of: "\t", with: " "),
            source: cleanedSource.isEmpty ? "cloud" : cleanedSource.replacingOccurrences(of: "\t", with: " "),
            updatedAt: Date()
        )

        queue.sync(flags: .barrier) {
            self.entries[key] = entry
            self.saveEntries()
        }
    }

    func allCount() -> Int {
        queue.sync { entries.count }
    }

    func clear() {
        queue.sync(flags: .barrier) {
            self.entries.removeAll(keepingCapacity: false)
            self.saveEntries()
        }
    }

    private func saveEntries() {
        guard let fileURL else { return }
        let lines = entries.values.sorted {
            if $0.languageCode != $1.languageCode {
                return $0.languageCode < $1.languageCode
            }
            return $0.normalizedKey < $1.normalizedKey
        }.map { entry in
            let timestamp = isoFormatter.string(from: entry.updatedAt)
            return "\(entry.languageCode)\t\(entry.normalizedKey)\t\(entry.meaning)\t\(entry.source)\t\(timestamp)"
        }

        let header = [
            "# Cloud meanings cache (TSV)",
            "# Format: language_code<TAB>normalized_key<TAB>meaning<TAB>source<TAB>updated_at_iso8601",
            ""
        ]
        let contentLines = header + lines
        let content = contentLines.joined(separator: "\n") + "\n"
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func loadEntries(from fileURL: URL) -> [String: CachedWordMeaning] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        var map: [String: CachedWordMeaning] = [:]
        let formatter = ISO8601DateFormatter()

        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 5 else { continue }

            let language = normalizeLanguage(String(parts[0]))
            let normalizedKey = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            let source = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
            let timestamp = String(parts[4]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !language.isEmpty, !normalizedKey.isEmpty, !meaning.isEmpty else {
                continue
            }

            let updatedAt = formatter.date(from: timestamp) ?? Date.distantPast
            let entry = CachedWordMeaning(
                languageCode: language,
                normalizedKey: normalizedKey,
                meaning: meaning,
                source: source.isEmpty ? "cloud" : source,
                updatedAt: updatedAt
            )

            let key = makeKey(languageCode: language, normalizedKey: normalizedKey)
            if let existing = map[key], existing.updatedAt > updatedAt {
                continue
            }
            map[key] = entry
        }

        return map
    }

    private static func makeKey(languageCode: String, normalizedKey: String) -> String {
        "\(normalizeLanguage(languageCode))|\(normalizedKey)"
    }

    private static func normalizeLanguage(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
