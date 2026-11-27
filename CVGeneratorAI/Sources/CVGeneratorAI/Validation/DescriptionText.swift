import Foundation

/// The person's description, indexed so that each claim in a generated CV can be checked against it.
///
/// The checks are conservative by construction: a token that could be read two ways is not accepted.
/// - **Contact details** (email, link, phone) must be a complete token of the description. They may differ
///   only in the formatting named at each check, never by being longer or shorter.
/// - **Names** (people, employers, schools, titles, places, skills) must occur as a contiguous phrase of whole
///   words, ignoring case and accents.
/// - **Prose** is kept sentence by sentence; a sentence is kept only if each of its clauses quotes a clause of the description
///   (or of the clauses that back an entry, for the text of an entry; see `ProseQuotes`), and it states no address the
///   description lacks.
/// - **Levels** need a statement in a sentence that names the item, with no negation or hedge in it.
/// - **An entry's own details** (title, dates, figures, place, issuer, link, "still works there") come only from the
///   clauses that back it (see `Grounding`).
struct DescriptionText {
    private let text: String
    let sentences: [Sentence]
    private let emails: Set<String>
    private let links: Set<String>
    private let phones: Set<String>
    private let languageOfText: @Sendable (String) -> String?
    private let language: String?
    /// The language of the description, when it is one of the six: the detector's, or else the framework's guess.
    private let vocabularyLanguage: Vocabulary.Language?

    init(_ description: String, languageOfText: @escaping @Sendable (String) -> String? = { _ in nil }) {
        self.languageOfText = languageOfText
        language = languageOfText(description).map(Self.primaryLanguage)
        vocabularyLanguage = (language ?? LanguageGuess.tag(of: description)).flatMap(Vocabulary.Language.init(tag:))
        text = Self.normalized(description)
        sentences = SentenceSplitter.sentencesByLine(in: description).map { Sentence($0.text, startsALine: $0.startsALine) }
        (emails, links, phones) = Self.addresses(in: description)
    }

    /// The description as the person speaks it: the `sentences` of `source` that remain once the clauses that speak for someone else
    /// are left out (see `Entries.spoken`). It is read in the language of `source`, whatever is left of the text. A name, a level or an
    /// address that stands only in the clause of someone else is not found in it.
    init(sentences raw: [String], of source: DescriptionText) {
        languageOfText = source.languageOfText
        language = source.language
        vocabularyLanguage = source.vocabularyLanguage
        text = Self.normalized(raw.joined(separator: " "))
        sentences = raw.map { Sentence($0) }
        (emails, links, phones) = Self.addresses(in: raw.joined(separator: " "))
    }

    private static func addresses(in text: String) -> (emails: Set<String>, links: Set<String>, phones: Set<String>) {
        let addresses = AddressTokens(text)
        let remainder = Digits.ascii(addresses.remainder)
        return (
            Set(addresses.emails), Set(addresses.links),
            Set(Digits.phoneStretches(in: remainder).filter { $0.count >= minimumPhoneDigits }.map(Digits.phoneKey))
        )
    }

    /// What explains a word of the description: the closed vocabulary, in the language of the description when it is known.
    var explainer: Explainer {
        Explainer(language: vocabularyLanguage)
    }

    /// A sentence of the description, as a text to look words up in (without accents) and as one to tell "e" (and)
    /// from "è" (is) in (with them).
    struct Sentence {
        let raw: String
        let folded: String
        let accented: String
        /// Whether the sentence starts a line of the description: not known of the sentences of a text made of kept clauses.
        let startsALine: Bool

        init(_ text: String, startsALine: Bool = false) {
            raw = text
            folded = DescriptionText.normalized(text)
            accented = DescriptionText.normalized(text, foldingAccents: false)
            self.startsALine = startsALine
        }
    }

    // MARK: - Contact details

    /// An email is kept if the description contains that whole address, ignoring case.
    /// "anna@example.com" is not found in "joanna@example.com", nor in "sam!anna@example.com".
    func supportedEmail(_ email: String?) -> String? {
        guard let email = email.presentValue, emails.contains(email.lowercased()) else { return nil }
        return email
    }

    /// A link is kept if the description contains that whole link, ignoring case, the scheme, a leading "www."
    /// and a trailing slash. "github.com/alice" is not found in "github.com/alice-smith", nor "example.com" in
    /// "example.com?user=alice".
    func supportedLink(_ link: String?) -> String? {
        guard let link = link.presentValue, links.contains(AddressTokens.normalizedLink(link)) else { return nil }
        return link
    }

