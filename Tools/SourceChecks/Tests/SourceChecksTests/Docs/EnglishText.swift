import Foundation

// MARK: - English Text

/// Tells which of the app's languages a passage is written in, for the check that the documents are in English.
///
/// The measure is the number of common function words of a language ("the", "and", "of" in English; "der", "und", "nicht" in
/// German) in a text. A word that two of the languages share, such as "a" or "in" or "no", counts for none of them, so that
/// the English count of a text cannot come from a German or Spanish article and the other way round. The rule:
///
/// - A language wins a text if it has at least `minimumHits` of the distinctive function words, they are at least
///   `minimumShare` of the words (a page of code and tables has too few to say), and it has `margin` times as many as the next
///   language, so that a tie or a close call says no language (`language(of:)`). A text of any length is judged this way: a
///   short German sentence is German, and one with fewer than `minimumHits` such words says nothing.
/// - A document is not judged as a whole but passage by passage (`passages(in:)`: each heading, table row and list item, and
///   each sentence of a paragraph), because a bilingual document has English enough to hide its German.
/// - A short quotation, one sentence of at most `maximumQuotationWords` words between double quotation marks, does not count:
///   the decision records quote examples in the languages of the app inside English sentences. A longer quotation, or one of
///   more sentences, is text, and its sentences are passages; a short quotation inside it, with the other marks, does not
///   count either. German that stands outside quotation marks is a foreign passage, and so is a mark that has no partner.
/// - A passage in another script (Cyrillic, Greek, Arabic, Chinese, ...) is not English: a tenth of its letters, and at least
///   `minimumOtherScriptLetters` of them, are outside the Latin script. A Greek letter in an equation is not a script.
/// - Latin-script languages other than the six of the app are out of scope: a Dutch passage has no word of the lists and
///   says no language.
enum EnglishText {

    enum Language: String, CaseIterable, Sendable {
        case english, german, italian, french, spanish, portuguese
    }

    /// What a passage is when it is not English or cannot be told: a language of the app, or a script other than Latin.
    enum Verdict: Equatable, Sendable, CustomStringConvertible {
        case language(Language)
        case otherScript

        var description: String {
            switch self {
            case .language(let language): language.rawValue
            case .otherScript: "a script other than Latin"
            }
        }
    }

    /// The fewest distinctive function words of a language that say a text is in it.
    static let minimumHits = 3

    /// The least share of the words of a text that the distinctive function words of its language make. Prose of any subject
    /// has far more; a text with fewer is code or a table.
    static let minimumShare = 0.03

    /// How many times as many distinctive function words as the next language a language needs to win.
    static let margin = 1.5

    /// The share of the letters of a text in a script other than Latin from which the text is in another script.
    static let otherScriptShare = 0.1

    /// The fewest letters in another script that make a script, so that a Greek letter or two in an equation is not one.
    static let minimumOtherScriptLetters = 3

    /// The most words of a quotation that does not count, which is also one sentence at most. The decision records quote
    /// examples of one sentence, the longest of them fifteen words; a longer quotation, or one of more sentences, is text.
    static let maximumQuotationWords = 20

    private static let functionWords: [Language: Set<String>] = [
        .english: [
            "the", "a", "an", "and", "of", "to", "in", "on", "is", "are", "was", "were", "be", "been", "that", "this", "these",
            "those", "with", "for", "not", "no", "as", "by", "it", "its", "from", "or", "which", "can", "has", "have", "had",
            "will", "would", "but", "if", "when", "than", "then", "each", "only", "any", "all", "you", "your", "they", "their",
            "what", "how", "so", "at", "also", "he", "she", "we", "his", "her", "our", "me", "my", "do", "does", "there",
        ],
        .german: [
            "der", "die", "das", "den", "dem", "des", "und", "ist", "nicht", "mit", "ein", "eine", "einen", "zu", "von", "für",
            "auf", "in", "an", "sich", "auch", "wird", "werden", "im", "es", "sind", "wir", "sie", "ich", "oder", "aber", "bei", "nach",
            "wenn", "dass", "wie", "aus", "nur", "noch", "kann", "hat", "war", "wurde", "man", "um", "über",
        ],
        .italian: [
            "il", "lo", "la", "le", "gli", "di", "che", "per", "con", "non", "una", "un", "uno", "è", "sono", "del", "della",
            "dei", "delle", "nel", "nella", "alla", "come", "più", "anche", "ma", "se", "si", "questo", "questa", "viene",
            "essere", "può", "sul", "dal", "nei", "agli", "a", "in",
        ],
        .french: [
            "le", "la", "les", "des", "du", "de", "et", "est", "une", "un", "que", "pour", "dans", "avec", "pas", "sur", "ce",
            "qui", "au", "aux", "ne", "ou", "sont", "par", "plus", "il", "elle", "nous", "vous", "cette", "être", "peut",
            "mais", "ses", "leur", "sans", "où", "à", "a",
        ],
        .spanish: [
            "el", "la", "los", "las", "de", "del", "que", "y", "en", "un", "una", "es", "por", "con", "para", "no", "se", "su",
            "al", "lo", "como", "más", "pero", "son", "este", "esta", "puede", "ser", "sin", "también", "sus", "cada", "a", "o",
        ],
        .portuguese: [
            "o", "a", "os", "as", "de", "do", "da", "dos", "das", "que", "e", "em", "um", "uma", "para", "com", "não", "se",
            "por", "é", "são", "mais", "mas", "como", "seu", "sua", "pode", "ser", "também", "sem", "nos", "na", "no", "ao",
        ],
    ]

