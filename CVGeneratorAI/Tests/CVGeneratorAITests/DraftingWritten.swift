import Foundation
import NaturalLanguage
@testable import CVGeneratorAI

// What the model writes around the facts (ADR 0031), measured on each final draft against the thresholds of #354. Pure, like
// `DraftingMeasure`: `DraftingWrittenTests` builds drafts by hand. Whether what it writes fits the person's role no counter can say:
// a person reads every distinct final draft once (`ReviewItem.pertinence`).

// MARK: - One draft

/// The summary, the job descriptions and the skills of one final draft.
struct WrittenMeasure: Codable, Equatable {
    let summarySentences: Int
    let summaryCharacters: Int
    let keptJobs: Int
    /// The kept jobs whose description has at least 40 characters in all.
    let describedJobs: Int
    let technologies: Int
    let softSkills: Int
    /// The sentences of the summary and of the job descriptions.
    let sentences: Int
    /// "<path>: <sentence>" for every written sentence the app's language detector puts in another language than the description's.
    /// A sentence it cannot tell (too short to be sure) is not counted either way.
    let otherLanguage: [String]
    /// "<path> \"<value>\" (<why>)": a summary, a job description or a skill that holds a tool of another trade (`offField`), and,
    /// for a description with no role, anything written around the facts.
    let offField: [String]
    /// What a reader rejected in the drafts of b14ceda8 (#354), found by rough rules (`ReaderRules`): numbers to follow, not findings.
    let readerFindings: [ReaderFinding]

