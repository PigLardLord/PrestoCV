import Foundation

/// Splits free text into sentences, cutting after ".", "!", "?" or "…" that is followed by a space or the end, and at line breaks.
///
/// "3.5", "example.com" and "e.g.x" stay whole: a full stop inside a token is not an end. Abbreviations such as "Dr. Smith"
/// are cut, which is harmless to the checks that read sentences one by one.
enum SentenceSplitter {
    static func sentences(in text: String) -> [String] {
        let characters = Array(text)
        var sentences: [String] = []
        var current = ""

        func closeSentence() {
            if let sentence = current.trimmedNonEmpty {
                sentences.append(sentence)
            }
            current = ""
        }

        for (index, character) in characters.enumerated() {
            current.append(character)

            let isLineBreak = character == "\n"
            let isTerminator = ".!?…".contains(character)
            let followedByGap = index + 1 == characters.count || characters[index + 1].isWhitespace

            if isLineBreak || (isTerminator && followedByGap) {
                closeSentence()
            }
        }
        closeSentence()

        return sentences
    }
}
