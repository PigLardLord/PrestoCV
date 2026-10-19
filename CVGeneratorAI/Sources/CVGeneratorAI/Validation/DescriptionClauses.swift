import Foundation

/// A clause of the description: the words of a sentence between two commas, semicolons or conjunctions.
struct Clause {
    let words: [Word]
    /// The clause as `DescriptionText.normalized` writes it, addresses taken out.
    let text: String
    /// The links the clause writes, as `AddressTokens.normalizedLink` gives them.
    let links: Set<String>
    /// Whether the clause stands on its own: it starts its sentence or follows a semicolon. One split off by a comma or a conjunction
    /// belongs to the clause before it.
    let isAnchored: Bool
    /// What the clause was read from, to cut it short: its words as written (digits as 0-9, addresses blanked) and as the sentence
    /// has them, both from the offset of the clause's first word.
    private let written: [Character]
    private let original: [Character]
    private let offset: Int
    /// What the sentence holds before the clause's first word: the clause that starts the sentence has it, the others none.
    private let preamble: String

    init(words: [Word], isAnchored: Bool, written: [Character], original: [Character], offset: Int, preamble: String = "") {
        self.words = words
        self.isAnchored = isAnchored
        self.written = written
        self.original = original
        self.offset = offset
        self.preamble = preamble
        text = DescriptionText.normalized(String(written.prefix((words.last?.range.upperBound ?? offset) - offset)))
        links = Set(AddressTokens(String(original)).links)
    }

    /// The clause up to its first `count` words: the words, the text and the links they write, and nothing after.
    func truncated(to count: Int) -> Clause {
        guard count < words.count else { return self }

        let cut = count > 0 ? words[count].range.lowerBound - offset : 0
        return Clause(
            words: Array(words.prefix(count)), isAnchored: isAnchored, written: written, original: Array(original.prefix(cut)), offset: offset,
            preamble: preamble
        )
    }

    /// Whether the word at `index` is written with a capital letter in the description.
    func isCapitalised(_ index: Int) -> Bool {
        let start = words[index].range.lowerBound - offset
        return written.indices.contains(start) && written[start].isUppercase
    }

    /// The clause as the sentence has it, from its first word to the first word of the next clause (from the start of the sentence, for
    /// the first clause): the addresses, the punctuation and the conjunction that ends it are in it.
    var source: String {
        preamble + String(original)
    }

    /// The clause as the sentence has it (`source`), with every run of words that `kept` leaves out written as a semicolon, so that
    /// the words around it stay apart. A clause none of whose words is kept is a semicolon.
    func source(keeping kept: Set<Int>) -> String {
        guard !kept.isEmpty else { return "; " }
        guard words.indices.contains(where: { !kept.contains($0) }) else { return source }

        var text = preamble
        var cursor = 0
        var index = 0
        while index < words.count {
            guard !kept.contains(index) else {
                index += 1
                continue
            }
            let start = min(words[index].range.lowerBound - offset, original.count)
            while index < words.count, !kept.contains(index) { index += 1 }
            text += String(original[min(cursor, start)..<start]) + "; "
            cursor = index < words.count ? min(words[index].range.lowerBound - offset, original.count) : original.count
        }
        return text + String(original[cursor...])
    }

    /// Whether the clause ends with a question mark, past the spaces, the punctuation and the closing marks after it: "Parlo
    /// francese?", "«Parli francese?»".
    var endsAQuestion: Bool {
        lastMark == "?"
    }

    /// Whether the clause ends with a colon: "My colleague wrote:".
    var endsWithAColon: Bool {
        lastMark == ":"
    }

    private static let trailing: Set<Character> = [",", ";", "!", ")", "]", "}", "\"", "'", "»", "«", "”", "“", "’", "‘", "›", "‹"]

    private var lastMark: Character? {
        source.last { !$0.isWhitespace && !Self.trailing.contains($0) }
    }

    /// Where `phrase` (the folded words of a quote) stands in the clause, as ranges of word positions.
    func spans(of phrase: [String]) -> [Range<Int>] {
        guard !phrase.isEmpty, words.count >= phrase.count else { return [] }

        return (0...(words.count - phrase.count)).compactMap { start in
            let range = start..<(start + phrase.count)
            return words[range].map(\.folded) == phrase ? range : nil
        }
    }