    /// The words that count for each language: its function words that no other language of the list uses.
    private static let distinctiveWords: [Language: Set<String>] = {
        var distinctive: [Language: Set<String>] = [:]
        for (language, words) in functionWords {
            let others = functionWords.filter { $0.key != language }.values.reduce(into: Set<String>()) { $0.formUnion($1) }
            distinctive[language] = words.subtracting(others)
        }
        return distinctive
    }()

    /// The language of `text` if it wins by a margin, or nil when no language does: `minimumHits` words, `minimumShare` of the
    /// words and `margin` times the next language.
    static func language(of text: String) -> Language? {
        let found = words(in: text)
        return winner(of: hits(in: found), among: found.count)
    }

    /// What `text` is: a text in another script, the language that wins it (`language(of:)`), or nil when there is nothing to
    /// say. It is `.language(.english)` for English.
    static func verdict(of text: String) -> Verdict? {
        isInAnotherScript(text) ? .otherScript : language(of: text).map(Verdict.language)
    }

    /// The first passage of `markdown` that is not English, with what it is.
    static func firstNotEnglish(in markdown: String) -> (passage: String, verdict: Verdict)? {
        for passage in passages(in: markdown) {
            if let verdict = verdict(of: passage), verdict != .language(.english) { return (passage, verdict) }
        }
        return nil
    }

    // MARK: - Words and passages

    /// The lowercased words of the prose of `markdown`: code, comments, link targets, addresses and HTML tags are not prose,
    /// and a word ends at anything that is not a letter.
    static func words(in markdown: String) -> [String] {
        MarkdownText.prose(markdown).lowercased().split { !$0.isLetter }.map(String.init)
    }

    /// The passages a document is judged by: each heading, table row and list item, and each sentence of a paragraph, without
    /// the short quotations in them; then each sentence of the other quotations of the block. A sentence ends at `.`, `!` or
    /// `?` and a space, unless a lowercase letter follows (`e.g. the`, `U.S. text`); a quotation is taken out before the text
    /// is split, so that it may hold sentences of its own.
    static func passages(in markdown: String) -> [String] {
        MarkdownText.blocks(in: markdown).flatMap { block -> [String] in
            let (text, judged) = quotations(in: block.text)
            let own: [String]
            switch block.kind {
            case .heading, .tableRow: own = text.isEmpty ? [] : [text]
            case .listItem, .paragraph: own = sentences(in: text)
            }
            return own + judged.flatMap(sentences(in:))
        }
    }

