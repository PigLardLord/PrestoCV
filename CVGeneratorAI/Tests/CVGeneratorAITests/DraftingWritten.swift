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
    /// The kept jobs whose description has a sentence of at least 40 characters.
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
        describedJobs = cv.experience.filter { job in Self.sentences(of: job.description ?? "").contains { $0.count >= 40 } }.count
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
        if input.kind == .noRole {
            hits += report.inferred.map { "\($0.path) \"\($0.value)\" (written around a description with no role)" }
        }
        offField = hits
        readerFindings = ReaderRules.findings(in: cv, language: input.language)
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

/// A class of the reasons a person rejected the drafts of b14ceda8 (#354). Each is counted by a rough rule over the final draft: a
/// number to follow from one run set to the next, not a threshold of #354 and not a hard finding.
enum ReaderClass: String, Codable, CaseIterable, Sendable {
    /// A quality listed as a technology ("Teamwork").
    case softAsTechnology
    /// A technology that is no tool of the trade: a word for anything ("documents"), or a lone word for an activity ("Maintenance").
    case noToolOfTheTrade
    /// A job whose duties start in more than one form, as the same duty written once as the person and once about them.
    case twoForms
    /// A skill in English words in a draft of another language.
    case skillInAnotherLanguage
}

/// One value of a final draft in a reader's class.
struct ReaderFinding: Codable, Equatable, Sendable {
    let kind: ReaderClass
    let path: String
    let value: String
}

/// The reader's classes of a run set, counted over its distinct drafts.
struct ReaderCounts: Codable, Equatable, Sendable {
    let softAsTechnology: Int
    let noToolOfTheTrade: Int
    let twoForms: Int
    let skillInAnotherLanguage: Int

    init(softAsTechnology: Int, noToolOfTheTrade: Int, twoForms: Int, skillInAnotherLanguage: Int) {
        self.softAsTechnology = softAsTechnology
        self.noToolOfTheTrade = noToolOfTheTrade
        self.twoForms = twoForms
        self.skillInAnotherLanguage = skillInAnotherLanguage
    }

    init(_ findings: [ReaderFinding]) {
        let count = { (kind: ReaderClass) in findings.filter { $0.kind == kind }.count }
        self.init(
            softAsTechnology: count(.softAsTechnology), noToolOfTheTrade: count(.noToolOfTheTrade), twoForms: count(.twoForms),
            skillInAnotherLanguage: count(.skillInAnotherLanguage)
        )
    }

    /// The line of summary.txt.
    var line: String {
        "the reader's classes, by rough rules: a soft skill as a technology \(softAsTechnology); no tool of the trade "
            + "\(noToolOfTheTrade); two forms in one job \(twoForms); a skill in another language \(skillInAnotherLanguage)"
    }
}

/// The rough rules of the reader's classes, those of the probes of #354: word lists, not a reading.
enum ReaderRules {
    static func findings(in cv: CVData, language: String) -> [ReaderFinding] {
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
        }
        return found
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
        return words.contains(where: englishSkillWords.contains)
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
