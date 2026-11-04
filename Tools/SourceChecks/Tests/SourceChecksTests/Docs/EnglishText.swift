import Foundation

// MARK: - English Text

/// Tells which of the app's languages a document is written in, for the check that the documents are in English.
///
/// The measure is the share of the words that are common function words of a language ("the", "and", "of" in English; "der",
/// "und", "nicht" in German). A word that two of the languages share, such as "a" or "in" or "no", counts for none of them,
/// so that the English share of a text cannot come from a German or Spanish article and the other way round. The language
/// with the largest share wins, if its share is not negligible: a page of code and tables has too few function words to say.
enum EnglishText {

    enum Language: String, CaseIterable, Sendable {
        case english, german, italian, french, spanish, portuguese
    }

    /// The least share of a text that the function words of its language make. Prose of any subject has far more; a text
    /// with fewer is code or a table, and says no language.
    static let minimumShare = 0.03

    /// A text of fewer words says too little to be judged.
    static let minimumWords = 20

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

    /// The language whose function words are the largest share of `markdown`, or nil when it has too few words to be judged
    /// or when no language reaches `minimumShare`.
    static func language(of markdown: String) -> Language? {
        let words = words(in: markdown)
        guard words.count >= minimumWords else { return nil }
        var best: (language: Language, share: Double)?
        for language in Language.allCases {
            let known = distinctiveWords[language] ?? []
            let share = Double(words.filter(known.contains).count) / Double(words.count)
            if share > (best?.share ?? 0) { best = (language, share) }
        }
        guard let best, best.share >= minimumShare else { return nil }
        return best.language
    }

    /// The lowercased words of the prose of `markdown`: code blocks, inline code, link targets, addresses and HTML tags are
    /// not prose, and a word ends at anything that is not a letter.
    static func words(in markdown: String) -> [String] {
        var prose = markdown
        for pattern in [#"(?s)```.*?```"#, #"`[^`\n]*`"#, #"\]\([^)\n]*\)"#, #"https?://\S+"#, #"<[^>\n]*>"#] {
            prose = prose.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return prose.lowercased().split { !$0.isLetter }.map(String.init)
    }

    /// `markdown` without the sections of the store listing that are in a language other than English: a section is a heading
    /// of the form `## Language, code` (such as `## German, de-DE`), with everything up to the next heading of its level.
    static func withoutTranslatedSections(_ markdown: String) -> String {
        var kept: [Substring] = []
        var skipping = false
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                skipping = isTranslatedHeading(line)
            }
            if !skipping { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    /// Whether a level-two heading names a language other than English: it ends in `, <code>`, a language code with an
    /// optional region, and the code is not an English one.
    private static func isTranslatedHeading(_ heading: Substring) -> Bool {
        guard let match = heading.firstMatch(of: /, ([a-z]{2,3})(-[A-Z]{2})?$/) else { return false }
        return match.output.1 != "en"
    }
}
