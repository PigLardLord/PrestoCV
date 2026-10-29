import Foundation
@testable import CVGeneratorAI

// The reader's classes of #354: rough rules over a final draft that count the reasons a person rejected the drafts, apart from
// the written measures of `DraftingWritten` so that they build on every platform (they need no language tagger).

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
    /// An interest that is a clause: more than 4 words, a word of the first person, a quality at work, or a finite verb first.
    case clauseAsInterest
    /// A summary sentence that starts with the verb of an earlier one, or that is a sentence of a job description.
    case repeatedSentence
    /// A year the description gives an entry and the draft does not hold (`InventedFacts.Report.lostYears`).
    case lostYear
    /// A job description that writes a run of five words twice: one duty said twice.
    case repeatedDuty
    /// A skill of more than four words: a clause, not the name of a skill ("edit the sound effects for the shows").
    case clauseAsSkill
    /// A soft skill whose head noun is a tool ("Präzisionswerkzeug", "strumenti di misura"): a thing, no quality.
    case toolAsSoftSkill
    /// A summary sentence in Spanish, Italian or Portuguese that starts, after a title of the person, with a verb of the third person
    /// ("Contable gestiona los registros.", "Si occupa della contabilità."): the person spoken of, not speaking.
    case thirdPersonSummary
    /// An interest of one noun that the description says after a verb in its infinitive form ("football" of "I play football"): the
    /// pastime's phrase without its verb (#354, round 1).
    case bareInterest
    /// A duty or a quality the person states that no job description and no skill of the draft holds (`ExpectedFact.duty`,
    /// `.quality`): "I mix on digital consoles", "mi piace lavorare in squadra" (#354, round 1).
    case unwrittenStatement
    /// A job sentence that quotes less than half of its words from the description, in a job whose sentences that quote it run to 40
    /// characters or more: a duty the person did not say, in a job they described ("I coordinated the movement of heavy equipment";
    /// ADR 0031, D6).
    case fillerDuty
    /// A summary sentence whose subject is the person's work, not the person: a bare word of a title or of the field followed by a
    /// verb "to be" ("Manutenzione è la mia attività principale."; #354, round 1), or a word of the work after an article, with any
    /// verb ("O trabalho exige…", "La manutenzione è…"; #354, round 3).
    case bareSubjectSummary
    /// A technology with a word in neither the description nor the reader's tools of the input's trade (`DraftingInputs.vocabularies`):
    /// a tool of another trade, an activity, or jargon ("frequency calibration", "software di tracciamento"; #354, round 1).
    case offTradeTechnology
    /// A technology that names a kind of tool and no tool of it: its head noun is a category ("software", "plataforma de
    /// desenvolvimento", "digital sound workstation") and none of its words is a name or an acronym (#354, round 2).
    case categoryAsTechnology
    /// Two soft skills of one quality ("precisione" and "attenzione"; "teamwork" and "collaboration"; #354, round 2).
    case sameQuality
    /// A summary sentence whose subject is a quality: it starts with a soft skill of the draft or a word for a quality at work
    /// ("Precisione e attenzione sono le mie qualità."; #354, round 2).
    case qualitySubjectSummary
    /// Two summary sentences that end with the same three words ("..., con enfoque práctico." twice; #354, round 2).
    case repeatedEnding
    /// A job description with three sentences or more that start with the same two words ("Je préparais ..." three times; #354,
    /// round 2).
    case sameOpening
    /// A summary sentence with no verb that starts with a bare word of a title or of the field ("Contable con gran capacidad de
    /// análisis."; #354, round 3).
    case fragmentSummary
    /// A summary sentence that lists three skills of the draft or more ("… terminal, scanner, codec e sensor."; #354, round 3).
    case listySummary
    /// A soft skill that is an empty word, of experience or of being a professional, and names no quality ("professional",
    /// "Erfahrung"; #354, round 3).
    case emptySoftSkill
    /// A job whose final description is under 40 characters while the step that writes the job pins a duty the description does not
    /// hold: the step counted that duty toward the job and asked for nothing more, and the final check moved it out (#354, round 3).
    case stepVsFinalPinned
    /// A summary sentence of three clauses or more joined by semicolons ("I manage the flow; I ensure …; I adapt …."; #354, round
    /// 3, at 0608938b).
    case chainedSummary

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
        case .repeatedDuty: "a duty said twice in one job"
        case .clauseAsSkill: "a clause as a skill"
        case .toolAsSoftSkill: "a tool as a soft skill"
        case .thirdPersonSummary: "a summary in the third person"
        case .bareInterest: "an interest without the verb of its phrase"
        case .unwrittenStatement: "a stated duty or quality the draft does not hold"
        case .fillerDuty: "a duty not said, in a job the person described"
        case .bareSubjectSummary: "a summary sentence with a bare work word as its subject"
        case .offTradeTechnology: "a technology neither stated nor of the trade"
        case .categoryAsTechnology: "a category as a technology"
        case .sameQuality: "two soft skills of one quality"
        case .qualitySubjectSummary: "a summary sentence with a quality as its subject"
        case .repeatedEnding: "two summary sentences with one ending"
        case .sameOpening: "three sentences of one job with one opening"
        case .fragmentSummary: "a summary sentence with no verb"
        case .listySummary: "a summary sentence that lists skills"
        case .emptySoftSkill: "an empty word as a soft skill"
        case .stepVsFinalPinned: "a short job with a pinned duty it does not hold"
        case .chainedSummary: "a summary sentence of clauses joined by semicolons"
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
        let tradeStems = DraftingInputs.vocabularies[input.id].map { stems(of: ([input.description] + $0).joined(separator: " ")) }
        for (index, skill) in cv.skills.enumerated() {
            let path = "skills[\(index)].name"
            if skill.kind == .technology {
                if isQuality(skill.name) {
                    found.append(ReaderFinding(kind: .softAsTechnology, path: path, value: skill.name))
                } else if isNoTool(skill.name) || isActivity(skill.name, language: language) || isPart(skill.name, of: input) {
                    found.append(ReaderFinding(kind: .noToolOfTheTrade, path: path, value: skill.name))
                } else if isCategory(skill.name, language: language) {
                    found.append(ReaderFinding(kind: .categoryAsTechnology, path: path, value: skill.name))
                }
            }
            if language != "en", isEnglish(skill.name, language: language) {
                found.append(ReaderFinding(kind: .skillInAnotherLanguage, path: path, value: skill.name))
            }
            if skill.kind == .technology, let known = tradeStems, !stems(of: skill.name).isSubset(of: known) {
                found.append(ReaderFinding(kind: .offTradeTechnology, path: path, value: skill.name))
            }
            if letterWords(of: skill.name).count > 4 {
                found.append(ReaderFinding(kind: .clauseAsSkill, path: path, value: skill.name))
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
            found += fillers(in: job, at: index, of: input.description)
        }
        found += sharedHeads(in: cv, language: language)
        found += headline(of: cv, for: input)
        found += summary(of: cv, for: input)
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill && skillWords.contains(fold(skill.name)) {
            found.append(ReaderFinding(kind: .skillWordAsQuality, path: "skills[\(index)].name", value: skill.name))
        }
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill && emptyWords.contains(fold(skill.name)) {
            found.append(ReaderFinding(kind: .emptySoftSkill, path: "skills[\(index)].name", value: skill.name))
        }
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill && isTool(skill.name, language: language) {
            found.append(ReaderFinding(kind: .toolAsSoftSkill, path: "skills[\(index)].name", value: skill.name))
        }
        found += sameQualities(in: cv)
        for (index, interest) in cv.interests.enumerated() where isClause(interest) || startsWithVerb(interest, in: input) {
            found.append(ReaderFinding(kind: .clauseAsInterest, path: "interests[\(index)]", value: interest))
        }
        for (index, interest) in cv.interests.enumerated() where losesItsVerb(interest, in: input) {
            found.append(ReaderFinding(kind: .bareInterest, path: "interests[\(index)]", value: interest))
        }
        found += shortDescribedJobs(in: cv, for: input)
        found += report.lostYears.map { ReaderFinding(kind: .lostYear, path: $0.entry, value: $0.year) }
        found += report.lost.filter { [.duty, .quality].contains($0.kind) }
            .map { ReaderFinding(kind: .unwrittenStatement, path: $0.kind.rawValue, value: $0.forms[0]) }
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
        if let run = repeatedRun(in: description) {
            found.append(ReaderFinding(kind: .repeatedDuty, path: path, value: run))
        }
        let openings = sentences.map { letterWords(of: $0).prefix(2) }
            .filter { $0.count == 2 && !auxiliaries.contains($0.last ?? "") }
            .map { $0.joined(separator: " ") }
        if let opening = openings.first(where: { opening in openings.count { $0 == opening } >= 3 }) {
            found.append(ReaderFinding(kind: .sameOpening, path: path, value: opening))
        }
        return found
    }

    /// The auxiliaries a past or a perfect tense opens with ("Ich habe die Leitungen geprüft", "J'ai formé"): an opening of the
    /// subject and an auxiliary says nothing of the verb, which comes later, so three of them are no repeated opening.
    static let auxiliaries: Set<String> = [
        "have", "has", "had", "am", "was", "were", "habe", "hat", "hatte", "bin", "war", "wurde", "ai", "avais", "suis", "etais",
        "ho", "avevo", "sono", "ero", "he", "habia", "tengo", "tenho", "tinha",
    ]

    /// The first run of five words that `text` writes twice, the second time apart from the first, if any.
    static func repeatedRun(in text: String) -> String? {
        let words = letterWords(of: text)
        var seen: [String: Int] = [:]
        for start in words.indices.dropLast(4) {
            let run = words[start..<(start + 5)].joined(separator: " ")
            if let earlier = seen[run] {
                if start - earlier >= 5 { return run }
            } else {
                seen[run] = start
            }
        }
        return nil
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

    /// The sentences of a job that quote less than half of their words of five letters and more from `description`, when its
    /// sentences that quote three in four of them run to 40 characters or more. A word is quoted when the description has a word
    /// of its first five letters, so an inflection still quotes it.
    static func fillers(in job: Experience, at index: Int, of description: String) -> [ReaderFinding] {
        let said = Set(longWords(of: description).map { $0.prefix(5) })
        let share = { (sentence: String) -> Double in
            let words = longWords(of: sentence)
            return words.isEmpty ? 1 : Double(words.count { said.contains($0.prefix(5)) }) / Double(words.count)
        }
        let sentences = WrittenMeasure.sentences(of: job.description ?? "")
        guard sentences.filter({ share($0) >= 0.75 }).joined(separator: " ").count >= 40 else { return [] }
        return sentences.filter { share($0) < 0.5 }
            .map { ReaderFinding(kind: .fillerDuty, path: "experience[\(index)].description", value: $0) }
    }

    private static func longWords(of text: String) -> [String] {
        letterWords(of: text).filter { $0.count >= 5 }
    }

    // MARK: Technologies

    /// A technology whose head noun, by its stem, an earlier technology has: the last word in English and German, the first in the
    /// other languages ("cahier d'exercices" after "cahiers").
    static func sharedHeads(in cv: CVData, language: String) -> [ReaderFinding] {
        var heads: Set<String> = []
        var found: [ReaderFinding] = []
        for (index, skill) in cv.skills.enumerated() where skill.kind == .technology {
            let words = letterWords(of: skill.name).filter { !["l", "d"].contains($0) }
            guard let word = ["en", "de"].contains(language) ? words.last : words.first, word.count >= 4 else { continue }
            let head = headGroups[stem(word)] ?? stem(word)
            if !heads.insert(head).inserted {
                found.append(ReaderFinding(kind: .sharedHeadNoun, path: "skills[\(index)].name", value: skill.name))
            }
        }
        return found
    }

    /// The stems of head nouns that name one tool, by the stem that stands for them: a console, a mixer and a desk are one
    /// mixing console (#354, round 2).
    static let headGroups: [String: String] = ["mixer": "consol", "desk": "consol"]

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

    /// A summary that names no title of the draft whole (with none kept, no stated title; with none stated, no word of the field),
    /// and summary sentences that repeat.
    static func summary(of cv: CVData, for input: DraftingInput) -> [ReaderFinding] {
        let summary = (cv.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return [] }
        var found: [ReaderFinding] = []
        let words = InventedFacts.words(of: summary)
        let kept = ([cv.personalInfo.title ?? ""] + cv.experience.map(\.title)).map { InventedFacts.words(of: $0) }.filter { !$0.isEmpty }
        let stated = input.facts.filter { $0.kind == .title }.flatMap(\.forms).map { InventedFacts.words(of: $0) }.filter { !$0.isEmpty }
        let titles = kept.isEmpty ? stated : kept
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
        found += sentences.filter { inTheThirdPerson($0, titles: titles, language: input.language) }
            .map { ReaderFinding(kind: .thirdPersonSummary, path: "summary", value: $0) }
        let workWords = Set((titles.flatMap { $0 } + InventedFacts.words(of: input.field ?? "")).filter { $0.count > 3 })
        found += sentences.filter { hasBareSubject($0, of: workWords, language: input.language) }
            .map { ReaderFinding(kind: .bareSubjectSummary, path: "summary", value: $0) }
        found += sentences.filter { isFragment($0, of: workWords, language: input.language) }
            .map { ReaderFinding(kind: .fragmentSummary, path: "summary", value: $0) }
        let skills = cv.skills.map { InventedFacts.words(of: $0.name) }.filter { !$0.isEmpty }
        found += sentences.filter { sentence in
            let words = InventedFacts.words(of: sentence)
            return skills.count { InventedFacts.holds(words, run: $0) } >= 3
        }.map { ReaderFinding(kind: .listySummary, path: "summary", value: $0) }
        found += sentences.filter { $0.filter { $0 == ";" }.count >= 2 }
            .map { ReaderFinding(kind: .chainedSummary, path: "summary", value: $0) }
        let qualities = cv.skills.filter { $0.kind == .softSkill }.map { letterWords(of: $0.name) }.filter { !$0.isEmpty }
        found += sentences.filter { hasQualitySubject($0, qualities: qualities) }
            .map { ReaderFinding(kind: .qualitySubjectSummary, path: "summary", value: $0) }
        var endings: Set<String> = []
        for sentence in sentences {
            let words = letterWords(of: sentence)
            guard words.count >= 5 else { continue }
            if !endings.insert(words.suffix(3).joined(separator: " ")).inserted {
                found.append(ReaderFinding(kind: .repeatedEnding, path: "summary", value: sentence))
            }
        }
        return found
    }

    /// Whether `sentence` starts with the words of a soft skill of the draft, or with a word for a quality at work, in a clause of
    /// five words or more: a quality spoken of as the subject, not the person speaking. A quality that opens a sentence before a
    /// comma ("Affidabile e preciso, seguo ...") describes the person who speaks after it.
    static func hasQualitySubject(_ sentence: String, qualities: [[String]]) -> Bool {
        let words = letterWords(of: sentence)
        let clause = letterWords(of: String(sentence.prefix { $0 != "," }))
        guard clause.count >= 5, let first = words.first, !personWords.contains(first), !pronouns.contains(first) else { return false }
        return qualities.contains { words.starts(with: $0) } || isQuality(first)
    }

    /// Whether `sentence` starts with a word of `workWords` and has a verb "to be" among its next three words, with no word of the
    /// person before it: the work spoken of as a thing, not the person speaking.
    static func hasBareSubject(_ sentence: String, of workWords: Set<String>, language: String) -> Bool {
        let words = sentence.lowercased().split { !$0.isLetter }.map(String.init)
        if let first = words.first, subjectArticles[language]?.contains(first) == true, words.count > 2 {
            let noun = fold(words[1])
            return (workWords.contains(noun) || workNouns.contains(noun)) && !words[2...].prefix(2).contains(where: personWords.contains)
        }
        guard let first = words.first, workWords.contains(fold(first)),
              let copula = words.dropFirst().prefix(3).firstIndex(where: copulas.contains) else { return false }
        return !words[..<copula].contains(where: personWords.contains)
    }

    /// Whether `sentence` is a bare word of `workWords` and the language's "with", with no verb "to be" and no word of the person:
    /// a title with its qualities, and no verb ("Contable con gran capacidad de análisis."). A word of the work followed by a verb
    /// ("Mechanic work asks for care") is no fragment.
    static func isFragment(_ sentence: String, of workWords: Set<String>, language: String) -> Bool {
        let words = sentence.lowercased().split { !$0.isLetter }.map(String.init)
        guard words.count > 2, workWords.contains(fold(words[0])), withWords[language]?.contains(words[1]) == true else { return false }
        return !words.contains(where: copulas.contains) && !words.contains(where: personWords.contains)
            && !words.contains(where: pronouns.contains)
    }

    /// The word for "with" that joins a title to its qualities, per language.
    static let withWords: [String: Set<String>] = [
        "en": ["with"], "it": ["con"], "de": ["mit"], "es": ["con"], "fr": ["avec"], "pt": ["com"],
    ]

    /// The articles and demonstratives that open a subject, lower case, per language ("l" of "l'attività"; the English "I" is no
    /// article).
    static let subjectArticles: [String: Set<String>] = [
        "en": ["the", "this"], "it": ["il", "lo", "la", "l", "i", "gli", "le", "questo", "questa"], "de": ["der", "die", "das"],
        "es": ["el", "la", "los", "las", "este", "esta"], "pt": ["o", "a", "os", "as", "este", "esta"], "fr": ["le", "la", "l", "les", "ce", "cette"],
    ]

    /// The words for work itself, folded, which after an article are the work as a subject ("Il lavoro", "O trabalho").
    static let workNouns: Set<String> = ["work", "lavoro", "arbeit", "travail", "trabajo", "trabalho", "manutenzione"]

    /// The forms of "to be" of the third person, accented: "è" is, "e" is and.
    static let copulas: Set<String> = [
        "is", "are", "was", "were", "è", "sono", "era", "erano", "ist", "sind", "war", "waren", "es", "son", "fue", "est", "sont",
        "était", "é", "são", "foi",
    ]

    /// The words of the person of the six languages, lower case.
    static let personWords: Set<String> = [
        "i", "my", "me", "io", "mio", "mia", "miei", "mie", "mi", "ich", "mein", "meine", "mich", "mir", "je", "j", "mon", "ma", "mes",
        "moi", "yo", "mis", "eu", "meu", "minha", "meus", "minhas",
    ]

    /// Whether `sentence` starts, after a title of the person and its article, with "se" or "si" before a word, or with a word of 4
    /// letters or more ending in -a or -e and an article right after it: a rough rule for a verb of the third person, in the
    /// languages that drop the subject pronoun.
    static func inTheThirdPerson(_ sentence: String, titles: [[String]], language: String) -> Bool {
        guard let articles = verbArticles[language] else { return false }
        var words = sentence.lowercased().split { !$0.isLetter }.map(String.init)
        let skip = words.first.map(articles.contains) == true ? 1 : 0
        if let title = titles.first(where: { !$0.isEmpty && words.dropFirst(skip).map(fold).starts(with: $0) }) {
            words.removeFirst(skip + title.count)
        }
        guard words.count >= 2 else { return false }
        if ["se", "si"].contains(words[0]) && !["me", "mi"].contains(words[1]) && language != "pt" { return true }
        let verb = words[0]
        return verb.count >= 4 && (verb.hasSuffix("a") || verb.hasSuffix("e")) && articles.contains(words[1])
            && !["aba", "ava", "ía"].contains(where: verb.hasSuffix) && !(language == "it" && verb.hasSuffix("re"))
            && !notVerbs.contains(fold(verb))
    }

    /// The articles that follow a verb before its object, by language.
    static let verbArticles: [String: Set<String>] = [
        "es": ["el", "la", "los", "las", "un", "una", "su", "sus"],
        "it": ["il", "lo", "la", "i", "gli", "le", "l", "un", "uno", "una"],
        "pt": ["o", "a", "os", "as", "um", "uma", "seu", "sua"],
    ]

    /// Folded words ending in -a or -e that an article follows and that are no verb of the third person.
    static let notVerbs: Set<String> = [
        "para", "desde", "hasta", "entre", "sobre", "contra", "durante", "siempre", "ahora", "toda", "hice", "tuve", "estuve", "pude",
        "come", "dove", "mentre", "oltre", "sempre", "anche", "prima", "tutte", "agora", "ainda", "tive", "estive",
    ]

    /// The subject pronouns of the first person, which a summary sentence starts with before its verb.
    static let pronouns: Set<String> = ["i", "ich", "je", "j", "io", "yo", "eu"]

    // MARK: Soft skills and interests

    /// The words for a skill, a competence or an ability, which name no quality.
    static let skillWords: Set<String> = [
        "skill", "skills", "ability", "abilities", "competence", "competences", "competencies", "competenza", "competenze", "abilita",
        "capacita", "kompetenz", "kompetenzen", "fahigkeit", "fahigkeiten", "competencia", "competencias", "habilidad",
        "habilidades", "capacidad", "capacidades", "capacite", "capacites", "aptitude", "aptitudes", "habilidade", "capacidade",
        "knowledge", "understanding", "expertise", "wissen", "verstandnis", "kenntnis", "kenntnisse", "fachwissen", "conoscenza",
        "conoscenze", "comprensione", "conocimiento", "conocimientos", "comprension", "connaissance", "connaissances",
        "comprehension", "conhecimento", "conhecimentos", "compreensao",
    ]

    /// The parts of the words of one quality, by quality: two soft skills with a word of one group say one quality twice.
    static let qualityGroups: [[String]] = [
        ["precis", "präzis", "prazis", "attent", "attenz", "atenc", "atenç", "accura", "accurat", "genau", "sorgf", "exact", "rigor",
         "rigueur", "meticul", "minuz", "esmero", "cuidad", "cuidado"],
        ["teamw", "teamf", "collab", "colab", "coope", "zusammenarb", "squadra", "equipo", "équipe", "equipe"],
    ]

    /// The soft skills of a quality an earlier soft skill has.
    static func sameQualities(in cv: CVData) -> [ReaderFinding] {
        var seen: Set<Int> = []
        var found: [ReaderFinding] = []
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill {
            let words = skill.name.lowercased().split { !$0.isLetter }.map(String.init)
            guard let group = qualityGroups.indices.first(where: { group in
                words.contains { word in qualityGroups[group].contains { word.hasPrefix($0) } }
            }) else { continue }
            if !seen.insert(group).inserted {
                found.append(ReaderFinding(kind: .sameQuality, path: "skills[\(index)].name", value: skill.name))
            }
        }
        return found
    }

    /// The nouns of a tool, a device or a machine, folded.
    static let toolNouns: Set<String> = [
        "tool", "tools", "device", "devices", "equipment", "software", "machine", "machines", "werkzeug", "werkzeuge", "gerat",
        "gerate", "maschine", "maschinen", "strumento", "strumenti", "attrezzo", "attrezzi", "macchina", "macchine", "herramienta",
        "herramientas", "maquina", "maquinas", "outil", "outils", "appareil", "appareils", "ferramenta", "ferramentas",
    ]

    /// Whether a soft skill names a tool: its head noun (the last word in English and German, the first in the other languages)
    /// is a tool noun, or, in German, a compound that ends with one ("Messgerät").
    static func isTool(_ skill: String, language: String) -> Bool {
        let words = letterWords(of: skill)
        guard let head = ["en", "de"].contains(language) ? words.last : words.first else { return false }
        return toolNouns.contains(head) || language == "de" && toolNouns.contains { head.count > $0.count + 2 && head.hasSuffix($0) }
    }

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

    /// Whether an interest of more than one word starts with an inflected verb of its clause ("spiele Schach" of "und spiele Schach"),
    /// as the device tags the description, or, in German, "ich" and the interest, in English and German; a verb in the form of its
    /// infinitive ("play football", "hiking", "wandern") is the pastime's phrase.
    static func startsWithVerb(_ interest: String, in input: DraftingInput) -> Bool {
        let words = letterWords(of: interest)
        guard ["en", "de"].contains(input.language), words.count > 1, let first = words.first, isInflected(first, language: input.language),
              let range = input.description.range(of: interest, options: [.caseInsensitive, .diacriticInsensitive]) else { return false }
        let start = input.description.distance(from: input.description.startIndex, to: range.lowerBound)
        let tagger = DeviceLexicalTagger()
        return tagger.verbs(in: input.description, language: input.language).contains { $0.contains(start) }
            || input.language == "de" && tagger.verbs(in: "ich " + interest.prefix(1).lowercased() + interest.dropFirst(), language: "de")
                .contains { $0.contains(4) }
    }

    /// Whether a lowered verb is inflected, by its ending: in English "-s" or "-ed", in German anything but "-n".
    static func isInflected(_ verb: String, language: String) -> Bool {
        language == "de" ? !verb.hasSuffix("n") : verb.hasSuffix("ed") || verb.hasSuffix("s") && !verb.hasSuffix("ss")
    }

    /// Whether an interest of one noun is said in the description right after a verb that is not inflected ("football" of "I play
    /// football"), as the device tags the description, in English and German; a gerund or a German infinitive is no noun.
    static func losesItsVerb(_ interest: String, in input: DraftingInput) -> Bool {
        let words = letterWords(of: interest)
        guard ["en", "de"].contains(input.language), words.count == 1, let noun = words.first, !noun.hasSuffix("ing"),
              !(input.language == "de" && interest.first?.isLowercase == true) else { return false }
        let said = input.description
        let verbs = DeviceLexicalTagger().verbs(in: said, language: input.language)
        var spoken: [(word: String, start: Int)] = []
        var start: Int?
        for (offset, character) in said.enumerated() {
            if character.isLetter { if start == nil { start = offset } } else if let first = start {
                spoken.append((fold(String(Array(said)[first..<offset])), first)); start = nil
            }
        }
        if let first = start { spoken.append((fold(String(Array(said)[first...])), first)) }
        return spoken.indices.dropFirst().contains { index in
            spoken[index].word == noun && verbs.contains { $0.contains(spoken[index - 1].start) }
                && !isInflected(spoken[index - 1].word, language: input.language)
        }
    }

    /// The words of `text`, lowered, folded and split at anything not a letter.
    /// The first five letters of each word of `text` of three letters or more that links no other ("della", "and"): how a technology
    /// is matched to the description and to the tools of a trade.
    static func stems(of text: String) -> Set<String> {
        Set(letterWords(of: text).filter { $0.count >= 3 && !linkWords.contains($0) }.map { String($0.prefix(5)) })
    }

    private static let linkWords: Set<String> = [
        "the", "and", "for", "with", "del", "dei", "della", "delle", "degli", "dello", "per", "con", "und", "von", "der", "die", "das",
        "des", "les", "pour", "avec", "los", "las", "para", "com", "dos",
    ]

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
        "active", "collaborative", "document", "maintenance", "troubleshooting", "mixing", "systems", "electrical", "preventive", "printer",
        "printers", "scanner", "spreadsheet",
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

    /// The German nouns of an activity that are an infinitive with a capital ("Messen", "Verdrahten"): a word of the list, or one
    /// ending in "-ieren" ("Installieren").
    static let activityInfinitives: Set<String> = [
        "messen", "prufen", "bohren", "loten", "schweissen", "verdrahten", "montieren", "schneiden", "planen", "kochen", "backen",
        "reinigen", "reparieren", "warten", "verlegen", "anschliessen", "einbauen", "frasen", "schleifen",
    ]

    /// Whether a technology of one word is an activity in its infinitive: German only, where the noun of an activity is its
    /// infinitive with a capital.
    static func isActivity(_ name: String, language: String) -> Bool {
        guard language == "de" else { return false }
        let words = letterWords(of: name.replacingOccurrences(of: "ß", with: "ss"))
        guard words.count == 1, let word = words.first else { return false }
        return activityInfinitives.contains(word) || word.count > 7 && word.hasSuffix("ieren")
    }

    /// The head nouns that name a kind of tool and no tool, folded; the head is the last word in English and German, the first
    /// in the other languages.
    static let categoryNouns: Set<String> = [
        "software", "softwares", "program", "programs", "programma", "programmi", "programa", "programas", "programm", "programme",
        "application", "applications", "app", "apps", "applicazione", "applicazioni", "aplicacion", "aplicaciones", "aplicacao",
        "aplicativo", "aplicativos", "anwendung", "anwendungen", "logiciel", "logiciels", "platform", "platforms", "piattaforma",
        "plataforma", "plataformas", "plattform", "plateforme", "editor", "editors", "editeur", "workstation", "workstations",
        "tool", "tools", "ferramenta", "ferramentas", "herramienta", "herramientas", "strumento", "strumenti", "outil", "outils",
        "werkzeug", "werkzeuge",
    ]

    /// Whether a technology names a category and no tool of it: its head noun is a category noun, and none of its words is a
    /// name (a capital inside it, or at its start after the first word), an acronym or a number.
    static func isCategory(_ name: String, language: String) -> Bool {
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let folded = words.map(fold)
        guard let head = ["en", "de"].contains(language) ? folded.last : folded.first, categoryNouns.contains(head) else { return false }
        let named = words.enumerated().contains { index, word in
            word.count > 1 && word == word.uppercased() && word.contains(where: \.isLetter)
                || word.dropFirst().contains(where: \.isUppercase)
                || index > 0 && word.first?.isUppercase == true && language != "de"
                || word.contains(where: \.isNumber)
        }
        return !named
    }

    static func isEnglish(_ name: String, language: String) -> Bool {
        guard name.unicodeScalars.allSatisfy(\.isASCII) else { return false }
        let words = name.lowercased().split { !$0.isLetter }.map(String.init)
        let own = loanwords.union(languageLoanwords[language] ?? [])
        return !words.allSatisfy(own.contains) && words.contains(where: englishSkillWords.contains)
    }

    /// English words that one language writes as its own and another does not ("scanner" in Portuguese, "escáner" in Spanish).
    static let languageLoanwords: [String: Set<String>] = [
        "it": ["scanner"], "pt": ["scanner"], "fr": ["scanner"], "de": ["scanner"],
    ]

    /// Empty words as a soft skill, folded: experience, or being a professional, which name no quality. The words for a skill or a
    /// knowledge are `skillWords`.
    static let emptyWords: Set<String> = [
        "professional", "professionale", "professionell", "professionnel", "professionnelle", "profesional", "profissional",
        "experience", "esperienza", "erfahrung", "experiencia", "competent", "competente", "kompetent",
        "qualified", "qualificato", "qualifiziert", "qualifie", "qualifiee", "cualificado", "qualificado",
    ]

    /// Whether a technology is a part or a material the person installs or handles (`DraftingInputs.parts`), by the stem of its
    /// head noun: a part is no tool of the trade.
    static func isPart(_ name: String, of input: DraftingInput) -> Bool {
        guard let parts = DraftingInputs.parts[input.id] else { return false }
        let stems = Set(parts.flatMap { letterWords(of: $0) }.map(stem))
        return letterWords(of: name).contains { stems.contains(stem($0)) }
    }

    /// The jobs whose final description is under 40 characters while the step that writes a job pins a duty (`dutyCheck`) that the
    /// description does not hold: the step took the job for described with a duty the final check then moved out of it.
    static func shortDescribedJobs(in cv: CVData, for input: DraftingInput) -> [ReaderFinding] {
        let language = input.language
        let sanitizer = CVDataSanitizer(languageOfText: { _ in language })
        let letters = { (text: String) in fold(text).filter(\.isLetter) }
        return cv.experience.indices.compactMap { index in
            let description = cv.experience[index].description ?? ""
            guard description.count < CVDataSanitizer.DutyVerdicts.describedLength,
                  let check = try? sanitizer.dutyCheck(of: cv, job: index, duties: nil, against: input.description),
                  check.pinned.contains(where: { !letters(description).contains(letters($0)) }) else { return nil }
            return ReaderFinding(kind: .stepVsFinalPinned, path: "experience[\(index)].description", value: description)
        }
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