    func contains(_ phrase: [String]) -> Bool {
        !spans(of: phrase).isEmpty
    }

    /// Where `phrase` stands in the clause as itself, and not as a part of a longer quote: "nurse" is not named by "head nurse"
    /// when the draft has a head nurse, nor "Acme" by "Acme Labs" when it has an Acme Labs.
    func standaloneSpans(of phrase: [String], amongQuotes quotes: [[String]]) -> [Range<Int>] {
        let covering = quotes.filter { $0.count > phrase.count }.flatMap { spans(of: $0) }
        return spans(of: phrase).filter { span in !covering.contains { $0.contains(span.lowerBound) && span.upperBound <= $0.upperBound } }
    }

    /// Where the clause begins to name the phrases: the last, among them, of the places where each first stands as itself. Nil when
    /// some phrase is not in the clause.
    func nameStart(of phrases: [[String]], amongQuotes quotes: [[String]]) -> Int? {
        let starts = phrases.map { standaloneSpans(of: $0, amongQuotes: quotes).map(\.lowerBound).min() }
        guard !starts.isEmpty, !starts.contains(where: { $0 == nil }) else { return nil }
        return starts.compactMap { $0 }.max()
    }

    /// The word positions that lie inside an occurrence of one of the phrases.
    func positions(inside phrases: [[String]]) -> Set<Int> {
        Set(phrases.flatMap { spans(of: $0) }.flatMap { $0 })
    }
}

/// The description cut into clauses, sentence by sentence.
///
/// A clause ends at a comma, a semicolon, a sentence end or a conjunction of the six languages (read with its accents, so
/// that "è" (is) does not end a clause the way "e" (and) does). A quote of the draft is never cut: "Procter and Gamble",
/// "Studio Rossi e Associati" and "Acme, Inc." stay in one clause.
struct DescriptionClauses {
    /// The clauses of each sentence, in order.
    let sentences: [[Clause]]
    /// The sentences as written.
    private let texts: [String]
    /// The offsets of the characters of each sentence that stand inside quotation marks (`QuotedSpeech`).
    private let quoted: [IndexSet]
    /// The sentences that start a line of the description: the first one, and each one after a line break.
    private let lineStarts: Set<Int>
    /// A clause by where it stands: its sentence, and its place in the sentence.
    struct Place: Hashable {
        let sentence: Int
        let clause: Int
    }

    /// - Parameters:
    ///   - sentences: The sentences of the description, as written.
    ///   - protecting: The quotes of the draft, as the folded words they are made of.
    ///   - language: The language of the description, to tell which words are verbs (`Word.isTaggedVerb`); with none, no word is.
    ///   - lineStarts: The sentences that start a line of the description; with none, no sentence is known to.
    init(sentences: [String], protecting quotes: [[String]], language: Vocabulary.Language? = nil, lineStarts: Set<Int> = []) {
        texts = sentences
        quoted = QuotedSpeech.offsets(in: sentences)
        self.lineStarts = lineStarts
        self.sentences = sentences.map { sentence in
            Self.clauses(of: sentence, blanked: AddressTokens(sentence).remainder, protecting: quotes, language: language)
        }
    }

    func clause(at place: Place) -> Clause {
        sentences[place.sentence][place.clause]
    }

    var places: [Place] {
        sentences.enumerated().flatMap { sentence, clauses in clauses.indices.map { Place(sentence: sentence, clause: $0) } }
    }

    /// The sentences as written, but for the clauses that `isKept` rejects, which are left out. A clause left out becomes a semicolon,
    /// so that the ones around it stay apart. A sentence of no words (an address on its own) stays as written, if `keepsAnAddress` lets
    /// it (it gets the sentence's position), and is left out otherwise.
    func sentences(keeping isKept: (Place) -> Bool, keepsAnAddress: (Int) -> Bool = { _ in true }) -> [String] {
        sentences(keepingWords: { isKept($0) ? Set(clause(at: $0).words.indices) : [] }, keepsAnAddress: keepsAnAddress)
    }

