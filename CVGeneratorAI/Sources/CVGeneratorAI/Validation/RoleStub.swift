import Foundation

/// A sentence of a job's description that says nothing but that the person held the job (#354): "Lavoro.", "Trabajé como auxiliar
/// en una guardería.", "Sono stato aiuto cuoco." The first pass quotes such a sentence of the description as the job's text, and the
/// draft shows it in front of the duties the second pass wrote, where it restates the title and the employer the job already shows.
enum RoleStub {
    /// Whether every word of `sentence` is a function, time or modality word (`Vocabulary.isNeutral`), a form of "be" or an auxiliary,
    /// a form of "work", or a word of `jobWords` (the job's title and employer, as `Word.folded` writes them).
    static func isStub(_ sentence: String, jobWords: Set<String>, language: Vocabulary.Language?) -> Bool {
        let words = Word.words(in: sentence)
        return !words.isEmpty && words.allSatisfy { word in
            jobWords.contains(word.folded)
                || Vocabulary.isNeutral(word.folded, in: language)
                || Vocabulary.isBeForm(word.accented, in: language)
                || Vocabulary.isAuxiliary(word.accented, in: language)
                || isWorking(word.folded, in: language)
        }
    }

    /// Whether `word` is a form of the verb "work", in the language of the description when it is known.
    private static func isWorking(_ word: String, in language: Vocabulary.Language?) -> Bool {
        let stems = language.map { stemsOfWork[$0] ?? [] } ?? stemsOfWork.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        return stems.contains { word.hasPrefix($0) }
    }

    /// The stems of the forms of "work", as `Word.folded` writes them: no noun of a trade starts with one but the worker itself,
    /// which says no more than the title does.
    private static let stemsOfWork: [Vocabulary.Language: Set<String>] = [
        .english: ["work"],
        .italian: ["lavor"],
        .spanish: ["trabaj"],
        .portuguese: ["trabalh"],
        .french: ["travail"],
        .german: ["arbeit", "gearbeitet"],
    ]
}
