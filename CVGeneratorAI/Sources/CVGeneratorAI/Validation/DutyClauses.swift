import Foundation

// MARK: The duties a job's text says

/// The duty clauses of a job's text (#354): a sentence of 2 words or more is one clause, and one more after each ";" and
/// after each "," or "and" (und, e, ed, y, et) whose next word, past a subject pronoun or "also", is a verb: a CV verb of the
/// language (`Vocabulary.Words.verbs`), an English word in -ing or -ed of 5 letters or more, or a word that is no function word
/// followed by an article. Read by its sentences, a job of two sentences of two duties each ("I plan the sound design and train
/// the junior technicians.") got typical duties it did not need, which said an abstract duty. The evaluation's reader counts
/// duties the same way (`probe/r3/clauses.py`, kept in step).
enum DutyClauses {
    /// How many duties `text`, in `language`, says.
    static func count(in text: String, language: Vocabulary.Language?) -> Int {
        sentences(of: text).reduce(0) { $0 + clauses(of: $1, language: language) }
    }

    private static func sentences(of text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        var ended = false
        for character in text {
            if ended, character.isWhitespace {
                sentences.append(current)
                current = ""
                ended = false
                continue
            }
            ended = ".!?".contains(character)
            current.append(character)
        }
        return sentences + [current]
    }

    private static func tokens(of sentence: String) -> [String] {
        var tokens: [String] = []
        var word = ""
        for character in sentence {
            if character.isLetter {
                word.append(character)
                continue
            }
            if !word.isEmpty { tokens.append(word) }
            word = ""
            if character == "," || character == ";" { tokens.append(String(character)) }
        }
        return word.isEmpty ? tokens : tokens + [word]
    }

    private static func clauses(of sentence: String, language: Vocabulary.Language?) -> Int {
        let tokens = tokens(of: sentence)
        let isMark = { (token: String) in token == "," || token == ";" }
        guard tokens.count(where: { !isMark($0) }) >= 2 else { return 0 }
        var count = 1
        for (index, token) in tokens.enumerated() {
            if token == ";" {
                if index + 1 < tokens.count { count += 1 }
                continue
            }
            guard token == "," || joins.contains(token.lowercased()) else { continue }
            var next = index + 1
            while next < tokens.count, subjects.contains(tokens[next].lowercased()) { next += 1 }
            guard next < tokens.count, !isMark(tokens[next]) else { continue }
            let after = next + 1 < tokens.count && !isMark(tokens[next + 1]) ? tokens[next + 1] : nil
            if isVerb(tokens[next], after: after, language: language) { count += 1 }
        }
        return count
    }

    private static func isVerb(_ word: String, after: String?, language: Vocabulary.Language?) -> Bool {
        let folded = DescriptionText.normalized(word)
        let articles = language.flatMap { Self.articles[$0] } ?? []
        guard !articles.contains(folded), !(language.flatMap { notVerbs[$0] } ?? []).contains(folded) else { return false }
        if let language, language.words.verbs.contains(folded) { return true }
        if language == .english, folded.count >= 5, folded.hasSuffix("ing") || folded.hasSuffix("ed") { return true }
        if language == .german, word.first?.isUppercase == true { return false }
        return after.map { articles.contains(DescriptionText.normalized($0)) } ?? false
    }

    private static let joins: Set<String> = ["and", "und", "e", "ed", "y", "et"]
    private static let subjects: Set<String> = ["i", "ich", "je", "j", "io", "yo", "eu", "also"]

    /// The articles and determiners of each language, without accents.
    private static let articles: [Vocabulary.Language: Set<String>] = [
        .english: ["the", "a", "an", "my", "our", "their", "his", "her", "its", "all", "each", "every", "this", "these", "those", "some"],
        .italian: ["il", "lo", "la", "l", "i", "gli", "le", "un", "uno", "una"],
        .spanish: ["el", "la", "los", "las", "un", "una", "unos", "unas"],
        .portuguese: ["o", "a", "os", "as", "um", "uma", "uns", "umas"],
        .french: ["le", "la", "les", "l", "un", "une", "des", "du"],
        .german: ["der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer"],
    ]

    /// The prepositions, conjunctions and negations that start no clause, without accents.
    private static let notVerbs: [Vocabulary.Language: Set<String>] = [
        .english: ["with", "for", "to", "of", "on", "in", "at", "by", "from", "into", "across", "throughout", "during", "and", "or", "not"],
        .italian: ["di", "da", "a", "in", "con", "su", "per", "tra", "fra", "e", "o", "non", "anche"],
        .spanish: ["de", "a", "en", "con", "por", "para", "sobre", "entre", "y", "o", "no", "tambien"],
        .portuguese: ["de", "a", "em", "com", "por", "para", "sobre", "entre", "e", "ou", "nao", "tambem", "no", "na", "nos", "nas"],
        .french: ["de", "a", "en", "avec", "pour", "par", "sur", "dans", "entre", "et", "ou", "ne", "pas", "aussi"],
        .german: ["mit", "fur", "zu", "von", "an", "auf", "in", "bei", "aus", "und", "oder", "nicht", "auch", "dass"],
    ]
}
