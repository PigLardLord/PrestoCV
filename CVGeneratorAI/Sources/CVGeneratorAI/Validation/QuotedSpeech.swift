import Foundation

/// What the description writes inside quotation marks (#202): another person's words, or words the person only quotes. They claim
/// nothing for the person (see `Grounding`).
///
/// A quote opens with a mark of the six languages and closes with the mark that pairs with it: «…», »…«, ‹…›, ›…‹, “…”, „…“, „…”,
/// ‚…‘, ‚…’, ‘…’, "…" and '…'. It may run over two sentences. A mark that nothing closes quotes nothing. A mark opens only at the start
/// or after a space, a bracket, a dash, a colon or another mark, and before a character that is no space (but for « and ‹, which French
/// writes with a space after them). It closes only before the end, a space or a punctuation mark, and after a character that is no space
/// (but for » and ›, which French writes with a space before them). So an apostrophe inside a word ("I’m", "l’inglese", "don't") is
/// never a mark, nor is an inch mark after a number.
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

    /// For each of `sentences`, in the order the description writes them, the offsets of its characters that stand inside a quote:
    /// the quoted characters, not the marks.
    static func offsets(in sentences: [String]) -> [IndexSet] {
        let text = Array(sentences.joined(separator: "\n"))
        var inside = IndexSet()
        var index = 0
        while index < text.count {
            if let closers = pairs[text[index]], opens(at: index, in: text),
               let close = text.indices.dropFirst(index + 1).first(where: { closers.contains(text[$0]) && closes(at: $0, in: text) }) {
                inside.insert(integersIn: (index + 1)..<close)
                index = close + 1
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

    private static func opens(at index: Int, in text: [Character]) -> Bool {
        guard index + 1 < text.count else { return false }
        if index > 0 {
            let previous = text[index - 1]
            guard previous.isWhitespace || beforeAnOpening.contains(previous) || pairs[previous] != nil else { return false }
        }
        return !text[index + 1].isWhitespace || spacedOpenings.contains(text[index])
    }

    private static func closes(at index: Int, in text: [Character]) -> Bool {
        if index + 1 < text.count {
            let next = text[index + 1]
            guard !next.isLetter, !next.isNumber else { return false }
        }
        return !text[index - 1].isWhitespace || spacedClosings.contains(text[index])
    }
}
