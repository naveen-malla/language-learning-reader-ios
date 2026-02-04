import Foundation

protocol DictionaryProvider {
    func lookup(normalizedKey: String) -> String?
    var sourceDescription: String { get }
}
