import Foundation

/// Protocol for dictionary providers that can look up word meanings.
protocol DictionaryProvider {
    /// Looks up the meaning of a word using its normalized key.
    /// - Parameter normalizedKey: The normalized (lowercased, trimmed) word to lookup.
    /// - Returns: The meaning if found, nil otherwise.
    func lookup(normalizedKey: String) -> String?
    
    /// A human-readable description of the dictionary source.
    var sourceDescription: String { get }
}
