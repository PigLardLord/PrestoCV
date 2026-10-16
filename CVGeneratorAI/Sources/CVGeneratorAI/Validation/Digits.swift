import Foundation

/// Reading numbers out of free text, the same way for the description and for a draft.
enum Digits {
    /// The text with every Unicode decimal digit (full-width, Arabic-Indic, Devanagari...) written as 0-9.
    static func ascii(_ text: String) -> String {
        String(text.map { character -> Character in
            guard !character.isASCII,
                  character.unicodeScalars.count == 1,
                  let scalar = character.unicodeScalars.first,
                  scalar.properties.numericType == .decimal,
                  let value = scalar.properties.numericValue else { return character }
            return Character(String(Int(value)))
        })
    }

    static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// Maximal runs of digits.
    static func runs(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in text {
            if isDigit(character) {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            runs.append(current)
        }
        return runs
    }

    /// Each stretch of digits joined by phone punctuation: a single space, "-", "." or "/" between digits, brackets
    /// around a group, and a leading "+". A full stop or a space before a letter ends the stretch. Only the digits are
    /// kept.
    static func phoneStretches(in text: String) -> [String] {
        let characters = Array(text)
        var stretches: [String] = []
        var digits = ""

        func closeStretch() {
            if !digits.isEmpty {
                stretches.append(digits)
            }
            digits = ""
        }

        for (index, character) in characters.enumerated() {
            let previous = index > 0 ? characters[index - 1] : nil
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let nextIsDigit = next.map(isDigit) ?? false

            if isDigit(character) {
                digits.append(character)
            } else if " -./".contains(character) {
                let joinsDigits = previous.map { isDigit($0) || $0 == ")" } ?? false
                if !(joinsDigits && (nextIsDigit || (next == "(" && " -".contains(character)))) {
                    closeStretch()
                }
            } else if character == "(" {
                if !(nextIsDigit && (digits.isEmpty || previous.map { " -./+".contains($0) } == true)) {
                    closeStretch()
                }
            } else if character == ")" {
                if !(previous.map(isDigit) ?? false) {
                    closeStretch()
                }
            } else if character == "+" {
                if !(nextIsDigit && digits.isEmpty) {
                    closeStretch()
                }
            } else {
                closeStretch()
            }
        }
        closeStretch()
        return stretches
    }

    /// A phone number's digits without a leading "00", which says what "+" says.
    static func phoneKey(_ digits: String) -> String {
        digits.hasPrefix("00") ? String(digits.dropFirst(2)) : digits
    }
}
