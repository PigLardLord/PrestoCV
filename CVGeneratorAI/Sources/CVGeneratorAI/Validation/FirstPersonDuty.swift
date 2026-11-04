import Foundation

/// ADR 0031: a duty the person said with a gerund, shared by two jobs ("setting up the PA systems and mixing the support acts",
/// "controllando i quadri elettrici e programmando la manutenzione preventiva"), in the first person of the job's other duties, so
/// one job does not mix two forms. English puts "I was" (a past job) or "I am" (the current one) before it. Italian, Spanish and
/// Portuguese write each gerund that starts the duty or follows a conjunction or a comma in the first person of the imperfect (a past
/// job) or of the present (the current one), when the word list knows that form. A duty in the first person keeps its words, but for
/// a gerund that opens a later part ("Controllavo i quadri e programmando la manutenzione", #362), which is written the same way when
/// it is the gerund of a verb the word list knows and no first person of another (`isWritten`: "e prendo" stays), as does a first
/// word in the first person that ends as one ("Prendo le ordinazioni"). A duty with a
/// form the list does not know keeps its words; each duty starts with a capital letter. A duty that starts with an Italian infinitive
/// in -are or a Portuguese one in -ar is written the same way (#354, round 10), and one in -ere or -ire of an ended Italian job
/// (round 14).
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
        /// The endings of the infinitive of each gerund's verb: "programmando" is a gerund of "programmare" (#362).
        var verbs: [String: [String]] = [:]
    }

    private static let endings: [Vocabulary.Language: Endings] = [
        .italian: Endings(
            gerunds: ["ando", "endo"],
            past: ["ando": ["avo"], "endo": ["evo", "ivo"]],
            present: ["ando": ["o"], "endo": ["o", "isco"]],
            verbs: ["ando": ["are"], "endo": ["ere", "ire"]]
        ),
        .spanish: Endings(
            gerunds: ["iendo", "yendo", "ando"],
            past: ["ando": ["aba"], "iendo": ["ía"], "yendo": ["ía"]],
            present: ["ando": ["o"], "iendo": ["o"], "yendo": ["o"]],
            verbs: ["ando": ["ar"], "iendo": ["er", "ir"], "yendo": ["er", "ir"]]
        ),
        .portuguese: Endings(
            gerunds: ["ando", "endo", "indo"],
            past: ["ando": ["ava"], "endo": ["ia"], "indo": ["ia"]],
            present: ["ando": ["o"], "endo": ["o"], "indo": ["o"]],
            verbs: ["ando": ["ar"], "endo": ["er"], "indo": ["ir"]]
        ),
    ]

    /// The Italian infinitives in -are and the Portuguese ones in -ar, which the rewrite reads as it reads a gerund (#354, round 10):
    /// asked for one more duty, the model wrote "Criar um sistema" and wrote it again in the repair. The Italian ones in -ere and -ire
    /// are written in the imperfect of an ended job, whose endings do not change the stem ("seguire" is "seguivo", #354, round 14),
    /// but for "essere"; in the current job they stay as they are, as their present often changes the stem ("tenere" is "tengo",
    /// and "volere" is not "volo"). The Portuguese ones in -er and -ir ("manter" is "mantenho", "pedir" is "peço") and the Spanish
    /// ones ("jugar" is "juego", and "jugo" is another word) stay as they are, and the duty check drops them.
    private static let infinitives: [Vocabulary.Language: Endings] = [
        .italian: Endings(
            gerunds: ["are", "ere", "ire"], past: ["are": ["avo"], "ere": ["evo"], "ire": ["ivo"]], present: ["are": ["o"]],
            exceptions: ["fare", "essere"]
        ),
        .portuguese: Endings(gerunds: ["ar"], past: ["ar": ["ava"]], present: ["ar": ["o"]], exceptions: ["estar"], unwritten: ["er", "ir"]),
    ]

    /// The words that join two parts of a duty.
    static let joiners: Set<String> = ["e", "ed", "y", "and"]
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
            guard let rules = opening(letters(first), language: language, wordList: wordList) else {
                return capitalised(withLaterGerundsWritten(tokens, current: current, language: language, wordList: wordList) ?? duty)
            }
            var converted: [String] = []
            for (index, token) in tokens.enumerated() {
                let opens = index == 0 || opensAPart(after: tokens[index - 1])
                guard opens, isOfTheForm(letters(token), rules) else { converted.append(token); continue }
                guard isGerund(letters(token), rules) else { return capitalised(duty) }
                // A first person that ends as a gerund ("prendo") keeps its words (#362).
                guard isWritten(letters(token), rules, language: language, wordList: wordList) else { converted.append(token); continue }
                guard let form = firstPerson(of: token, rules, current: current, language: language, wordList: wordList) else {
                    return capitalised(duty)
                }
                converted.append(form)
            }
            // A part after an infinitive may open with a gerund ("controlar os quadros e revisando as notas").
            let opened = converted.joined(separator: " ")
            return capitalised(withLaterGerundsWritten(converted, current: current, language: language, wordList: wordList) ?? opened)
        case nil:
            return capitalised(duty)
        }
    }

    /// Whether `duty`, which opens in the first person, has a later part that opens with a gerund (`isWritten`), as the rewrite
    /// leaves one whose first person the word list does not know (#362): "Sostituisco i cuscinetti e lubrificando i motori" mixes two
    /// forms, and the duty check drops it.
    static func joinsAGerund(_ duty: String, language: Vocabulary.Language?, wordList: any WordList) -> Bool {
        guard let language, let rules = endings[language] else { return false }
        let tokens = duty.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        guard let first = tokens.first, opening(letters(first), language: language, wordList: wordList) == nil else { return false }
        return tokens.indices.dropFirst().contains { index in
            opensAPart(after: tokens[index - 1]) && isWritten(letters(tokens[index]), rules, language: language, wordList: wordList)
        }
    }

    /// `tokens`, of a duty that opens in the first person, with each later part that opens with a gerund (`isWritten`) in the
    /// first person of the job (#362), or nil when the word list knows the first person of none of one such gerund's forms.
    private static func withLaterGerundsWritten(
        _ tokens: [String], current: Bool, language: Vocabulary.Language, wordList: any WordList
    ) -> String? {
        guard let rules = endings[language] else { return nil }
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        var converted: [String] = []
        for (index, token) in tokens.enumerated() {
            guard index > 0, opensAPart(after: tokens[index - 1]),
                  isWritten(letters(token), rules, language: language, wordList: wordList) else {
                converted.append(token)
                continue
            }
            guard let form = firstPerson(of: token, rules, current: current, language: language, wordList: wordList) else { return nil }
            converted.append(form)
        }
        return converted.joined(separator: " ")
    }

    /// Whether the word after `previous` opens a part of a duty: `previous` ends with a comma or joins two parts.
    private static func opensAPart(after previous: String) -> Bool {
        previous.hasSuffix(",") || joiners.contains(previous.lowercased().filter(\.isLetter))
    }

    /// The form of `language` that the first word of a duty, `word`, is written in: the gerund's when `isWritten`, else the
    /// infinitive's, or nil when it is neither ("prendo" keeps the duty as the person said it, #362).
    private static func opening(_ word: String, language: Vocabulary.Language, wordList: any WordList) -> Endings? {
        if let rules = endings[language], isWritten(word, rules, language: language, wordList: wordList) { return rules }
        return infinitives[language].flatMap { isGerund(word, $0) ? $0 : nil }
    }

    /// Whether `word`, which opens a part of a duty, is a gerund the rewrite writes (#362): the gerund of a verb the word list knows
    /// ("programmando", of "programmare"), and no first person of another verb ("prendo", of "prendere"; "atendo", of "atender")
    /// nor a word that ends as one and is no verb's ("quando"). Those keep their words. A form with no verbs (an infinitive's) is
    /// written when it ends as one.
    private static func isWritten(_ word: String, _ rules: Endings, language: Vocabulary.Language, wordList: any WordList) -> Bool {
        guard isGerund(word, rules) else { return false }
        guard !rules.verbs.isEmpty else { return true }
        guard let ending = rules.gerunds.first(where: { word.hasSuffix($0) }) else { return false }
        let knows = { (candidate: String) in wordList.knows(candidate, inLanguage: language.rawValue) == true }
        let stem = String(word.dropLast(ending.count))
        let verbs: [String] = (rules.verbs[ending] ?? []).map { stem + $0 }
        let verbsOfAFirstPerson: [String] = Set(rules.verbs.values.joined()).map { String(word.dropLast()) + $0 }
        return verbs.contains(where: knows) && !verbsOfAFirstPerson.contains(where: knows)
    }

    /// The perfective past of each language that has two pasts: the word its first duty opens with that marks it, the ending of
    /// the imperfect the rewrite reads, and what it writes for the first part and for each later one.
    private struct Perfective: Sendable {
        let marks: @Sendable (String) -> Bool
        let imperfect: String
        let first: @Sendable (String) -> String
        let later: @Sendable (String) -> String
        /// The other endings of the imperfect, which the rewrite does not write: a part that opens with one keeps the whole duty.
        let unwritten: [String]
    }

    private static let perfectives: [Vocabulary.Language: Perfective] = [
        .italian: Perfective(
            marks: { $0 == "ho" }, imperfect: "avo", first: { "Ho " + $0 + "ato" }, later: { $0 + "ato" }, unwritten: ["evo", "ivo"]
        ),
        .portuguese: Perfective(
            marks: { $0.count > 3 && $0.hasSuffix("ei") }, imperfect: "ava", first: { capitalised($0 + "ei") }, later: { $0 + "ei" },
            unwritten: ["ia"]
        ),
    ]

    /// `duty` of an ended job in the past its first `held` duty uses (#354, round 12): after "Ho gestito…", the rewrite of an
    /// infinitive, or the model, wrote "Verificavo…", and the job mixed two pasts. When that duty opens with the perfective past
    /// (`Perfective`), each part of `duty` that opens with the imperfect in -avo (Italian) or -ava (Portuguese) is written in it:
    /// "Ho verificato… e preparato…", "Revisei… e organizei…". A part in another imperfect, or a form the word list does not know,
    /// keeps the whole duty.
    static func inThePast(of held: [String], _ duty: String, language: Vocabulary.Language?, wordList: any WordList) -> String {
        guard let language, let rules = perfectives[language],
              let opening = held.first?.split(whereSeparator: { !$0.isLetter }).first.map({ $0.lowercased() }), rules.marks(opening)
        else { return duty }
        let tokens = duty.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        guard let first = tokens.first, letters(first).count > rules.imperfect.count + 1, letters(first).hasSuffix(rules.imperfect) else {
            return duty
        }
        var converted: [String] = []
        for (index, token) in tokens.enumerated() {
            let word = letters(token)
            let previous = index > 0 ? tokens[index - 1] : nil
            let opensAPart = previous == nil || previous.map { $0.hasSuffix(",") || joiners.contains(letters($0)) } == true
            guard opensAPart, word.count > rules.imperfect.count + 1 else { converted.append(token); continue }
            if rules.unwritten.contains(where: word.hasSuffix) { return duty }
            guard word.hasSuffix(rules.imperfect) else { converted.append(token); continue }
            let trailing = String(token.reversed().prefix { !$0.isLetter }.reversed())
            let stem = String(word.dropLast(rules.imperfect.count))
            let form = index == 0 ? rules.first(stem) : rules.later(stem)
            guard let verb = form.split(separator: " ").last, wordList.knows(String(verb), inLanguage: language.rawValue) == true else {
                return duty
            }
            converted.append(form + trailing)
        }
        return converted.joined(separator: " ")
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
