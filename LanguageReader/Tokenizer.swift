import Foundation
import NaturalLanguage

struct Token: Identifiable {
    let id = UUID()
    let text: String
    let isWord: Bool
}

struct Tokenizer {
    func tokenize(_ text: String) -> [Token] {
        let natural = tokenizeWithNaturalLanguage(text)
        if !natural.isEmpty {
            return natural
        }
        return fallbackTokenize(text)
    }

    private func tokenizeWithNaturalLanguage(_ text: String) -> [Token] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [Token] = []
        var lastIndex = text.startIndex

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if range.lowerBound > lastIndex {
                let gap = String(text[lastIndex..<range.lowerBound])
                tokens.append(Token(text: gap, isWord: false))
            }

            let word = String(text[range])
            tokens.append(Token(text: word, isWord: true))

            lastIndex = range.upperBound
            return true
        }

        if lastIndex < text.endIndex {
            let tail = String(text[lastIndex..<text.endIndex])
            tokens.append(Token(text: tail, isWord: false))
        }

        return tokens
    }

    private func fallbackTokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var currentIsWord: Bool? = nil

        for character in text {
            let isWord = isWordCharacter(character)
            if currentIsWord == nil {
                currentIsWord = isWord
                current = String(character)
                continue
            }

            if isWord == currentIsWord {
                current.append(character)
            } else {
                tokens.append(Token(text: current, isWord: currentIsWord ?? false))
                current = String(character)
                currentIsWord = isWord
            }
        }

        if let currentIsWord {
            tokens.append(Token(text: current, isWord: currentIsWord))
        }

        return tokens
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        let wordScalars = CharacterSet.letters
            .union(.nonBaseCharacters)
            .union(.decimalDigits)

        return character.unicodeScalars.allSatisfy { wordScalars.contains($0) }
    }
}