    /// A phone number is kept if the description contains that whole number, ignoring separators and a
    /// leading "+" or "00". A part of a number, or a number with extra digits, is not found.
    func supportedPhone(_ phone: String?) -> String? {
        guard let phone = phone.presentValue else { return nil }
        let digits = Digits.ascii(phone).filter(Digits.isDigit)
        guard digits.count >= Self.minimumPhoneDigits, phones.contains(Digits.phoneKey(digits)) else { return nil }
        return phone
    }

    // MARK: - Names

    /// A name (of a person, employer, school, title, place, skill...) is kept if it occurs in the description as a
    /// contiguous phrase of whole words, ignoring case and accents.
    /// "John Smith" is not found in "I am John; my manager is Jane Smith".
    func named(_ name: String?) -> String? {
        guard let name = name.presentValue, !Self.spans(of: Self.normalized(name), in: text).isEmpty else { return nil }
        return name
    }

    /// An employer of a job, kept as `named` keeps a name, when one of its occurrences in the description can be an employer's name:
    /// one right after a possessive of the person ("les entreprises de mon quartier", "my street") is a place or a thing of theirs, and
    /// names no one the person works for (#354).
    func namedEmployer(_ name: String?) -> String? {
        guard let name = named(name) else { return nil }
        let possessives = vocabularyLanguage.map { Self.possessives[$0] ?? [] }
            ?? Self.possessives.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        let isAName = Self.spans(of: Self.normalized(name), in: text).contains { span in
            let start = String.Index(utf16Offset: span.lowerBound, in: text)
            let before = text[..<start].split(separator: " ").last.map(String.init) ?? ""
            return !possessives.contains(before)
        }
        return isAName ? name : nil
    }

    /// The possessives of the person, in the first person, as `normalized` writes them.
    private static let possessives: [Vocabulary.Language: Set<String>] = [
        .english: ["my", "our"],
        .italian: ["mio", "mia", "miei", "mie", "nostro", "nostra", "nostri", "nostre"],
        .german: ["mein", "meine", "meinem", "meinen", "meiner", "meines", "unser", "unsere", "unserem", "unseren", "unserer", "unseres"],
        .spanish: ["mi", "mis", "nuestro", "nuestra", "nuestros", "nuestras"],
        .french: ["mon", "ma", "mes", "notre", "nos"],
        .portuguese: ["meu", "minha", "meus", "minhas", "nosso", "nossa", "nossos", "nossas"],
    ]

    // MARK: - Prose

    /// The sentences of `prose` each of whose clauses quotes one of the `quotes` (see `ProseQuotes`), or nil when none is left.
    ///
    /// - Parameter allowsNumbers: Whether a sentence may hold a number: a summary holds none, not even one the description writes.
    func grounded(_ prose: String?, quoting quotes: ProseQuotes, allowsNumbers: Bool) -> String? {
        guard let prose = prose.presentValue else { return nil }

        let kept = Self.sentences(of: prose).filter { isGrounded($0, quoting: quotes, allowsNumbers: allowsNumbers) }
        return kept.isEmpty ? nil : kept.joined(separator: " ")
    }

    /// The sentences of `prose` that hold a letter: one with none (" ,", "}, {", what the model leaves of its answer's punctuation)
    /// has no word to check, so no rule would ever drop it, and it says nothing (#354).
    private static func sentences(of prose: String) -> [String] {
        SentenceSplitter.sentences(in: prose).filter { $0.contains(where: \.isLetter) }
    }

    /// The sentences of `prose` that are grounded (see `grounded(_:quoting:allowsNumbers:)`) or `isPlain`: the text the model writes
    /// around the facts keeps the sentences that state no fact of their own (ADR 0031, `WrittenText`).
    func written(
        _ prose: String?, quoting quotes: ProseQuotes, allowsNumbers: Bool, orPlain isPlain: (String) -> Bool
    ) -> String? {
        guard let prose = prose.presentValue else { return nil }

        let kept = Self.sentences(of: prose).filter {
            isGrounded($0, quoting: quotes, allowsNumbers: allowsNumbers) || isPlain($0)
        }
        return kept.isEmpty ? nil : kept.joined(separator: " ")
    }

