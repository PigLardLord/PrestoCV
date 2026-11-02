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
    /// The technologies in no class of the reader's that says a technology is no tool of the trade (`notTools`; #354, round 9).
    let tradeTools: Int
    let softSkills: Int
    /// The sentences of the summary and of the job descriptions.
    let sentences: Int
    /// "<path>: <sentence>" for every written sentence the app's language detector puts in another language than the description's,
    /// unless the description language's dictionary knows each of its words, as the app reads it (#354, round 13: "Gerencio fluxos
    /// de dados internos." is Portuguese, and the detector says Spanish). A sentence it cannot tell (too short to be sure) is not
    /// counted either way.
    let otherLanguage: [String]
    /// "<path> \"<value>\" (<why>)": a summary, a job description or a skill that holds a tool of another trade (`offField`), and,
    /// for a description with no role, anything written around the facts.
    let offField: [String]
    /// What a reader rejected in the drafts of b14ceda8 (#354), found by rough rules (`ReaderRules`): numbers to follow, not findings.
    let readerFindings: [ReaderFinding]

    /// - Parameters:
    ///   - answers: the raw answers of the draft's requests, for the words they glue (`ReaderRules.gluedWords`).
    ///   - wordList: the dictionary that tells a sentence of a close language from one of the description's.
    ///   - requests: the draft's requests with their steps, for the classes read from them (`ReaderRules.requestFindings`).
    init(
        _ cv: CVData, for input: DraftingInput, report: InventedFacts.Report, answers: [String], requests: [RequestRecord] = [],
        wordList: any WordList
    ) {
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
            guard let tag = AppLanguageDetector.languageTag(of: item.sentence), !tag.hasPrefix(input.language),
                  !Self.isKnown(item.sentence, inLanguage: input.language, by: wordList) else { return nil }
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
        let findings = ReaderRules.findings(in: cv, for: input, report: report)
        let rejected = Set(findings.filter { Self.notTools.contains($0.kind) }.map(\.path))
        tradeTools = cv.skills.indices.filter { cv.skills[$0].kind == .technology && !rejected.contains("skills[\($0)].name") }.count
        readerFindings = findings + ReaderRules.gluedWords(in: cv, answers: answers)
            + ReaderRules.requestFindings(in: cv, for: input, requests: requests)
    }

    /// The reader's classes of a technology that is no tool of the trade: a quality, a work object, an activity, a person or a
    /// document, a bare kind of tool, stationery, a tool of no word of the trade, or one with a word of a name.
    static let notTools: Set<ReaderClass> = [
        .softAsTechnology, .workObjectTechnology, .noToolOfTheTrade, .nonToolTechnology, .categoryAsTechnology, .stationeryTechnology,
        .offTradeTechnology, .employerWordTechnology,
    ]

    /// The first seven letters of each single-word trap of 6 letters or more ("auditor" of a wish to become one): a skill with a
    /// word that starts with one ("auditoría") echoes what the person does not state of themselves.
    static func trapStems(of input: DraftingInput) -> [(trap: String, stem: String)] {
        input.traps.compactMap { trap in
            let words = InventedFacts.words(of: trap)
            guard words.count == 1, let word = words.first, word.count >= 6, word.allSatisfy(\.isLetter) else { return nil }
            return (trap, String(word.prefix(7)))
        }
    }

    /// Whether the draft has a summary of 2 to 6 sentences and at least 120 characters: a rich draft keeps up to 6 (probe round 17).
    var hasSummary: Bool { (2...6).contains(summarySentences) && summaryCharacters >= 120 }

    /// Whether the draft has at least 4 tools of the trade (`tradeTools`) and 3 soft skills; 3 and 2 for a sparse description.
    func hasSkills(sparse: Bool) -> Bool {
        tradeTools >= (sparse ? 3 : 4) && softSkills >= (sparse ? 2 : 3)
    }

    /// Whether the dictionary of `language` knows each word of `sentence` that is no number, as written.
    static func isKnown(_ sentence: String, inLanguage language: String, by wordList: any WordList) -> Bool {
        let words = Word.words(in: sentence).filter { !$0.isNumber }
        return !words.isEmpty && words.allSatisfy { wordList.knows($0.accented, inLanguage: language) == true }
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
            lines.append("enough tools of the trade and soft skills in \(withSkills) of \(drafts) distinct drafts (90% needed)")
        }
        if otherLanguage > 0 { lines.append("\(otherLanguage) of \(sentences) written sentences in another language (none allowed)") }
        if p95Seconds > Self.p95Budget {
            lines.append("p95 \(String(format: "%.1f", p95Seconds)) s per draft (at most \(Int(Self.p95Budget)) s)")
        }
        return lines
    }
}
