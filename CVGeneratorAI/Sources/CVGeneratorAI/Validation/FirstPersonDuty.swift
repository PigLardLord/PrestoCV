import Foundation

/// ADR 0031: a duty the person said with a gerund, shared by two jobs ("setting up the PA systems and mixing the support acts",
/// "controllando i quadri elettrici e programmando la manutenzione preventiva"), in the first person of the job's other duties, so
/// one job does not mix two forms. English puts "I was" (a past job) or "I am" (the current one) before it. Italian, Spanish and
/// Portuguese write each gerund that starts the duty or follows a conjunction in the first person of the imperfect (a past job) or
/// of the present (the current one), when the word list knows that form; a gerund after a comma follows only when no verb in the
/// first person comes before it (a list of gerunds), as it is otherwise the adjunct of that verb ("gestivo gli ordini,
/// coordinando i fornitori", #362). A duty in the first person keeps its words, but for a gerund that opens a later part
/// ("Controllavo i quadri e programmando la manutenzione", #362), which is written the same way when it is the gerund of a verb the
/// word list knows, or of an irregular verb (`irregular`: "facendo" is of "fare", and the word list has no verb it could find
/// from the gerund), and no first person of another (`isWritten`: "e prendo" stays), as does a first word in the first person that
/// ends as one ("Prendo le ordinazioni"). A duty with a form the list does not know keeps its words; each duty starts with a
/// capital letter. A duty that starts with an Italian infinitive in -are or a Portuguese one in -ar is written the same way (#354,
/// round 10), and one in -ere or -ire of an ended Italian job (round 14).
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

    /// A gerund of a verb whose stem the gerund does not keep: the word list has no verb that is the gerund's stem and an infinitive
    /// ending ("facere" for "facendo", "sirvir" for "sirviendo"), so the rewrite cannot find the verb from the gerund. Each is
    /// written in the form listed, which the word list must still know. The imperfect of the Italian ones is the gerund's stem and
    /// "evo" or "ivo"; the lists hold the verbs of CV duties, not every irregular verb, and a gerund that is not on one keeps the
    /// duty as the person said it (#362).
    private struct Irregular {
        let past: String
        let present: String
    }

    private static let irregular: [Vocabulary.Language: [String: Irregular]] = [
        .italian: [
            "facendo": Irregular(past: "facevo", present: "faccio"),
            "dicendo": Irregular(past: "dicevo", present: "dico"),
            "traducendo": Irregular(past: "traducevo", present: "traduco"),
            "proponendo": Irregular(past: "proponevo", present: "propongo"),
            "ponendo": Irregular(past: "ponevo", present: "pongo"),
            "conducendo": Irregular(past: "conducevo", present: "conduco"),
            "producendo": Irregular(past: "producevo", present: "produco"),
            "mantenendo": Irregular(past: "mantenevo", present: "mantengo"),
            "ottenendo": Irregular(past: "ottenevo", present: "ottengo"),
            "tenendo": Irregular(past: "tenevo", present: "tengo"),
            "sostenendo": Irregular(past: "sostenevo", present: "sostengo"),
            "scegliendo": Irregular(past: "sceglievo", present: "scelgo"),
        ],
        .spanish: [
            "sirviendo": Irregular(past: "servía", present: "sirvo"),
            "pidiendo": Irregular(past: "pedía", present: "pido"),
            "repitiendo": Irregular(past: "repetía", present: "repito"),
            "durmiendo": Irregular(past: "dormía", present: "duermo"),
            "diciendo": Irregular(past: "decía", present: "digo"),
            "haciendo": Irregular(past: "hacía", present: "hago"),
            "siguiendo": Irregular(past: "seguía", present: "sigo"),
            "consiguiendo": Irregular(past: "conseguía", present: "consigo"),
            "eligiendo": Irregular(past: "elegía", present: "elijo"),
            "teniendo": Irregular(past: "tenía", present: "tengo"),
            "manteniendo": Irregular(past: "mantenía", present: "mantengo"),
            "obteniendo": Irregular(past: "obtenía", present: "obtengo"),
            "sosteniendo": Irregular(past: "sostenía", present: "sostengo"),
            "proponiendo": Irregular(past: "proponía", present: "propongo"),
            "produciendo": Irregular(past: "producía", present: "produzco"),
            "traduciendo": Irregular(past: "traducía", present: "traduzco"),
            "trayendo": Irregular(past: "traía", present: "traigo"),
        ],
        .portuguese: [
            "fazendo": Irregular(past: "fazia", present: "faço"),
            "dizendo": Irregular(past: "dizia", present: "digo"),
            "trazendo": Irregular(past: "trazia", present: "trago"),
            "mantendo": Irregular(past: "mantinha", present: "mantenho"),
            "obtendo": Irregular(past: "obtinha", present: "obtenho"),
            "pedindo": Irregular(past: "pedia", present: "peço"),
            "seguindo": Irregular(past: "seguia", present: "sigo"),
            "servindo": Irregular(past: "servia", present: "sirvo"),
        ],
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
            guard let opened = opening(letters(first), language: language, wordList: wordList) else {
                return capitalised(withLaterGerundsWritten(tokens, current: current, language: language, wordList: wordList) ?? duty)
            }
            let rules = opened.rules
            // A verb in the first person has come before a part once an earlier part opened with a word that is no gerund of the
            // list, or the duty opened with an infinitive: a gerund after a comma is then the adjunct of that verb, and keeps its
            // words, where in a list of gerunds each one is written (#362).
            var finite = !opened.ofGerunds
            var converted: [String] = []
            for (index, token) in tokens.enumerated() {
                let word = letters(token)
                guard index == 0 || opensAPart(after: tokens[index - 1]) else { converted.append(token); continue }
                guard isOfTheForm(word, rules) else {
                    finite = finite || !joiners.contains(word)
                    converted.append(token)
                    continue
                }
                guard isGerund(word, rules) else { return capitalised(duty) }
                // A first person that ends as a gerund ("prendo") keeps its words (#362).
                guard isWritten(word, rules, language: language, wordList: wordList) else {
                    finite = true
                    converted.append(token)
                    continue
                }
                if opened.ofGerunds, finite, index > 0, tokens[index - 1].hasSuffix(",") { converted.append(token); continue }
                guard let form = firstPerson(of: token, rules, current: current, language: language, wordList: wordList) else {
                    return capitalised(duty)
                }
                converted.append(form)
            }
            // A part after an infinitive may open with a gerund ("controlar os quadros e revisando as notas").
            let joined = converted.joined(separator: " ")
            return capitalised(withLaterGerundsWritten(converted, current: current, language: language, wordList: wordList) ?? joined)
        case nil:
            return capitalised(duty)
        }
    }

    /// Whether `duty`, which opens in the first person, has a later part that a joiner opens with a gerund (`isWritten`), as the
    /// rewrite leaves one whose first person the word list does not know (#362): "Sostituisco i cuscinetti e lubrificando i motori"
    /// mixes two forms, and the duty check drops it. A gerund after a comma is the adjunct of the verb before it ("gestivo gli
    /// ordini, coordinando i fornitori"), and mixes nothing.
    static func joinsAGerund(_ duty: String, language: Vocabulary.Language?, wordList: any WordList) -> Bool {
        guard let language, let rules = endings[language] else { return false }
        let tokens = duty.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        guard let first = tokens.first, opening(letters(first), language: language, wordList: wordList) == nil else { return false }
        return tokens.indices.dropFirst().contains { index in
            joins(tokens[index - 1]) && isWritten(letters(tokens[index]), rules, language: language, wordList: wordList)
        }
    }

    /// `tokens`, of a duty that opens in the first person, with each later part that a joiner opens with a gerund (`isWritten`) in
    /// the first person of the job (#362), or nil when the word list knows the first person of none of one such gerund's forms. A
    /// gerund after a comma follows a verb in the first person, which it is the adjunct of, and keeps its words.
    private static func withLaterGerundsWritten(
        _ tokens: [String], current: Bool, language: Vocabulary.Language, wordList: any WordList
    ) -> String? {
        guard let rules = endings[language] else { return nil }
        let letters = { (token: String) in token.lowercased().filter(\.isLetter) }
        var converted: [String] = []
        for (index, token) in tokens.enumerated() {
            guard index > 0, joins(tokens[index - 1]),
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
        previous.hasSuffix(",") || joins(previous)
    }

    /// Whether `previous` is a word that joins two parts of a duty.
    private static func joins(_ previous: String) -> Bool {
        joiners.contains(previous.lowercased().filter(\.isLetter))
    }

    /// The form of `language` that the first word of a duty, `word`, is written in: the gerund's when `isWritten`, else the
    /// infinitive's, or nil when it is neither ("prendo" keeps the duty as the person said it, #362).
    private static func opening(
        _ word: String, language: Vocabulary.Language, wordList: any WordList
    ) -> (rules: Endings, ofGerunds: Bool)? {
        if let rules = endings[language], isWritten(word, rules, language: language, wordList: wordList) { return (rules, true) }
        return infinitives[language].flatMap { isGerund(word, $0) ? ($0, false) : nil }
    }

    /// Whether `word`, which opens a part of a duty, is a gerund the rewrite writes (#362): the gerund of a verb the word list knows
    /// ("programmando", of "programmare") or of an irregular one (`irregular`: "facendo"), and no first person of another verb
    /// ("prendo", of "prendere"; "atendo", of "atender") nor a word that ends as one and is no verb's ("quando"). Those keep their
    /// words. A form with no verbs (an infinitive's) is written when it ends as one.
    private static func isWritten(_ word: String, _ rules: Endings, language: Vocabulary.Language, wordList: any WordList) -> Bool {
        guard isGerund(word, rules) else { return false }
        guard !rules.verbs.isEmpty else { return true }
        guard let ending = rules.gerunds.first(where: { word.hasSuffix($0) }) else { return false }
        let knows = { (candidate: String) in wordList.knows(candidate, inLanguage: language.rawValue) == true }
        let stem = String(word.dropLast(ending.count))
        let verbs: [String] = (rules.verbs[ending] ?? []).map { stem + $0 }
        let verbsOfAFirstPerson: [String] = Set(rules.verbs.values.joined()).map { String(word.dropLast()) + $0 }
        return (irregular[language]?[word] != nil || verbs.contains(where: knows)) && !verbsOfAFirstPerson.contains(where: knows)
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
        let candidates: [String]
        if let form = irregular[language]?[word.lowercased()] {
            let written = current ? form.present : form.past
            candidates = [word.first?.isUppercase == true ? capitalised(written) : written]
        } else {
            candidates = ((current ? rules.present : rules.past)[ending] ?? []).map { stem + $0 }
        }
        guard let known = candidates.first(where: { wordList.knows($0.lowercased(), inLanguage: language.rawValue) == true }) else { return nil }
        return known + trailing
    }

    private static func capitalised(_ text: String) -> String {
        guard let head = text.first else { return text }
        return String(head).uppercased() + text.dropFirst()
    }
}