    /// Whether each clause of `sentence` quotes a clause of a sentence of the description that names one of `names` and none of
    /// `own` (`ProseQuotes`): what the description says of another job ("onde desenvolvo aplicativos para lojas" in the sentence of
    /// Sulware), restated in the text of this one (#354).
    func repeats(_ sentence: String, ofSentencesNaming names: [String], notNaming own: [String]) -> Bool {
        let phrases = { (names: [String]) in names.compactMap(\.presentValue).map { Self.normalized($0) } }
        let others = phrases(names)
        let ownNames = phrases(own)
        let mentions = { (sentence: Sentence, phrases: [String]) in phrases.contains { !Self.spans(of: $0, in: sentence.folded).isEmpty } }
        return restates(sentence, ofSentencesWhere: { mentions($0, others) && !mentions($0, ownNames) })
    }

    /// Whether each clause of `sentence` quotes a clause of the sentences of the description that `isSource` picks (`ProseQuotes`).
    func restates(_ sentence: String, ofSentencesWhere isSource: (Sentence) -> Bool) -> Bool {
        let said = sentences.filter(isSource)
        guard !said.isEmpty else { return false }

        let clauses = DescriptionClauses(sentences: said.map(\.raw), protecting: [], language: explainer.language).sentences.joined()
        let quotes = ProseQuotes(sources: clauses.map { ProseQuotes.Source($0) }, language: explainer.language)
        return isGrounded(sentence, quoting: quotes, allowsNumbers: true)
    }

    /// The words of the description, as `Word.folded` writes them.
    var foldedWords: Set<String> {
        Set(Word.words(in: text).map(\.folded))
    }

    /// The words of the description, as `Word.folded` writes them, once each of `names` is taken out of it, whatever its case.
    func foldedWords(outside names: [String]) -> Set<String> {
        var rest = text
        for name in names.sorted(by: { $0.count > $1.count }) where !name.isEmpty {
            rest = rest.replacingOccurrences(of: Self.normalized(name), with: " ", options: [.caseInsensitive, .diacriticInsensitive])
        }
        return Set(Word.words(in: rest).map(\.folded))
    }

    /// Addresses are read from the sentence as written, never with their digits folded: "alice١@example.com" is not
    /// "alice1@example.com". What is left once the addresses are taken out is read as words and numbers.
    private func isGrounded(_ sentence: String, quoting quotes: ProseQuotes, allowsNumbers: Bool) -> Bool {
        guard isInTheLanguageOfTheDescription(sentence, wordList: nil) else { return false }

        let addresses = AddressTokens(sentence)
        guard !addresses.hasAmbiguousAddress,
              addresses.emails.allSatisfy(emails.contains),
              addresses.links.allSatisfy(links.contains) else { return false }

        let words = Word.words(in: addresses.remainder)
        let proseClauses = DescriptionClauses(sentences: [sentence], protecting: [], language: explainer.language).sentences.first ?? []
        return (allowsNumbers || !words.contains(where: \.isNumber)) && proseClauses.allSatisfy { quotes.quotes($0.words) }
    }

    /// A sentence is in another language only when the detector is sure of both languages and they differ, and, given a `wordList`,
    /// the dictionary of the description's language lacks one of its words: a short sentence the detector gives to a close language
    /// ("Gerencio fluxos de dados internos." read as Spanish in a Portuguese description) whose words are all Portuguese stays
    /// (#354).
    func isInTheLanguageOfTheDescription(_ sentence: String, wordList: (any WordList)?) -> Bool {
        guard let descriptionLanguage = language, let sentenceLanguage = languageOfText(sentence).map(Self.primaryLanguage),
              sentenceLanguage != descriptionLanguage else { return true }
        let words = Word.words(in: sentence).filter { !$0.isNumber }
        guard let wordList, !words.isEmpty else { return false }
        return words.allSatisfy { wordList.knows($0.accented, inLanguage: descriptionLanguage) == true }
    }

    /// "pt-PT" and "pt-BR" are both Portuguese.
    private static func primaryLanguage(_ tag: String) -> String {
        tag.split(separator: "-").first.map { String($0).lowercased() } ?? tag.lowercased()
    }

    // MARK: - Levels

