import Foundation

/// What the description writes inside quotation marks (#202): another person's words, or words the person only quotes. They claim
/// nothing for the person (see `Grounding`).
///
/// A quote opens with a mark of the six languages and closes with the mark that pairs with it: «…», »…«, ‹…›, ›…‹, “…”, „…“, „…”,
/// ‚…‘, ‚…’, ‘…’, "…" and '…'. It may run over two sentences, and over lines. A mark opens only at the start or after a space, a
/// bracket, a dash, a colon or another mark, and before a character that is no space (but for « and ‹, which French writes with a
/// space after them) or at the end of its line, where the quote goes on with the next line ("Mon collègue a écrit '", then "Je parle
/// français.'"). It closes only before the end, a space or a punctuation mark, and after a character that is no space (but for » and ›,
/// which French writes with a space before them, and for a mark alone on its line). So an apostrophe inside a word ("I’m", "l’inglese",
/// "don't") is never a mark, and an inch mark after a number opens no quote.
///
/// - A single mark right after a letter or a digit may end a word rather than the quote, whatever follows it: a possessive
///   ("patients' records", "Hans’ Team"), an elision ("un po'", "jusqu' à") or a prime ("a 5' de la oficina"). It closes no quote for
///   sure. A quote closes at the first mark that does: a double mark, a guillemet, or a single mark after anything but a letter or a
///   digit ("…French.'").
/// - A quote that only such a mark may close runs to the end of the line of the last of them. Whether the quote ends at that mark or
///   goes on past it, nothing after it on its line is surely the person's; only a line break tells where another person's words end,
///   as it does after a line that introduces them ("My colleague wrote:").
/// - A mark that nothing may close quotes nothing: a stray mark, or an apostrophe that starts a word ("the '90s").
/// - A mark alone on its line closes the quote, so the line after it claims as usual, unless a later mark closes the quote for sure
///   and no opening mark after the lone one pairs with it: the lone mark is then a symbol the quote holds, such as a ditto mark, and
///   the quote runs to that later mark ("My colleague wrote "", "In my table, the ditto symbol is:", """, "I speak French." and
///   "End of my message."" on five lines quote all of the colleague's message).
enum QuotedSpeech {
    /// The closing marks of each opening mark.
    private static let pairs: [Character: Set<Character>] = [
        "«": ["»"], "»": ["«"], "‹": ["›"], "›": ["‹"],
        "“": ["”"], "„": ["“", "”"], "‚": ["‘", "’"], "‘": ["’"],
        "\"": ["\""], "'": ["'"],
    ]

    /// What may stand right before an opening mark, besides a space or another mark.
    private static let beforeAnOpening: Set<Character> = ["(", "[", "{", ":", "-", "–", "—", "/"]

    /// The opening and the closing marks that may have a space on their inner side, as French writes them: « … ».
    private static let spacedOpenings: Set<Character> = ["«", "‹"]
    private static let spacedClosings: Set<Character> = ["»", "›"]

    /// The closing marks that are written for an apostrophe or a prime too.
    private static let apostrophes: Set<Character> = ["'", "’", "‘"]

    /// For each of `sentences`, in the order the description writes them, the offsets of its characters that stand inside a quote:
    /// the quoted characters, not the marks.
    /// - Parameter lineStarts: The sentences that start a line of the description; with none, no line break is known, and the
    ///   description is one line.
    static func offsets(in sentences: [String], lineStarts: Set<Int>) -> [IndexSet] {
        let text = Array(sentences.joined(separator: "\n"))
        let lineEnds = lineEnds(of: sentences, lineStarts: lineStarts) + [text.count]
        var inside = IndexSet()
        var index = 0
        while index < text.count {
            guard let closers = pairs[text[index]], opens(at: index, in: text) else {
                index += 1
                continue
            }
            let marks = text.indices.dropFirst(index + 1).filter { closers.contains(text[$0]) && closes(at: $0, in: text) }
            if let first = marks.first(where: { !mayEndAWord(at: $0, in: text) }) {
                let later = isAlone(at: first, in: text)
                    ? unpairedClose(after: first, opening: text[index], among: marks, in: text) : nil
                let close = later ?? first
                inside.insert(integersIn: (index + 1)..<close)
                index = close + 1
            } else if let last = marks.last, let end = lineEnds.first(where: { $0 > last }) {
                inside.insert(integersIn: (index + 1)..<end)
                index = end
            } else {
                index += 1
            }
        }

        var start = 0
        return sentences.map { sentence in
            let range = start..<(start + sentence.count)
            start = range.upperBound + 1
            return IndexSet(inside.filter(range.contains).map { $0 - range.lowerBound })
        }
    }

    /// The offsets, in `sentences` joined by line breaks, of the breaks that end a line: those before the sentences that start one.
    private static func lineEnds(of sentences: [String], lineStarts: Set<Int>) -> [Int] {
        var ends: [Int] = []
        var offset = 0
        for (number, sentence) in sentences.enumerated() {
            if number > 0, lineStarts.contains(number) { ends.append(offset - 1) }
            offset += sentence.count + 1
        }
        return ends
    }

    /// Whether the mark at `index` opens a quote. A line break after it ends its line: in `offsets(in:lineStarts:)` the sentences are
    /// joined by line breaks, and a sentence ends with a mark only where its line does.
    private static func opens(at index: Int, in text: [Character]) -> Bool {
        guard index + 1 < text.count else { return false }
        if index > 0 {
            let previous = text[index - 1]
            guard previous.isWhitespace || beforeAnOpening.contains(previous) || pairs[previous] != nil else { return false }
        }
        let next = text[index + 1]
        return !next.isWhitespace || next == "\n" || spacedOpenings.contains(text[index])
    }

    private static func closes(at index: Int, in text: [Character]) -> Bool {
        if index + 1 < text.count {
            let next = text[index + 1]
            guard !next.isLetter, !next.isNumber else { return false }
        }
        return !text[index - 1].isWhitespace || spacedClosings.contains(text[index]) || isAlone(at: index, in: text)
    }

    /// Whether the mark at `index` stands alone on its line.
    private static func isAlone(at index: Int, in text: [Character]) -> Bool {
        index > 0 && text[index - 1] == "\n" && (index + 1 == text.count || text[index + 1] == "\n")
    }

    /// The mark that closes the quote when the mark `alone` on its line is a symbol that the quote holds, such as a ditto mark: the
    /// first later mark of `marks` that closes the quote for sure and that no opening mark after `alone` pairs with. Nil when there is
    /// none, and the lone mark closes the quote. Other marks alone on their lines neither open nor close here.
    private static func unpairedClose(after alone: Int, opening: Character, among marks: [Int], in text: [Character]) -> Int? {
        let sure = Set(marks.filter { $0 > alone && !isAlone(at: $0, in: text) && !mayEndAWord(at: $0, in: text) })
        var open = 0
        for position in (alone + 1)..<text.count where !isAlone(at: position, in: text) {
            if sure.contains(position) {
                if open == 0 { return position }
                open -= 1
            } else if text[position] == opening, opens(at: position, in: text) {
                open += 1
            }
        }
        return nil
    }

    /// Whether the closing mark at `index` may end a word rather than a quote: a single mark right after a letter or a digit.
    private static func mayEndAWord(at index: Int, in text: [Character]) -> Bool {
        apostrophes.contains(text[index]) && (text[index - 1].isLetter || text[index - 1].isNumber)
    }
}
