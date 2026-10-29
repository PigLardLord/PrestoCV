import Foundation

/// ADR 0031: a duty the person said with a gerund, shared by two jobs ("setting up the PA systems and mixing the support acts",
/// "controllando i quadri elettrici e programmando la manutenzione preventiva"), in the first person of the job's other duties, so
/// one job does not mix two forms. English puts "I was" (a past job) or "I am" (the current one) before it. Italian, Spanish and
/// Portuguese write each gerund that starts the duty or follows a conjunction or a comma in the first person of the imperfect (a past
/// job) or of the present (the current one), when the word list knows that form. Any other duty, and one with a form the list does
/// not know, keeps its words; each duty starts with a capital letter. A duty that starts with an Italian infinitive in -are or a
/// Portuguese one in -ar is written the same way (#354, round 10).
enum FirstPersonDuty {
    private struct Endings {
        /// The endings of the form the rewrite reads: a gerund's, or an infinitive's.
        let gerunds: [String]
        let past: [String: [String]]
        let present: [String: [String]]
        /// The words of the form the endings write as another word ("estar", not "esto").
        var exceptions: Set<String> = []
        /// The endings of the same form that the rewrite does not write: a part that opens with one keeps the whole duty.
        var unwritten: [String] = []
    }

    private static let endings: [Vocabulary.Language: Endings] = [
        .italian: Endings(
            gerunds: ["ando", "endo"],
            past: ["ando": ["avo"], "endo": ["evo", "ivo"]],
            present: ["ando": ["o"], "endo": ["o", "isco"]]
        ),
        .spanish: Endings(
            gerunds: ["iendo", "yendo", "ando"],
            past: ["ando": ["aba"], "iendo": ["ía"], "yendo": ["ía"]],
            present: ["ando": ["o"], "iendo": ["o"], "yendo": ["o"]]
        ),
        .portuguese: Endings(
            gerunds: ["ando", "endo", "indo"],
            past: ["ando": ["ava"], "endo": ["ia"], "indo": ["ia"]],
            present: ["ando": ["o"], "endo": ["o"], "indo": ["o"]]
        ),
    ]

    /// The Italian infinitives in -are and the Portuguese ones in -ar, which the rewrite reads as it reads a gerund (#354, round 10):
    /// asked for one more duty, the model wrote "Criar um sistema" and wrote it again in the repair. The infinitives in -ere, -ire,
    /// -er and -ir ("manter" is "mantenho", "pedir" is "peço") and the Spanish ones, whose present often changes the stem ("jugar"
    /// is "juego", and "jugo" is another word), stay as they are, and the duty check drops them.
    private static let infinitives: [Vocabulary.Language: Endings] = [
        .italian: Endings(gerunds: ["are"], past: ["are": ["avo"]], present: ["are": ["o"]], exceptions: ["fare"], unwritten: ["ere", "ire"]),
        .portuguese: Endings(gerunds: ["ar"], past: ["ar": ["ava"]], present: ["ar": ["o"]], exceptions: ["estar"], unwritten: ["er", "ir"]),
    ]

    private static let joiners: Set<String> = ["e", "ed", "y", "and"]
    /// English words in -ing that are no gerund of a duty.
    private static let notGerunds: Set<String> = [
        "bring", "string", "spring", "swing", "sling", "sting", "during", "nothing", "something", "everything", "anything", "morning", "evening", "ceiling",
    ]

    static func written(_ duty: String, current: Bool, language: Vocabulary.Language?, wordList: any WordList) -> String {
        let tokens = duty.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = tokens.first else { return duty }
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        switch language {
        case .english:
            let word = letters(first)
            guard word.count > 4, word.hasSuffix("ing"), !notGerunds.contains(word), first != first.uppercased() else { return capitalised(duty) }
            return (current ? "I am " : "I was ") + String(first.prefix(1)).lowercased() + duty.dropFirst()
        case let language?:
            let forms = [endings[language], infinitives[language]].compactMap { $0 }
            guard let rules = forms.first(where: { isGerund(letters(first), $0) }) else { return capitalised(duty) }
            var converted: [String] = []
            for (index, token) in tokens.enumerated() {
                let previous = index > 0 ? tokens[index - 1] : nil
                let opensAPart = previous == nil || previous.map { $0.hasSuffix(",") || joiners.contains(letters($0)) } == true
                guard opensAPart, isOfTheForm(letters(token), rules) else { converted.append(token); continue }
                guard isGerund(letters(token), rules) else { return capitalised(duty) }
                guard let form = firstPerson(of: token, rules, current: current, language: language, wordList: wordList) else {
                    return capitalised(duty)
                }
                converted.append(form)
            }
            return capitalised(converted.joined(separator: " "))
        case nil:
            return capitalised(duty)
        }
    }

    /// Whether `word` ends as a word of the form, one the rewrite writes or not.
    private static func isOfTheForm(_ word: String, _ rules: Endings) -> Bool {
        (rules.gerunds + rules.unwritten).contains { word.count > $0.count + 1 && word.hasSuffix($0) }
    }

    private static func isGerund(_ word: String, _ rules: Endings) -> Bool {
        !rules.exceptions.contains(word) && rules.gerunds.contains { word.count > $0.count + 1 && word.hasSuffix($0) }
    }

    /// The first person of the gerund `token`, with the punctuation it ends with, or nil when the word list knows none of its forms.
    private static func firstPerson(
        of token: String, _ rules: Endings, current: Bool, language: Vocabulary.Language, wordList: any WordList
    ) -> String? {
        let trailing = String(token.reversed().prefix { !$0.isLetter }.reversed())
        let word = String(token.dropLast(trailing.count))
        guard let ending = rules.gerunds.first(where: { word.lowercased().hasSuffix($0) }) else { return nil }
        let stem = String(word.dropLast(ending.count))
        let candidates = ((current ? rules.present : rules.past)[ending] ?? []).map { stem + $0 }
        guard let known = candidates.first(where: { wordList.knows($0.lowercased(), inLanguage: language.rawValue) == true }) else { return nil }
        return known + trailing
    }

    private static func capitalised(_ text: String) -> String {
        guard let head = text.first else { return text }
        return String(head).uppercased() + text.dropFirst()
    }
}