    /// The levels the description allows for `item`, or nil when it states none.
    ///
    /// A level is stated by a CEFR code (which is exact) or by a level word, in the clause that names the item (a clause
    /// ends at a comma, a semicolon or a conjunction) and with no negation or hedge in it ("not fluent", "a bit",
    /// "hardly"): "Italian and my sister's French (native)" says nothing of Italian, nor "Italian (native), French (A2)"
    /// of Italian's A2, whether or not the draft has French.
    /// When the clause names other items too, each statement belongs to the nearest item, and to none when two are
    /// equally near.
    func levels<Level: Hashable & Sendable>(
        of item: String,
        among items: [String],
        vocabulary: LevelVocabulary<Level>,
        codes: [String: Level] = [:]
    ) -> Set<Level>? {
        let own = Self.normalized(item)
        let others = items.map { Self.normalized($0) }.filter { $0 != own && !$0.isEmpty }
        var fromCodes = Set<Level>()
        var fromWords = Set<Level>()

        for sentence in sentences {
            let ownSpans = Self.spans(of: own, in: sentence.folded)
            guard !ownSpans.isEmpty else { continue }
            let otherSpans = others.flatMap { Self.spans(of: $0, in: sentence.folded) }
            let clauses = Self.clauseRanges(of: sentence)

            for statement in Self.statements(in: sentence.folded, vocabulary: vocabulary, codes: codes) {
                guard let nearest = Self.nearest(to: statement.span, in: ownSpans),
                      nearest.gap < (Self.nearest(to: statement.span, in: otherSpans)?.gap ?? Int.max),
                      !Self.isSeparatedByConjunction(statement.span, nearest.span, in: sentence),
                      Self.isInTheClauseOfTheItem(statement.span, item: nearest.span, clauses: clauses, in: sentence.folded),
                      !Self.hedgesOrNegates(Self.clauseText(containing: statement.span, ranges: clauses, in: sentence.folded),
                                           language: vocabularyLanguage) else { continue }

                if statement.isCode {
                    fromCodes.formUnion(statement.levels)
                } else {
                    fromWords.formUnion(statement.levels)
                }
            }
        }

        let allowed = fromCodes.isEmpty ? fromWords : fromCodes
        return allowed.isEmpty ? nil : allowed
    }

    private struct Statement<Level: Hashable & Sendable> {
        let span: Range<Int>
        let levels: Set<Level>
        let isCode: Bool
    }

    private static func statements<Level: Hashable & Sendable>(
        in sentence: String,
        vocabulary: LevelVocabulary<Level>,
        codes: [String: Level]
    ) -> [Statement<Level>] {
        var statements: [Statement<Level>] = []
        var claimed: [Range<Int>] = []

        for entry in vocabulary.phrases {
            for span in spans(of: entry.phrase, in: sentence) where !claimed.contains(where: { $0.overlaps(span) }) {
                claimed.append(span)
                statements.append(Statement(span: span, levels: entry.levels, isCode: false))
            }
        }
        for (code, level) in codes {
            for span in spans(of: code, in: sentence) {
                statements.append(Statement(span: span, levels: [level], isCode: true))
            }
        }
        return statements
    }

    /// The span nearest to `span` and the characters between them (0 when they touch or overlap).
    private static func nearest(to span: Range<Int>, in others: [Range<Int>]) -> (span: Range<Int>, gap: Int)? {
        others
            .map { other in (span: other, gap: max(0, max(span.lowerBound, other.lowerBound) - min(span.upperBound, other.upperBound))) }
            .min { $0.gap < $1.gap }
    }

    /// Whether an "and", "e", "und"... lies between the two spans. The sentence is read with its accents, so "è" (is)
    /// is not taken for "e" (and); if folding the accents changed the length, they are read without them.
    private static func isSeparatedByConjunction(_ first: Range<Int>, _ second: Range<Int>, in sentence: Sentence) -> Bool {
        let start = min(first.upperBound, second.upperBound)
        let end = max(first.lowerBound, second.lowerBound)
        guard start < end else { return false }

        let readable = sentence.accented.utf16.count == sentence.folded.utf16.count ? sentence.accented : sentence.folded
        let units = Array(readable.utf16)
        let between = String(decoding: units[start..<min(end, units.count)], as: UTF16.self)
        return between.split(whereSeparator: { !$0.isLetter }).contains { StatementWords.conjunctions.contains(String($0)) }
    }

    // MARK: - Clauses

    /// The clauses of a sentence as UTF-16 offset ranges of its folded text.
    static func clauseRanges(of sentence: Sentence) -> [Range<Int>] {
        let readable = sentence.accented.utf16.count == sentence.folded.utf16.count ? sentence.accented : sentence.folded
        var ranges: [Range<Int>] = []
        var clauseStart = 0
        var offset = 0

        for word in readable.split(separator: " ", omittingEmptySubsequences: false) {
            let length = word.utf16.count
            if StatementWords.conjunctions.contains(String(word.filter { $0.isLetter })) {
                if offset > clauseStart { ranges.append(clauseStart..<(offset - 1)) }
                clauseStart = offset + length + 1
            } else if word.hasSuffix(",") || word.hasSuffix(";") {
                ranges.append(clauseStart..<(offset + length))
                clauseStart = offset + length + 1
            }
            offset += length + 1
        }
        let end = readable.utf16.count
        if clauseStart < end { ranges.append(clauseStart..<end) }
        return ranges
    }

