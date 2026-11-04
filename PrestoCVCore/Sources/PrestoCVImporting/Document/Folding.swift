// MARK: - Folding for the vocabulary

extension StringProtocol {
    /// Lower case without diacritics, with typographic apostrophes as plain ones: how the vocabulary compares words.
    /// "Über mich", "ÜBER MICH" and "uber mich" fold alike; "ß" folds to "ss".
    var folded: String {
        var out = String.UnicodeScalarView()
        for scalar in lowercased().unicodeScalars {
            if (0x0300...0x036F).contains(scalar.value) { continue }   // combining marks of a decomposed letter
            if let base = foldedLetters[scalar] {
                out.append(contentsOf: base.unicodeScalars)
            } else if scalar == "\u{2019}" || scalar == "\u{2018}" || scalar == "\u{02BC}" {
                out.append("'")
            } else {
                out.append(scalar)
            }
        }
        return String(out)
    }
}

private let foldedLetters: [Unicode.Scalar: String] = {
    let groups: [(String, String)] = [
        ("àáâãäåāăą", "a"), ("çćĉċč", "c"), ("ďđ", "d"), ("èéêëēĕėęě", "e"), ("ĝğġģ", "g"), ("ĥħ", "h"),
        ("ìíîïĩīĭįı", "i"), ("ĵ", "j"), ("ķ", "k"), ("ĺļľŀł", "l"), ("ñńņňŉ", "n"), ("òóôõöøōŏő", "o"),
        ("ŕŗř", "r"), ("śŝşšș", "s"), ("ţťŧț", "t"), ("ùúûüũūŭůűų", "u"), ("ŵ", "w"), ("ýÿŷ", "y"), ("źżž", "z"),
    ]
    var table: [Unicode.Scalar: String] = ["ß": "ss", "æ": "ae", "œ": "oe", "þ": "th", "ð": "d"]
    for (letters, base) in groups {
        for scalar in letters.unicodeScalars { table[scalar] = base }
    }
    return table
}()

// MARK: - Words

extension StringProtocol {
    /// The words of a text: runs of letters, digits and the apostrophes and hyphens inside them.
    var words: [Substring] {
        var result: [Substring] = []
        var start: Index?
        var index = startIndex
        while index < endIndex {
            let character = self[index]
            let isPart = character.isLetter || character.isNumber
                || ((character == "'" || character == "’" || character == "-") && start != nil)
            if isPart {
                if start == nil { start = index }
            } else if let wordStart = start {
                result.append(Substring(self[wordStart..<index]))
                start = nil
            }
            index = self.index(after: index)
        }
        if let wordStart = start { result.append(Substring(self[wordStart..<endIndex])) }
        return result.map { word in
            var trimmed = word
            while let last = trimmed.last, last == "'" || last == "’" || last == "-" { trimmed = trimmed.dropLast() }
            return trimmed
        }
    }

    /// Whether the text starts with a letter in lower case.
    var startsInLowerCase: Bool {
        guard let first = first(where: { !$0.isWhitespace }) else { return false }
        return first.isLetter && first.isLowercase
    }
}