    /// The sentences as written, each clause with only the words that `kept` gives it (`Clause.source(keeping:)`): a word left out
    /// becomes a semicolon, as a clause left out does. A sentence of no words is kept as `sentences(keeping:keepsAnAddress:)` keeps it.
    func sentences(keepingWords kept: (Place) -> Set<Int>, keepsAnAddress: (Int) -> Bool = { _ in true }) -> [String] {
        sentences.indices.map { sentence in
            guard !sentences[sentence].isEmpty else { return keepsAnAddress(sentence) ? texts[sentence] : "" }

            return sentences[sentence].indices.map { clause in
                sentences[sentence][clause].source(keeping: kept(Place(sentence: sentence, clause: clause)))
            }.joined()
        }
    }

    /// The positions of the words of the clause at `place` that stand inside quotation marks (`QuotedSpeech`).
    func quotedWords(at place: Place) -> Set<Int> {
        let words = clause(at: place).words
        return Set(words.indices.filter { quoted[place.sentence].contains(words[$0].range.lowerBound) })
    }

    /// The sentence that starts the line of sentence `sentence`, or nil when no sentence before it is known to start one.
    func lineStart(of sentence: Int) -> Int? {
        (0...sentence).last { lineStarts.contains($0) }
    }

    /// The places of the clauses next to `place` in its sentence.
    func neighbours(of place: Place) -> [Place] {
        [place.clause - 1, place.clause + 1]
            .filter { sentences[place.sentence].indices.contains($0) }
            .map { Place(sentence: place.sentence, clause: $0) }
    }

    // MARK: - Cutting

    private static func clauses(of sentence: String, blanked: String, protecting quotes: [[String]], language: Vocabulary.Language?) -> [Clause] {
        let written = Array(Digits.ascii(blanked))
        var words = Word.words(in: blanked)
        for index in LexicalClasses.verbs(in: String(written), words: words, language: language) { words[index].isTaggedVerb = true }
        let protected = protectedPairs(in: words, quotes: quotes)
        let characters = Array(sentence)

        var groups: [[Word]] = []
        var anchors: [Bool] = []
        var current: [Word] = []
        var currentIsAnchored = true
        var nextIsAnchored = true
        for (index, word) in words.enumerated() {
            let isInsideAQuote = protected.contains(index) || protected.contains(index - 1)
            if StatementWords.isConjunction(word.accented, in: language) && !isInsideAQuote && !word.isHyphenated {
                if !current.isEmpty {
                    groups.append(current)
                    anchors.append(currentIsAnchored)
                }
                current = []
                nextIsAnchored = false
                continue
            }
            if current.isEmpty { currentIsAnchored = nextIsAnchored }
            current.append(word)
            if word.endsWithABreak && !protected.contains(index) {
                groups.append(current)
                anchors.append(currentIsAnchored)
                current = []
                nextIsAnchored = word.endsWithASemicolon
            }
        }
        if !current.isEmpty {
            groups.append(current)
            anchors.append(currentIsAnchored)
        }
        if !anchors.isEmpty { anchors[0] = true }

        return groups.enumerated().map { number, group in
            let start = group[0].range.lowerBound
            let end = number + 1 < groups.count ? groups[number + 1][0].range.lowerBound : written.count
            return Clause(
                words: group,
                isAnchored: anchors[number],
                written: Array(written[start..<max(start, min(end, written.count))]),
                original: Array(characters[min(start, characters.count)..<min(max(start, end), characters.count)]),
                offset: start,
                preamble: number == 0 ? String(characters[0..<min(start, characters.count)]) : ""
            )
        }
    }

    /// The positions of the words that are followed, inside a quote, by another word of the same quote: neither a
    /// conjunction nor a comma after them ends the clause.
    private static func protectedPairs(in words: [Word], quotes: [[String]]) -> Set<Int> {
        var protected = Set<Int>()
        let folded = words.map(\.folded)
        for quote in quotes where quote.count > 1 && folded.count >= quote.count {
            for start in 0...(folded.count - quote.count) where Array(folded[start..<(start + quote.count)]) == quote {
                protected.formUnion(start..<(start + quote.count - 1))
            }
        }
        return protected
    }
}