    /// Whether the statement sits in the clause of the item, or in the next one when that clause starts with it ("Italian,
    /// native", "My English is fluent, B2 on paper", "Swift, niveau intermédiaire"). A clause that starts with another
    /// word is the statement of another item ("French (A2)"), whether or not the draft has it.
    private static func isInTheClauseOfTheItem(_ statement: Range<Int>, item: Range<Int>, clauses: [Range<Int>], in text: String) -> Bool {
        guard let statementClause = clauseIndex(containing: statement.lowerBound, in: clauses),
              let itemClause = clauseIndex(containing: item.lowerBound, in: clauses) else { return false }
        if statementClause == itemClause {
            return true
        }
        guard statementClause == itemClause + 1 else { return false }

        let before = substring(of: text, range: clauses[statementClause].lowerBound..<statement.lowerBound)
        return before.split(whereSeparator: { !$0.isLetter }).allSatisfy { StatementWords.appositionWords.contains(String($0)) }
    }

    /// The clause an offset lies in; nil when it lies in none.
    private static func clauseIndex(containing offset: Int, in ranges: [Range<Int>]) -> Int? {
        ranges.firstIndex { $0.contains(offset) }
    }

    private static func clauseText(containing span: Range<Int>, ranges: [Range<Int>], in text: String) -> String {
        let clause = ranges.first { $0.contains(span.lowerBound) } ?? 0..<text.utf16.count
        return substring(of: text, range: clause)
    }

    static func substring(of text: String, range: Range<Int>) -> String {
        let units = Array(text.utf16)
        let end = min(range.upperBound, units.count)
        guard range.lowerBound < end else { return "" }
        return normalized(String(decoding: units[range.lowerBound..<end], as: UTF16.self))
    }

    /// Whether the sentence holds a negation or a hedge (`StatementWords.hedges`). A hedge of another language that the description's
    /// language has as a word of its own is none (`Vocabulary.isOwnWord`): German "Mai" is a month, Portuguese "no" is "in the".
    static func hedgesOrNegates(_ sentence: String, language: Vocabulary.Language? = nil) -> Bool {
        sentence.contains("n't") || containsAny(StatementWords.hedges.filter { !Vocabulary.isOwnWord($0, in: language) }, in: sentence)
    }

    static func containsAny(_ phrases: [String], in sentence: String) -> Bool {
        phrases.contains { !spans(of: $0, in: sentence).isEmpty }
    }

    // MARK: - Scanning

    private static let minimumPhoneDigits = 6

    /// Lower case, without accents (unless `foldingAccents` is false), with apostrophes, quotes and dashes unified
    /// and white space collapsed. Digits are left as they are: an address holds them exactly.
    static func normalized(_ text: String, foldingAccents: Bool = true) -> String {
        let unified: [(String, String)] = [
            ("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{02BC}", "'"), ("\u{201C}", "\""), ("\u{201D}", "\""),
            ("\u{2013}", "-"), ("\u{2014}", "-"), ("\u{2010}", "-"), ("\u{2011}", "-"),
        ]
        var value = text
        for (from, to) in unified {
            value = value.replacingOccurrences(of: from, with: to)
        }
        let options: String.CompareOptions = foldingAccents ? [.caseInsensitive, .diacriticInsensitive] : [.caseInsensitive]
        let folded = value.folding(options: options, locale: nil)
        return folded.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Where `phrase` occurs in `text` as whole words, as UTF-16 offset ranges.
    static func spans(of phrase: String, in text: String) -> [Range<Int>] {
        guard !phrase.isEmpty else { return [] }

        var spans: [Range<Int>] = []
        var searchStart = text.startIndex
        while let range = text.range(of: phrase, range: searchStart..<text.endIndex) {
            if isBoundary(before: range.lowerBound, in: text) && isBoundary(after: range.upperBound, in: text) {
                let start = text.utf16.distance(from: text.utf16.startIndex, to: range.lowerBound)
                let end = text.utf16.distance(from: text.utf16.startIndex, to: range.upperBound)
                spans.append(start..<end)
            }
            searchStart = text.index(after: range.lowerBound)
        }
        return spans
    }

    private static func isBoundary(before index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        return !isWordCharacter(text[text.index(before: index)])
    }

    private static func isBoundary(after index: String.Index, in text: String) -> Bool {
        guard index < text.endIndex else { return true }
        return !isWordCharacter(text[index])
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
