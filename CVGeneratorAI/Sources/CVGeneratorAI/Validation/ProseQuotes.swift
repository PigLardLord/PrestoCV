import Foundation

/// The clauses of the description that a prose clause may quote (ADR 0023, rule (d)).
///
/// Each clause of a summary sentence, a role description or an achievement must quote one clause of the description: the same words,
/// in the same forms and the same order. Case, diacritics, white space and punctuation are ignored, and no lemma is used. The quote
/// runs to the end of that clause, or to the start of its purpose tail, and may leave out only a lead-in (see `LeadIn`). A quote
/// keeps the user's own claim, with its subject, its voice and its negation: "I was trained by Acme" does not keep "I trained
/// Acme", and "My colleague managed a school" does not keep "I managed a school".
struct ProseQuotes {
    /// A clause of the description, and where a quote of it may end.
    struct Source {
        let words: [Word]
        /// The numbers of words a quote may run to: the whole clause, or up to where its purpose tail starts.
        let ends: [Int]

        /// - Parameter ends: Where a quote may end; the end of the clause when there is no purpose tail.
        init(_ clause: Clause, ends: [Int]? = nil) {
            words = clause.words
            self.ends = ends ?? [clause.words.count]
        }
    }

    private let sources: [Source]
    private let language: Vocabulary.Language?

    init(sources: [Source], language: Vocabulary.Language?) {
        self.sources = sources
        self.language = language
    }

    /// The same quotes with the sources of `other` too.
    func adding(_ other: ProseQuotes) -> ProseQuotes {
        ProseQuotes(sources: sources + other.sources, language: language)
    }

    /// Whether the words of a clause of prose are a quote of one of the sources.
    func quotes(_ prose: [Word]) -> Bool {
        let wanted = prose.map(\.folded)
        guard !wanted.isEmpty else { return false }

        return sources.contains { source in
            source.ends.contains { end in
                guard end >= wanted.count, end <= source.words.count else { return false }
                let start = end - wanted.count
                return source.words[start..<end].map(\.folded) == wanted && LeadIn.holds(source.words[..<start], in: language)
            }
        }
    }
}

/// What a quote may leave out at the start of its clause: first-person pronouns and joining words ("I", "where I"; "io", "dove";
/// "ich", "wo ich"; "je", "j'", "où"; "yo", "donde"; "eu", "onde"), with the auxiliary or the form of "to be" that follows them ("I
/// have", "I'm", "où j'ai", "ho", "sono", "ich habe"). Never an article, a word of negation, doubt, wish, future or condition, or
/// any other word.
enum LeadIn {
    private struct Words {
        /// The pronouns and joining words, as `Word.folded` writes them.
        let leading: Set<String>
        /// The forms that say "I have" or "I am" without a pronoun, in the languages that drop it.
        let alone: Set<String>
    }

    private static let words: [Vocabulary.Language: Words] = [
        .english: Words(leading: ["i", "where"], alone: []),
        .italian: Words(leading: ["io", "mi", "m", "dove"], alone: ["ho", "sono"]),
        .german: Words(leading: ["ich", "wo"], alone: []),
        .spanish: Words(leading: ["yo", "me", "donde"], alone: ["he", "soy"]),
        .french: Words(leading: ["je", "j", "me", "m", "ou"], alone: []),
        .portuguese: Words(leading: ["eu", "me", "onde"], alone: ["tenho", "sou"]),
    ]

    private static let everyLeadingWord: Set<String> = words.values.reduce(into: []) { $0.formUnion($1.leading) }

    /// Whether `words`, the start of a clause, is a lead-in: nothing, or pronouns and joining words, then at most one auxiliary or form
    /// of "to be". Without a pronoun that form must be one that says "I have" or "I am" on its own.
    static func holds(_ words: ArraySlice<Word>, in language: Vocabulary.Language?) -> Bool {
        guard !words.isEmpty else { return true }

        let rules = language.flatMap { Self.words[$0] }
        let leading = rules?.leading ?? everyLeadingWord
        let rest = words.drop(while: { leading.contains($0.folded) })
        guard rest.count <= 1 else { return false }
        guard let form = rest.first else { return true }

        let isAuxiliary = Vocabulary.isBeForm(form.accented, in: language) || Vocabulary.isAuxiliary(form.accented, in: language)
        return isAuxiliary && (rest.count < words.count || rules?.alone.contains(form.folded) == true)
    }
}