    /// `text` without the text between double quotation marks, straight (`"..."`) or curly (`“...”`), and the quotations that
    /// are judged as text: those that are not short (`isShortQuotation`). A quotation that is judged is read as `text` is,
    /// so a quotation inside it with the other marks is short or judged by itself; its own text comes before the quotations
    /// in it. A mark that has no partner in the text quotes nothing.
    private static func quotations(in text: String) -> (outside: String, judged: [String]) {
        var judged: [String] = []
        let outside = text.replacing(/"([^"]*)"|\u{201C}([^\u{201D}]*)\u{201D}/) { match in
            let quoted = String(match.output.1 ?? match.output.2 ?? "")
            if !isShortQuotation(quoted) {
                let (own, inner) = quotations(in: quoted)
                if !own.isEmpty { judged.append(own) }
                judged += inner
            }
            return " "
        }
        return (collapsed(outside), judged)
    }

    /// Whether a quotation does not count: one sentence at most, of at most `maximumQuotationWords` words. Each quotation is
    /// measured alone, so a run of short quotations does not count either; the check finds documents written in another
    /// language, not text hidden from it on purpose.
    private static func isShortQuotation(_ quoted: String) -> Bool {
        sentences(in: collapsed(quoted)).count <= 1 && words(in: quoted).count <= maximumQuotationWords
    }

    /// `text` with one space between its words, and none around them.
    private static func collapsed(_ text: some StringProtocol) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func sentences(in text: String) -> [String] {
        let characters = Array(text)
        var sentences: [String] = []
        var current = ""
        for (index, character) in characters.enumerated() {
            current.append(character)
            guard ".!?".contains(character), index + 2 < characters.count, characters[index + 1] == " ", !characters[index + 2].isLowercase else { continue }
            sentences.append(current.trimmingCharacters(in: .whitespaces))
            current = ""
        }
        sentences.append(current.trimmingCharacters(in: .whitespaces))
        return sentences.filter { !$0.isEmpty }
    }

    // MARK: - Counting

    private static func hits(in words: [String]) -> [Language: Int] {
        var hits: [Language: Int] = [:]
        for language in Language.allCases {
            let known = distinctiveWords[language] ?? []
            hits[language] = words.filter(known.contains).count
        }
        return hits
    }

    private static func winner(of hits: [Language: Int], among wordCount: Int) -> Language? {
        let ranked = hits.sorted { $0.value > $1.value }
        guard let best = ranked.first, best.value >= minimumHits, Double(best.value) / Double(wordCount) >= minimumShare else { return nil }
        let second = ranked.dropFirst().first?.value ?? 0
        return Double(best.value) >= margin * Double(second) ? best.key : nil
    }

    /// Whether a tenth of the letters of the prose of `text`, and at least `minimumOtherScriptLetters`, are not Latin.
    private static func isInAnotherScript(_ text: String) -> Bool {
        var letters = 0
        var other = 0
        for character in MarkdownText.prose(text) where character.isLetter {
            letters += 1
            if !isLatin(character) { other += 1 }
        }
        return other >= minimumOtherScriptLetters && Double(other) / Double(letters) >= otherScriptShare
    }

    /// Whether a letter is Latin with its accents: Basic Latin to Latin Extended-B, and Latin Extended Additional.
    private static func isLatin(_ letter: Character) -> Bool {
        guard let scalar = letter.unicodeScalars.first?.value else { return true }
        return scalar <= 0x024F || (0x1E00...0x1EFF).contains(scalar)
    }

    // MARK: - Translated sections

    /// The languages of the store listing's translated sections, by the name the listing gives them and their code.
    private static let listingLanguages = [
        "German": "de", "Italian": "it", "French": "fr", "Spanish": "es", "Portuguese": "pt", "Chinese": "zh",
    ]

    /// `markdown` without the sections of the store listing that are in a language other than English: a section is a heading
    /// of the form `## Language, code` (such as `## German, de-DE`), with everything up to the next heading of level one or
    /// two. A heading in a code fence is not a heading, and the line ending of the file does not matter.
    static func withoutTranslatedSections(_ markdown: String) -> String {
        let lines = MarkdownText.lines(of: markdown)
        var kept: [Substring] = []
        var skipping = false
        for (line, isFenced) in zip(lines, MarkdownText.fencedLines(in: lines)) {
            if !isFenced, let level = MarkdownText.headingLevel(of: line), level <= 2 {
                skipping = isTranslatedHeading(String(line))
            }
            if !skipping { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    /// Whether a line is the heading of a translated section: `## Name, code` or `## Name (Region), code-REGION`, where the
    /// name is one of the listing's languages and the code is its code. A name the listing does not know, or a code that is
    /// not the one of the name, is not a translated section, and its text is read like any other.
    static func isTranslatedHeading(_ heading: String) -> Bool {
        let line = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = line.wholeMatch(of: /## ([A-Za-z]+)(?: \([^)]+\))?, ([a-z]{2,3})(?:-[A-Za-z]{2,4})?/) else { return false }
        return listingLanguages[String(match.output.1)] == String(match.output.2)
    }
}