    init(_ cv: CVData, for input: DraftingInput, report: InventedFacts.Report) {
        let summary = cv.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summarySentences = Self.sentences(of: summary)
        self.summarySentences = summarySentences.count
        summaryCharacters = summary.count
        keptJobs = cv.experience.count
        describedJobs = cv.experience.filter { ($0.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 }.count
        technologies = cv.skills.filter { $0.kind == .technology }.count
        softSkills = cv.skills.filter { $0.kind == .softSkill }.count

        var written = summarySentences.map { (path: "summary", sentence: $0) }
        for (index, job) in cv.experience.enumerated() {
            written += Self.sentences(of: job.description ?? "").map { (path: "experience[\(index)].description", sentence: $0) }
        }
        sentences = written.count
        otherLanguage = written.compactMap { item in
            guard let tag = AppLanguageDetector.languageTag(of: item.sentence), !tag.hasPrefix(input.language) else { return nil }
            return "\(item.path) (\(tag)): \(item.sentence)"
        }

        let offWords = input.offField.map { InventedFacts.words(of: $0) }
        var hits: [String] = []
        let fields = [("summary", summary)]
            + cv.experience.enumerated().map { ("experience[\($0.offset)].description", $0.element.description ?? "") }
            + cv.skills.enumerated().map { ("skills[\($0.offset)].name", $0.element.name) }
        for (path, value) in fields where !value.isEmpty {
            let words = InventedFacts.words(of: value)
            if let tool = zip(input.offField, offWords).first(where: { InventedFacts.holds(words, run: $0.1) })?.0 {
                hits.append("\(path) \"\(value)\" (a tool of another trade: \(tool))")
            }
        }
        for (index, skill) in cv.skills.enumerated() {
            let words = InventedFacts.words(of: skill.name)
            if let trap = Self.trapStems(of: input).first(where: { stem in words.contains { $0.hasPrefix(stem.stem) } })?.trap {
                hits.append("skills[\(index)].name \"\(skill.name)\" (an echo of a word the person does not state of themselves: \(trap))")
            }
        }
        if input.kind == .noRole {
            hits += report.inferred.map { "\($0.path) \"\($0.value)\" (written around a description with no role)" }
        }
        offField = hits
        readerFindings = ReaderRules.findings(in: cv, for: input, report: report)
    }

    /// The first seven letters of each single-word trap of 6 letters or more ("auditor" of a wish to become one): a skill with a
    /// word that starts with one ("auditoría") echoes what the person does not state of themselves.
    static func trapStems(of input: DraftingInput) -> [(trap: String, stem: String)] {
        input.traps.compactMap { trap in
            let words = InventedFacts.words(of: trap)
            guard words.count == 1, let word = words.first, word.count >= 6, word.allSatisfy(\.isLetter) else { return nil }
            return (trap, String(word.prefix(7)))
        }
    }

    /// Whether the draft has a summary of 2 to 4 sentences and at least 120 characters.
    var hasSummary: Bool { (2...4).contains(summarySentences) && summaryCharacters >= 120 }

    /// Whether the draft has at least 4 technologies and 3 soft skills; 3 and 2 for a sparse description.
    func hasSkills(sparse: Bool) -> Bool {
        technologies >= (sparse ? 3 : 4) && softSkills >= (sparse ? 2 : 3)
    }

    /// The sentences of `text`, trimmed, as the system tells them apart.
    static func sentences(of text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - A run set

/// The written measures of a run set's distinct final drafts, and the thresholds of #354 they miss.
struct WrittenCounts: Codable, Equatable {
    /// The distinct final drafts of the inputs with a role, study or field.
    let drafts: Int
    let withSummary: Int
    /// The distinct final drafts of the app's examples, and those with a summary: every one needs it.
    let exampleDrafts: Int
    let examplesWithSummary: Int
    let keptJobs: Int
    let describedJobs: Int
    let withSkills: Int
    let sentences: Int
    let otherLanguage: Int
    /// The reader's classes over the distinct drafts: no threshold.
    let reader: ReaderCounts

    /// The largest share of drafts or jobs that may miss a summary, a description or the skills.
    static let allowedMiss = 0.1
    /// The most seconds a draft may take at the 95th percentile, the claim check included.
    static let p95Budget = 90.0

    init(_ measured: [DraftMeasure]) {
        // An input's identical drafts count once, as in `DraftCounts.distinctFinal`.
        var distinct: [(id: String, kind: DraftingInput.Kind, final: CVData, written: WrittenMeasure)] = []
        for draft in measured where draft.kind != .noRole {
            guard let final = draft.final, let written = draft.written,
                  !distinct.contains(where: { $0.id == draft.id && $0.final == final }) else { continue }
            distinct.append((draft.id, draft.kind, final, written))
        }
        drafts = distinct.count
        withSummary = distinct.filter(\.written.hasSummary).count
        let examples = distinct.filter { $0.kind == .example }
        exampleDrafts = examples.count
        examplesWithSummary = examples.filter(\.written.hasSummary).count
        keptJobs = distinct.map(\.written.keptJobs).reduce(0, +)
        describedJobs = distinct.map(\.written.describedJobs).reduce(0, +)
        withSkills = distinct.filter { $0.written.hasSkills(sparse: $0.kind == .sparse) }.count
        sentences = distinct.map(\.written.sentences).reduce(0, +)
        otherLanguage = distinct.map(\.written.otherLanguage.count).reduce(0, +)
        reader = ReaderCounts(distinct.flatMap(\.written.readerFindings))
    }

    /// The thresholds of #354 the set misses, each as a line of summary.txt; the time is `p95Seconds` of the set.
    func shortfalls(p95Seconds: Double) -> [String] {
        var lines: [String] = []
        func short(_ count: Int, of total: Int) -> Bool { total > 0 && Double(count) < Double(total) * (1 - Self.allowedMiss) }
        if short(withSummary, of: drafts) { lines.append("a summary in \(withSummary) of \(drafts) distinct drafts (90% needed)") }
        if examplesWithSummary < exampleDrafts {
            lines.append("a summary in \(examplesWithSummary) of \(exampleDrafts) distinct drafts of the examples (all needed)")
        }
        if short(describedJobs, of: keptJobs) { lines.append("a description on \(describedJobs) of \(keptJobs) kept jobs (90% needed)") }
        if short(withSkills, of: drafts) {
            lines.append("enough technologies and soft skills in \(withSkills) of \(drafts) distinct drafts (90% needed)")
        }
        if otherLanguage > 0 { lines.append("\(otherLanguage) of \(sentences) written sentences in another language (none allowed)") }
        if p95Seconds > Self.p95Budget {
            lines.append("p95 \(String(format: "%.1f", p95Seconds)) s per draft (at most \(Int(Self.p95Budget)) s)")
        }
        return lines
    }
}

// MARK: - The reader's classes

/// A class of the reasons a person rejected the drafts of #354. Each is counted by a rough rule over the final draft: a number to
/// follow from one run set to the next, not a threshold of #354 and not a hard finding.
enum ReaderClass: String, Codable, CaseIterable, Sendable {
    /// A quality listed as a technology ("Teamwork").
    case softAsTechnology
    /// A technology that is no tool of the trade: a word for anything ("documents"), or a lone word for an activity ("Maintenance").
    case noToolOfTheTrade
    /// A job whose duties start in more than one form, as the same duty written once as the person and once about them.
    case twoForms
    /// A skill in English words in a draft of another language; a loanword ("leadership") is not one.
    case skillInAnotherLanguage
    /// A technology whose head noun an earlier one has ("digital desks" after "mixing desks").
    case sharedHeadNoun
    /// A headline that is a part of a title the person states, and none of its forms ("amministrativa" of "impiegata
    /// amministrativa").
    case headlineFragment
    /// A summary that names neither the headline nor a kept job title whole, or, with none, no word of the person's field.
    case summaryWithoutPerson
    /// A job description with a sentence that starts with an infinitive or a gerund, as an instruction or a fragment.
    case infinitiveDuty
    /// A job description that does not end with a full stop.
    case unfinishedDescription
    /// An ended job whose duties are said both in the past and in the present.
    case mixedTense
    /// A soft skill that is the word for a skill ("competence").
    case skillWordAsQuality
    /// An interest that is a clause: more than 4 words, a word of the first person, or a quality at work.
    case clauseAsInterest
    /// A summary sentence that starts with the verb of an earlier one, or that is a sentence of a job description.
    case repeatedSentence
    /// A year the description gives an entry and the draft does not hold (`InventedFacts.Report.lostYears`).
    case lostYear

    /// The words of the class in the line of summary.txt.
    var label: String {
        switch self {
        case .softAsTechnology: "a soft skill as a technology"
        case .noToolOfTheTrade: "no tool of the trade"
        case .twoForms: "two forms in one job"
        case .skillInAnotherLanguage: "a skill in another language"
        case .sharedHeadNoun: "two technologies of one head noun"
        case .headlineFragment: "a headline that is a part of a title"
        case .summaryWithoutPerson: "a summary that does not name the person's work"
        case .infinitiveDuty: "a duty as an infinitive or a gerund"
        case .unfinishedDescription: "a description with no full stop"
        case .mixedTense: "an ended job in two tenses"
        case .skillWordAsQuality: "the word for a skill as a soft skill"
        case .clauseAsInterest: "a clause as an interest"
        case .repeatedSentence: "a repeated summary sentence"
        case .lostYear: "a lost year"
        }
    }
}

/// One value of a final draft in a reader's class.
struct ReaderFinding: Codable, Equatable, Sendable {
    let kind: ReaderClass
    let path: String
    let value: String
}

/// The reader's classes of a run set, counted over its distinct drafts.
struct ReaderCounts: Codable, Equatable, Sendable {
    /// The count of each class, by its raw value; a class with none is 0.
    let counts: [String: Int]

    init(_ findings: [ReaderFinding]) {
        counts = Dictionary(uniqueKeysWithValues: ReaderClass.allCases.map { kind in
            (kind.rawValue, findings.filter { $0.kind == kind }.count)
        })
    }

    func count(_ kind: ReaderClass) -> Int { counts[kind.rawValue] ?? 0 }

    /// The line of summary.txt.
    var line: String {
        "the reader's classes, by rough rules: " + ReaderClass.allCases.map { "\($0.label) \(count($0))" }.joined(separator: "; ")
    }
}

/// The rough rules of the reader's classes, those of the probes of #354: word lists, not a reading.
enum ReaderRules {
    static func findings(in cv: CVData, for input: DraftingInput, report: InventedFacts.Report) -> [ReaderFinding] {
        let language = input.language
        var found: [ReaderFinding] = []
        for (index, skill) in cv.skills.enumerated() {
            let path = "skills[\(index)].name"
            if skill.kind == .technology {
                if isQuality(skill.name) {
                    found.append(ReaderFinding(kind: .softAsTechnology, path: path, value: skill.name))
                } else if isNoTool(skill.name) {
                    found.append(ReaderFinding(kind: .noToolOfTheTrade, path: path, value: skill.name))
                }
            }
            if language != "en", isEnglish(skill.name) {
                found.append(ReaderFinding(kind: .skillInAnotherLanguage, path: path, value: skill.name))
            }
        }
        let vocabulary = Vocabulary.Language(rawValue: language)
        for (index, job) in cv.experience.enumerated() {
            let description = job.description ?? ""
            let forms = WrittenMeasure.sentences(of: description).compactMap { CVDataSanitizer.form(withoutConnector($0), language: vocabulary) }
            if Set(forms.map { "\($0)" }).count > 1 {
                found.append(ReaderFinding(kind: .twoForms, path: "experience[\(index)].description", value: description))
            }
            found += duties(of: job, at: index, language: language)
        }
        found += sharedHeads(in: cv, language: language)
        found += headline(of: cv, for: input)
        found += summary(of: cv, for: input)
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill && skillWords.contains(fold(skill.name)) {
            found.append(ReaderFinding(kind: .skillWordAsQuality, path: "skills[\(index)].name", value: skill.name))
        }
        for (index, interest) in cv.interests.enumerated() where isClause(interest) {
            found.append(ReaderFinding(kind: .clauseAsInterest, path: "interests[\(index)]", value: interest))
        }
        found += report.lostYears.map { ReaderFinding(kind: .lostYear, path: $0.entry, value: $0.year) }
        return found
    }

    // MARK: Duties

    /// A job's description: a sentence that starts with an infinitive or a gerund, no full stop at the end, and, for an ended job,
    /// duties in the past and in the present.
    static func duties(of job: Experience, at index: Int, language: String) -> [ReaderFinding] {
        let description = (job.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return [] }
        let path = "experience[\(index)].description"
        let sentences = WrittenMeasure.sentences(of: description).map(withoutConnector)
        var found: [ReaderFinding] = []
        if sentences.contains(where: { startsWithInfinitive($0, language: language) }) {
            found.append(ReaderFinding(kind: .infinitiveDuty, path: path, value: description))
        }
        if let last = description.last, !".!?…".contains(last) {
            found.append(ReaderFinding(kind: .unfinishedDescription, path: path, value: description))
        }
        let tenses = Set(sentences.compactMap { tense(of: $0, language: language) })
        if !job.current, tenses.count > 1 {
            found.append(ReaderFinding(kind: .mixedTense, path: path, value: description))
        }
        return found
    }

    /// Whether `sentence` starts with an infinitive or a gerund: by the endings of the word, a rough rule; none in German, whose
    /// infinitive ends a sentence.
    static func startsWithInfinitive(_ sentence: String, language: String) -> Bool {
        guard let first = letterWords(of: sentence).first else { return false }
        switch language {
        case "en": return first.count > 4 && first.hasSuffix("ing")
        case "it": return first.count > 4 && ["are", "ere", "ire", "ando", "endo"].contains(where: first.hasSuffix)
        case "es": return first.count > 4 && ["ar", "er", "ir", "ando", "iendo"].contains(where: first.hasSuffix)
        case "pt": return first.count > 4 && ["ar", "er", "ir", "ando", "endo", "indo"].contains(where: first.hasSuffix)
        case "fr": return first.count > 4 && ["er", "ir", "re", "ant"].contains(where: first.hasSuffix)
        default: return false
        }
    }

    enum Tense: Hashable { case past, present }

    /// The tense of a duty said in the first person, by the endings of its verb: a rough rule, nil when it cannot tell.
    static func tense(of sentence: String, language: String) -> Tense? {
        let words = letterWords(of: sentence)
        guard let first = words.first else { return nil }
        func ending(_ word: String, past: [String], present: [String]) -> Tense? {
            if past.contains(where: word.hasSuffix) { return .past }
            return present.contains(where: word.hasSuffix) ? .present : nil
        }
        switch language {
        case "en":
            guard first == "i", words.count > 1 else { return nil }
            let verb = words[1]
            if ["was", "were", "had", "did", "made", "led", "ran", "kept", "built", "taught", "took"].contains(verb) { return .past }
            if ["am", "have", "also"].contains(verb) { return nil }
            return verb.hasSuffix("ed") ? .past : .present
        case "de":
            guard first == "ich", words.count > 1 else { return nil }
            let verb = words[1]
            if ["habe", "hatte", "war", "bin"].contains(verb) || verb.hasSuffix("te") { return .past }
            return .present
        case "fr":
            guard first == "je" || first == "j", words.count > 1 else { return nil }
            let verb = words[1]
            if ["ai", "avais", "étais"].contains(verb) || verb.hasSuffix("ais") { return .past }
            return verb == "suis" ? nil : .present
        case "it":
            if ["ho", "sono", "ero"].contains(first) { return .past }
            return ending(first, past: ["avo", "evo", "ivo", "ai", "ii"], present: ["o"])
        case "es":
            if ["he", "fui"].contains(first) { return .past }
            return ending(first, past: ["é", "í", "aba", "ía"], present: ["o"])
        case "pt":
            return ending(first, past: ["ei", "ava", "ia", "i"], present: ["o"])
        default:
            return nil
        }
    }

    // MARK: Technologies

    /// A technology whose head noun, by its stem, an earlier technology has: the last word in English and German, the first in the
    /// other languages ("cahier d'exercices" after "cahiers").
    static func sharedHeads(in cv: CVData, language: String) -> [ReaderFinding] {
        var heads: Set<String> = []
        var found: [ReaderFinding] = []
        for (index, skill) in cv.skills.enumerated() where skill.kind == .technology {
            let words = letterWords(of: skill.name).filter { !["l", "d"].contains($0) }
            guard let head = (["en", "de"].contains(language) ? words.last : words.first).map(stem) else { continue }
            if !heads.insert(head).inserted {
                found.append(ReaderFinding(kind: .sharedHeadNoun, path: "skills[\(index)].name", value: skill.name))
            }
        }
        return found
    }

    /// A word without the ending of its plural and its last vowel ("consoles" and "console" are "consol").
    static func stem(_ word: String) -> String {
        var stem = word
        for ending in ["es", "s", "en", "n"] where stem.count > 4 && stem.hasSuffix(ending) {
            stem.removeLast(ending.count)
            break
        }
        if stem.count > 4, let last = stem.last, "aeiouàèéìòù".contains(last) { stem.removeLast() }
        return stem
    }

    // MARK: Headline and summary

    /// A headline whose words are a part of a stated title and none of its forms.
    static func headline(of cv: CVData, for input: DraftingInput) -> [ReaderFinding] {
        guard let title = cv.personalInfo.title, !title.isEmpty else { return [] }
        let words = InventedFacts.words(of: title)
        for fact in input.facts where fact.kind == .title {
            let forms = fact.forms.map { InventedFacts.words(of: $0) }
            guard !forms.contains(words), let full = forms.first, words.count < full.count, InventedFacts.holds(full, run: words) else {
                continue
            }
            return [ReaderFinding(kind: .headlineFragment, path: "personalInfo.title", value: title)]
        }
        return []
    }

    /// A summary that names no title of the draft whole (or, with none, no word of the field), and summary sentences that repeat.
    static func summary(of cv: CVData, for input: DraftingInput) -> [ReaderFinding] {
        let summary = (cv.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return [] }
        var found: [ReaderFinding] = []
        let words = InventedFacts.words(of: summary)
        let titles = ([cv.personalInfo.title ?? ""] + cv.experience.map(\.title)).map { InventedFacts.words(of: $0) }.filter { !$0.isEmpty }
        let named = titles.isEmpty
            ? InventedFacts.words(of: input.field ?? "").filter { $0.count > 3 }.contains(where: words.contains)
            : titles.contains { InventedFacts.holds(words, run: $0) }
        if !named {
            found.append(ReaderFinding(kind: .summaryWithoutPerson, path: "summary", value: summary))
        }
        let sentences = WrittenMeasure.sentences(of: summary)
        let duties = Set(cv.experience.flatMap { WrittenMeasure.sentences(of: $0.description ?? "") }.map(fold))
        var verbs: Set<String> = []
        for sentence in sentences {
            let verb = letterWords(of: sentence).first { !pronouns.contains($0) }
            let again = verb.map { !verbs.insert($0).inserted } ?? false
            if again || duties.contains(fold(sentence)) {
                found.append(ReaderFinding(kind: .repeatedSentence, path: "summary", value: sentence))
            }
        }
        return found
    }

    /// The subject pronouns of the first person, which a summary sentence starts with before its verb.
    static let pronouns: Set<String> = ["i", "ich", "je", "j", "io", "yo", "eu"]

    // MARK: Soft skills and interests

    /// The words for a skill, a competence or an ability, which name no quality.
    static let skillWords: Set<String> = [
        "skill", "skills", "ability", "abilities", "competence", "competences", "competencies", "competenza", "competenze", "abilita",
        "capacita", "kompetenz", "kompetenzen", "fahigkeit", "fahigkeiten", "competencia", "competencias", "habilidad",
        "habilidades", "capacidad", "capacidades", "capacite", "capacites", "aptitude", "aptitudes", "habilidade", "capacidade",
    ]

    /// The words of the first person in an interest ("like working with directors" is one of the person's).
    static let firstPersonWords: Set<String> = [
        "i", "my", "me", "myself", "io", "mi", "sono", "mio", "mia", "ich", "mich", "mir", "bin", "je", "j", "moi", "suis",
        "yo", "soy", "eu", "sou", "like", "piace", "gusta", "gosto", "aime", "mag",
    ]

    /// Whether an interest is a clause, not a pastime: more than 4 words, a word of the first person, or the stem of a quality at
    /// work.
    static func isClause(_ interest: String) -> Bool {
        let words = letterWords(of: interest)
        let lowered = interest.lowercased()
        return words.count > 4 || words.contains(where: firstPersonWords.contains)
            || CVDataSanitizer.softStems.contains { lowered.contains($0) }
    }

    /// The words of `text`, lowered, folded and split at anything not a letter.
    static func letterWords(of text: String) -> [String] {
        fold(text).split { !$0.isLetter }.map(String.init)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }


    /// Parts of the words for qualities at work, in the six languages.
    static let qualities = [
        "communicat", "comunica", "kommunika", "teamwork", "team work", "teamfähig", "collabor", "zusammenarbeit", "lavoro di squadra",
        "trabajo en equipo", "travail d'équipe", "travail en équipe", "trabalho em equipe", "leadership", "problem solving",
        "problem-solving", "empat", "flexib", "flessib", "adaptab", "adattab", "pünktlich", "zuverläss", "affidab", "fiab", "reliab",
        "time management", "gestione del tempo", "gestion du temps", "ascolto", "escuta", "listening", "attention to detail",
        "attenzione ai dettagli", "precisione", "puntual", "pontual", "pazien", "patien", "geduld", "sorgfalt", "cortes", "höflich",
    ]

    /// Words for anything, of no trade.
    static let generic: Set<String> = [
        "documento", "documenti", "documents", "discussione", "analisi", "collaborazione", "norme", "regole", "metodi", "procedure",
        "código", "codigo", "estrutura", "validação", "interface", "gestion", "organisation", "communication", "coordination",
        "kommunikation", "planung", "interaktion", "servicio", "comunicación", "organización", "interacción", "diálogo", "observação",
        "escrita", "mediação", "lavoro", "work", "tools", "strumenti", "methods", "safety", "sicurezza", "qualità", "quality",
    ]

    /// The endings of a noun of an activity ("manutenzione", "Wartung", "maintenance" is not one: "-ance" and "-ment" name tools too).
    static let activityEndings = [
        "zione", "zioni", "ung", "ungen", "tion", "tions", "ción", "ciones", "ção", "ções", "isation", "amiento", "imento",
    ]

    /// The words that join a duty to the one before, and say nothing of its form.
    static let connectors: Set<String> = [
        "then", "also", "and", "later", "afterwards", "poi", "inoltre", "anche", "e", "quindi", "dopo", "dann", "auch", "und", "danach",
        "puis", "aussi", "et", "ensuite", "luego", "también", "y", "después", "depois", "também", "além",
    ]

    /// English words of skills that no other of the six languages writes the same way.
    static let englishSkillWords: Set<String> = [
        "management", "communication", "skills", "solving", "teamwork", "leadership", "attention", "detail", "organization", "planning",
        "listening", "problem", "customer", "approach", "record", "keeping", "tools", "safety", "clear", "expression", "respect",
        "active", "collaborative", "document", "maintenance", "troubleshooting", "mixing", "systems", "electrical", "preventive",
    ]

    /// English words the other five languages write as their own in a CV ("leadership", "software").
    static let loanwords: Set<String> = [
        "leadership", "team", "leader", "software", "hardware", "marketing", "design", "budget", "computer", "database", "web",
        "manager", "management", "know", "how",
    ]

    static func isQuality(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return qualities.contains { lowered.contains($0) }
    }

    static func isNoTool(_ name: String) -> Bool {
        let lowered = name.lowercased().trimmingCharacters(in: .whitespaces)
        if generic.contains(lowered) { return true }
        let single = !lowered.contains(" ")
        let acronym = name == name.uppercased()
        return single && !acronym && activityEndings.contains { lowered.hasSuffix($0) }
    }

    static func isEnglish(_ name: String) -> Bool {
        guard name.unicodeScalars.allSatisfy(\.isASCII) else { return false }
        let words = name.lowercased().split { !$0.isLetter }.map(String.init)
        return !words.allSatisfy(loanwords.contains) && words.contains(where: englishSkillWords.contains)
    }

    /// `sentence` without the words that join it to the one before ("Then I rig" is "I rig").
    static func withoutConnector(_ sentence: String) -> String {
        var rest = Substring(sentence)
        while let end = rest.firstIndex(where: { !$0.isLetter }), connectors.contains(rest[..<end].lowercased()) {
            rest = rest[end...].drop { !$0.isLetter }
        }
        return String(rest)
    }
}
