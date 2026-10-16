import Foundation

/// A word or a number of a text, with where it stands.
struct Word: Equatable {
    /// Lower case, with accents: "è" (is) is not "e" (and).
    let accented: String
    /// Lower case, without accents, digits written as 0-9: how words are compared.
    let folded: String
    let isNumber: Bool
    /// Character offsets in the text it was read from.
    let range: Range<Int>
    /// Whether a comma or a semicolon follows it.
    let endsWithABreak: Bool
    /// Whether a semicolon follows it.
    let endsWithASemicolon: Bool
    /// Whether a hyphen and a letter follow it with no space between: the "e" of "e-mail" is no conjunction.
    let isHyphenated: Bool
    /// Whether the device's lexical class tags it as a verb: known only for the words of a description's clauses (`DescriptionClauses`).
    var isTaggedVerb = false
}

extension Word {
    /// The words and numbers of `text`, in order. Punctuation separates them and is not kept, apart from the commas and semicolons
    /// that follow a word. A word is a run of letters and digits with a letter in it ("B2", "3rd"); a number is a run of digits,
    /// which keeps its inner separator: "3.5" and "1.000" are numbers, and "1,000" is "1.000".
    static func words(in text: String) -> [Word] {
        let characters = Array(Digits.ascii(text))
        var words: [Word] = []
        var index = 0

        while index < characters.count {
            guard characters[index].isLetter || Digits.isDigit(characters[index]) else {
                index += 1
                continue
            }
            let run = endOfRun(from: index, in: characters)
            let isNumber = characters[index..<run].allSatisfy(Digits.isDigit)
            let end = isNumber ? endOfNumber(from: index, in: characters) : run
            let written = String(characters[index..<end])

            let separator = separator(after: end, in: characters)
            words.append(Word(
                accented: isNumber ? number(written) : DescriptionText.normalized(written, foldingAccents: false),
                folded: isNumber ? number(written) : DescriptionText.normalized(written),
                isNumber: isNumber,
                range: index..<end,
                endsWithABreak: separator != nil,
                endsWithASemicolon: separator == ";",
                isHyphenated: !isNumber && end + 1 < characters.count && characters[end] == "-" && characters[end + 1].isLetter
            ))
            index = end
        }
        return words
    }

    private static func endOfRun(from start: Int, in characters: [Character]) -> Int {
        var end = start
        while end < characters.count && (characters[end].isLetter || Digits.isDigit(characters[end])) { end += 1 }
        return end
    }

    private static func endOfNumber(from start: Int, in characters: [Character]) -> Int {
        var end = start
        while end < characters.count {
            let isDigit = Digits.isDigit(characters[end])
            let isInnerSeparator = (characters[end] == "." || characters[end] == ",") && end + 1 < characters.count && Digits.isDigit(characters[end + 1])
            guard isDigit || isInnerSeparator else { break }
            end += 1
        }
        return end
    }

    private static func number(_ written: String) -> String {
        written.replacingOccurrences(of: ",", with: ".")
    }

    /// The comma or the semicolon after a word, past the brackets and quotes that close it: "(native), French".
    private static func separator(after end: Int, in characters: [Character]) -> Character? {
        var index = end
        while index < characters.count, ")]}\"'»”’ ".contains(characters[index]) { index += 1 }
        return index < characters.count && (characters[index] == "," || characters[index] == ";") ? characters[index] : nil
    }
}
