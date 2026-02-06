import Foundation

final class DictionaryOverrideStore {
    private let fileURL: URL?
    private let missingURL: URL?
    private let normalizer = TextNormalizer()
    private var overrides: [String: String]

    init(fileURL: URL?, missingURL: URL?, overrides: [String: String] = [:]) {
        self.fileURL = fileURL
        self.missingURL = missingURL
        self.overrides = overrides

        if let fileURL, overrides.isEmpty {
            self.overrides = Self.loadOverrides(from: fileURL)
        }
    }

    func lookup(normalizedKey: String) -> String? {
        overrides[normalizedKey]
    }

    func setOverride(word: String, meaning: String) {
        let normalized = normalizer.normalize(word)
        overrides[normalized] = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        saveOverrides()
    }

    func ensureOverridesFile() {
        guard let fileURL else { return }
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let header = [
            "# Dictionary overrides (TSV)",
            "# Format: normalized_key<TAB>meaning",
            "# Example: ಮನೆ\thouse",
            ""
        ].joined(separator: "\n")

        try? header.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func appendMissing(word: String) {
        guard let missingURL else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(word)\t\(timestamp)\n"

        if let handle = try? FileHandle(forWritingTo: missingURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            try? line.write(to: missingURL, atomically: true, encoding: .utf8)
        }
    }

    private func saveOverrides() {
        guard let fileURL else { return }
        let header = [
            "# Dictionary overrides (TSV)",
            "# Format: normalized_key<TAB>meaning",
            "# Example: ಮನೆ\thouse",
            ""
        ]
        let lines = overrides.keys.sorted().compactMap { key -> String? in
            guard let meaning = overrides[key], !meaning.isEmpty else { return nil }
            return "\(key)\t\(meaning)"
        }
        let contentLines = header + lines
        let content = contentLines.joined(separator: "\n") + (contentLines.isEmpty ? "" : "\n")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func loadOverrides(from fileURL: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        var results: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let parts = trimmed.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            results[key] = value
        }

        return results
    }
}
