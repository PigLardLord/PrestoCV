import Foundation

/// Splits free text into sentences, cutting after ".", "!", "?" or "…" that is followed by a space or the end, and at line breaks.
///
/// "3.5", "example.com" and "e.g.x" stay whole: a full stop inside a token is not an end. Abbreviations such as "Dr. Smith"
/// are cut, which is harmless to the checks that read sentences one by one.
enum SentenceSplitter {
    static func sentences(in text: String) -> [String] {
        sentencesByLine(in: text).map(\.text)
    }

    /// `text` with each semicolon that a clause of the person's own follows ("; I train the crew", "; j'accompagne…") as a full stop,
    /// and that clause with a capital: the model wrote a summary's sentences as one, joined by semicolons (#354, round 4). A
    /// semicolon before anything else stays.
    static func unchained(_ text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let semicolon = rest.firstIndex(of: ";") {
            let after = rest[rest.index(after: semicolon)...]
            let clause = after.drop { $0 == " " }
            guard clause.startIndex > after.startIndex, opensWithThePerson(clause) else {
                result += rest[...semicolon]
                rest = after
                continue
            }
            var before = rest[..<semicolon]
            while before.last == " " { before = before.dropLast() }
            result += before + ". " + clause.prefix(1).uppercased()
            rest = clause.dropFirst()
        }
        return result + rest
    }

    /// Whether `clause` opens with the person as its subject: "I", or the first person of the other languages in any case.
    private static func opensWithThePerson(_ clause: Substring) -> Bool {
        let word = clause.prefix { $0.isLetter }
        if word == "I" { return true }
        let folded = word.lowercased()
        if firstPersons.contains(folded) { return true }
        return folded == "j" && clause.dropFirst().first.map { "'’".contains($0) } == true
    }

    /// The first person of German, French, Italian, Spanish and Portuguese, in lower case; English's is "I", only with its capital.
    private static let firstPersons: Set<String> = ["ich", "je", "io", "yo", "eu"]

    /// The sentences of `text` as `sentences(in:)` cuts them, each with whether it starts a line: the first one does, and so does each
    /// one that a line break comes before.
    static func sentencesByLine(in text: String) -> [(text: String, startsALine: Bool)] {
        let characters = Array(text)
        var sentences: [(text: String, startsALine: Bool)] = []
        var current = ""
        var startsALine = true

        func closeSentence(atALineBreak: Bool) {
            if let sentence = current.trimmedNonEmpty {
                sentences.append((sentence, startsALine))
                startsALine = false
            }
            if atALineBreak { startsALine = true }
            current = ""
        }

        for (index, character) in characters.enumerated() {
            current.append(character)

            let isLineBreak = character == "\n"
            let isTerminator = ".!?…".contains(character)
            let followedByGap = index + 1 == characters.count || characters[index + 1].isWhitespace

            if isLineBreak || (isTerminator && followedByGap) {
                closeSentence(atALineBreak: isLineBreak)
            }
        }
        closeSentence(atALineBreak: false)

        return sentences
    }
}
