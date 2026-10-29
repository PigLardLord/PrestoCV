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
    /// A summary sentence past the opening with no word of five letters or more in common with the description, the kept titles,
    /// the duties or the skills: a sentence of the person's work that says none of it ("I guarantee every action follows the
    /// established pattern"; #354, round 4, at d1d09c81).
    case unanchoredSummary
    /// A German separable verb written apart at the end of a subordinate clause, where it is one word ("dass ich … sicher stelle";
    /// #354, round 4, at d1d09c81), in the summary or a job's description.
    case splitVerb
    /// A technology that names a person, an activity or a document, and no tool: a role ("intérprete", "analista"), the noun of an
    /// activity ("Escaneo", "análisis de datos") or what the work produces ("fatture"; #354, round 5, at 0a135a4b).
    case nonToolTechnology
    /// A technology of one word that the description writes as the second of two modifiers of another technology's noun: the
    /// adjective cut from its noun ("pneumatici" of "schemi elettrici e pneumatici"; #354, round 5).
    case clippedModifier
    /// An Italian, Spanish or Portuguese summary sentence with no verb of the first person and no word of the person: the work
    /// spoken of, not the person speaking ("Ogni azione è guidata dalla cura…"; #354, round 5).
    case impersonalSummary
    /// An Italian, Spanish or Portuguese summary sentence that opens with a past participle, as a note, and has no verb or word of
    /// the person: the participle's "-o" read as the first person ("Mantenido un enfoque preciso…"; #354, round 6).
    case participleSummary
    /// Stationery as a technology, named alone or with a word after or before its noun ("cahiers d'exercices"); a pen that is a
    /// device ("penna ottica") is none (#354, round 6).
    case stationeryTechnology
    /// A German subordinate clause after "dass", "weil", "sodass" or "ob" whose finite verb is not its last word: the clause ends
    /// with a noun after the verb ("…, dass alle Anlagen funktionieren einwandfrei durch die Prüfung."; #354, round 5).
    case germanVerbPosition
    /// A summary sentence that says the person works or worked as something no title of the draft and not its headline is
    /// ("In passato ho lavorato come contabile" of the employer "Studio Contabile Merlini"; #354, round 7). A sentence that says
    /// the person is something counts only when it holds a word of a name, an employer or a school, a trap or a title not kept.
    case inventedSummaryTitle
    /// A technology the description does not state that holds a word of the name of an employer, a school or a person
    /// ("Kestrel forklift" of the employer "Kestrel Foods"; #354, round 7).
    case employerWordTechnology
    /// A technology whose head noun is a part, a material or a work object the person handles (`DraftingInputs.parts`), and not
    /// the object of a verb of use in the description ("quadri elettrici" of "controllando i quadri elettrici"; #354, round 7).
    case workObjectTechnology
    /// Two summary sentences that open with one verb, one of them the opening code writes ("Lavoro come capoturno." and "Lavoro
    /// da sedici anni…"; #354, round 7).
    case floorVerbCollision
    /// A word of the final draft that is two adjacent words of a raw answer, the first with a capital: a noun joined to the word
    /// after it as if it were a particle ("Teilachte" of "jedes Teil achte"; #354, round 8). Counted by `gluedWords`, which needs the
    /// answers.
    case gluedWord
    /// A job whose two sentences name one duty with one noun and two adjectives ("comunicazioni ufficiali" and "comunicazioni
    /// formali"; #354, round 8): the same duty said twice.
    case rewordedDuty
    /// Two summary sentences whose last clause after a comma opens and ends with one word ("…, was meine Verlässlichkeit beweist."
    /// and "…, was meine Konzentration beweist."; #354, round 8).
    case repeatedTail
    /// A technology the description does not state, nor the reader's list of the trade names as it is, whose head noun is a
    /// generic system, software, machine, set of tools or equipment, with only words of a work object or an activity around it
    /// and no product, name or device ("sistema di tracciamento dati", "máquina de escaneo de registros", "Montagesystem"; #354,
    /// round 9). A bare head is a category (`categoryAsTechnology`).
    case genericSystemTechnology
    /// A summary sentence in the present tense, after the opening, whose words of the work come mostly from the duties of an ended
    /// job and from no current one, while a job is current ("I maintain the machinery…" of an ended forklift driver; #354, round 10).
    case endedDutyInSummary
    /// A summary clause after a comma that praises the person's own quality ("…, was meine Präzision zeigt", "…, which shows my
    /// care"), after the first one of the summary (#354, round 10).
    case selfPraiseTail
    /// A word of how often ("daily", "mensuales", "annuel") in the summary or a job's duties, of a frequency the description does
    /// not say (#354, round 10).
    case inventedFrequency
    /// A soft skill of three words or more that opens with a gerund, a clause of the description ("working closely with directors";
    /// #354, round 10).
    case gerundSoftSkill
    /// A summary sentence that names a kept technology the description does not state ("mit dem Werkzeugkasten"; #354, round 11).
    case unstatedToolInSummary
    /// A summary sentence past the opening whose words of the work come from a duty the draft wrote, not from the description, at
    /// least as many as from the description ("Rispondo alle comunicazioni con i fornitori"; #354, round 11).
    case writtenDutyInSummary
    /// A word of a job's description, in lower case, that the description writes only inside the name of an employer
    /// ("transporte" of "Transportes Ebro Norte"; #354, round 11).
    case employerWordInDuty
    /// A duty of a vague phrase that names no task ("Ho svolto compiti legati alla gestione dei documenti"; #354, round 11).
    case vagueDuty
    /// A job's description that only says the person worked, with no word of the job ("Trabajé."; #354, round 11).
    case bareWorkDescription

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
        case .unanchoredSummary: "a summary sentence with no word of the work"
        case .splitVerb: "a German separable verb split in a subordinate clause"
        case .nonToolTechnology: "a person, an activity or a document as a technology"
        case .clippedModifier: "a modifier cut from its noun as a technology"
        case .impersonalSummary: "a summary sentence with no person speaking"
        case .participleSummary: "a summary sentence that opens with a participle"
        case .stationeryTechnology: "stationery as a technology"
        case .germanVerbPosition: "a German finite verb before the end of its subordinate clause"
        case .inventedSummaryTitle: "a summary sentence with a title the draft does not keep"
        case .employerWordTechnology: "a technology with a word of a name"
        case .workObjectTechnology: "a work object as a technology"
        case .floorVerbCollision: "the opening's verb opening another summary sentence"
        case .gluedWord: "a noun glued to the next word"
        case .rewordedDuty: "one duty said twice in a job"
        case .repeatedTail: "two summary sentences with one closing clause"
        case .genericSystemTechnology: "a generic system as a technology"
        case .endedDutyInSummary: "a duty of an ended job in the present in the summary"
        case .selfPraiseTail: "a self-praise closing clause after the first"
        case .inventedFrequency: "a frequency the description does not say"
        case .gerundSoftSkill: "a clause with a gerund as a soft skill"
        case .unstatedToolInSummary: "a summary sentence with a tool the description does not state"
        case .writtenDutyInSummary: "a summary sentence from a duty the draft wrote"
        case .employerWordInDuty: "a duty with a word of an employer's name"
        case .vagueDuty: "a duty of a vague phrase"
        case .bareWorkDescription: "a description that only says the person worked"
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
                } else if isPart(skill.name, of: input) {
                    found.append(ReaderFinding(kind: .workObjectTechnology, path: path, value: skill.name))
                } else if isNoTool(skill.name) || isActivity(skill.name, language: language) {
                    found.append(ReaderFinding(kind: .noToolOfTheTrade, path: path, value: skill.name))
                } else if isNonTool(skill.name, language: language) {
                    found.append(ReaderFinding(kind: .nonToolTechnology, path: path, value: skill.name))
                } else if isCategory(skill.name, language: language) {
                    found.append(ReaderFinding(kind: .categoryAsTechnology, path: path, value: skill.name))
                }
            }
            if skill.kind == .technology, isStationery(skill.name, language: language) {
                found.append(ReaderFinding(kind: .stationeryTechnology, path: path, value: skill.name))
            }
            if language != "en", isEnglish(skill.name, language: language) {
                found.append(ReaderFinding(kind: .skillInAnotherLanguage, path: path, value: skill.name))
            }
            if skill.kind == .technology, let known = tradeStems, !stems(of: skill.name).isSubset(of: known) {
                found.append(ReaderFinding(kind: .offTradeTechnology, path: path, value: skill.name))
            }
            if isClause(skill.name, language: language) {
                found.append(ReaderFinding(kind: .clauseAsSkill, path: path, value: skill.name))
            }
            if skill.kind == .technology, holdsAName(skill.name, of: input) {
                found.append(ReaderFinding(kind: .employerWordTechnology, path: path, value: skill.name))
            }
            if skill.kind == .technology, isGenericSystem(skill.name, of: input) {
                found.append(ReaderFinding(kind: .genericSystemTechnology, path: path, value: skill.name))
            }
        }
        found += clippedModifiers(in: cv, of: input)
        let vocabulary = Vocabulary.Language(rawValue: language)
        for (index, job) in cv.experience.enumerated() {
            let description = job.description ?? ""
            let forms = WrittenMeasure.sentences(of: description).compactMap { CVDataSanitizer.form(withoutConnector($0), language: vocabulary) }
            if Set(forms.map { "\($0)" }).count > 1 {
                found.append(ReaderFinding(kind: .twoForms, path: "experience[\(index)].description", value: description))
            }
            found += duties(of: job, at: index, language: language)
            found += fillers(in: job, at: index, of: input.description)
            found += rewordedDuties(in: description).map { ReaderFinding(kind: .rewordedDuty, path: "experience[\(index)].description", value: $0) }
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
        for (index, skill) in cv.skills.enumerated() where skill.kind == .softSkill && isGerundClause(skill.name, language: language) {
            found.append(ReaderFinding(kind: .gerundSoftSkill, path: "skills[\(index)].name", value: skill.name))
        }
        found += inventedFrequencies(in: cv, of: input.description)
        found += employerWords(in: cv, for: input)
        for (index, job) in cv.experience.enumerated() {
            found += WrittenMeasure.sentences(of: job.description ?? "").filter(isVague)
                .map { ReaderFinding(kind: .vagueDuty, path: "experience[\(index)].description", value: $0) }
        }
        for (index, job) in cv.experience.enumerated() {
            let sentences = WrittenMeasure.sentences(of: job.description ?? "")
            if !sentences.isEmpty, sentences.allSatisfy({ RoleStub.isStub($0, jobWords: [], language: vocabulary) }) {
                found.append(ReaderFinding(kind: .bareWorkDescription, path: "experience[\(index)].description", value: job.description ?? ""))
            }
        }
        for (index, interest) in cv.interests.enumerated() where isClause(interest) || startsWithVerb(interest, in: input) {
            found.append(ReaderFinding(kind: .clauseAsInterest, path: "interests[\(index)]", value: interest))
        }
        for (index, interest) in cv.interests.enumerated() where losesItsVerb(interest, in: input) {
            found.append(ReaderFinding(kind: .bareInterest, path: "interests[\(index)]", value: interest))
        }
        found += shortDescribedJobs(in: cv, for: input)
        if language == "de" {
            let texts = [("summary", cv.summary ?? "")] + cv.experience.enumerated().map { ("experience[\($0).description", $1.description ?? "") }
            found += texts.flatMap { path, text in splitVerbs(in: text).map { ReaderFinding(kind: .splitVerb, path: path, value: $0) } }
            found += texts.flatMap { path, text in
                verbsBeforeTheEnd(in: text).map { ReaderFinding(kind: .germanVerbPosition, path: path, value: $0) }
            }
        }
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

    /// The French pronouns and the negation that stand between "je" and its verb.
    private static let frenchPronounsBeforeTheVerb: Set<String> = [
        "m", "me", "t", "te", "s", "se", "l", "le", "la", "les", "lui", "leur", "nous", "vous", "y", "en", "ne", "n",
    ]

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
            // The verb follows its object and reflexive pronouns: "je m'occupais" is in the past (#354, round 11).
            guard first == "je" || first == "j",
                  let verb = words.dropFirst().first(where: { !Self.frenchPronounsBeforeTheVerb.contains($0) }) else { return nil }
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
        // The anchors are the work itself: the titles, the duties the draft keeps and its tools, not the whole description (whose
        // "lavoro" anchored any sentence) and not the qualities (#354, round 5).
        let anchors = anchorStems(of: [cv.personalInfo.title ?? "", input.field ?? ""] + cv.experience.map(\.title)
            + input.facts.filter { $0.kind == .title }.flatMap(\.forms) + cv.experience.map { $0.description ?? "" }
            + cv.skills.filter { $0.kind == .technology }.map(\.name))
        found += sentences.dropFirst().filter { anchorStems(of: [$0]).isDisjoint(with: anchors) }
            .map { ReaderFinding(kind: .unanchoredSummary, path: "summary", value: $0) }
        if ["it", "es", "pt"].contains(input.language) {
            found += sentences.filter { !speaksAsThePerson($0, language: input.language) }
                .map { ReaderFinding(kind: .impersonalSummary, path: "summary", value: $0) }
            found += sentences.filter { opensWithAParticiple($0, language: input.language) }
                .map { ReaderFinding(kind: .participleSummary, path: "summary", value: $0) }
        }
        found += sentences.flatMap { sentence in
            inventedTitles(in: sentence, of: cv, for: input).map { _ in ReaderFinding(kind: .inventedSummaryTitle, path: "summary", value: sentence) }
        }
        found += floorCollisions(in: sentences).map { ReaderFinding(kind: .floorVerbCollision, path: "summary", value: $0) }
        found += repeatedTails(in: sentences).map { ReaderFinding(kind: .repeatedTail, path: "summary", value: $0) }
        found += endedDuties(in: sentences, of: cv, language: input.language)
            .map { ReaderFinding(kind: .endedDutyInSummary, path: "summary", value: $0) }
        found += selfPraiseTails(in: sentences).map { ReaderFinding(kind: .selfPraiseTail, path: "summary", value: $0) }
        found += unstatedTools(in: sentences, of: cv, for: input)
            .map { ReaderFinding(kind: .unstatedToolInSummary, path: "summary", value: $0) }
        found += writtenDutySentences(in: sentences, of: cv, for: input)
            .map { ReaderFinding(kind: .writtenDutyInSummary, path: "summary", value: $0) }
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

    /// The first five letters of the words of five letters or more of `texts` that say nothing of a work ("every", "always",
    /// "sempre"): what a summary sentence shares with the work it is about.
    static func anchorStems(of texts: [String]) -> Set<String> {
        Set(texts.flatMap(letterWords(of:)).filter { $0.count >= 5 && !commonWords.contains($0) }.map { String($0.prefix(5)) })
            .subtracting(workStopStems)
    }

    /// The stems of the words for work of any trade ("lavoro", "tâche", "Aufgabe", "element", "process"): a sentence that shares
    /// only one of them with the work names none of it (#354, round 5).
    static let workStopStems: Set<String> = [
        "lavor", "attiv", "compi", "traba", "tarea", "taref", "trava", "tache", "arbei", "aufga", "eleme", "proce", "activ", "tasks",
        "teams",
    ]

    /// Whether an Italian, Spanish or Portuguese sentence speaks as the person: a word of the person ("mi", "yo", "meu"), an
    /// auxiliary of the first person ("ho", "sono", "tengo"), or a verb in "-o" first, or first after a comma ("Gestisco …",
    /// "Con cura, verifico …"). A rough rule: "Con cura verifico" is not read.
    static func speaksAsThePerson(_ sentence: String, language: String) -> Bool {
        let words = letterWords(of: sentence)
        if words.contains(where: (speakerWords[language] ?? []).contains) { return true }
        let firsts = sentence.split(separator: ",").compactMap { letterWords(of: String($0)).first { !connectors.contains($0) } }
        return firsts.contains { $0.count >= 3 && $0.hasSuffix("o") && !determiners.contains($0) && !isGerund($0, language: language) }
    }

    /// Whether a folded word of six letters or more ends as a gerund, "-ando" or "-endo", and "-indo" in Portuguese, and is no first
    /// person of the same ending ("comprendo", "atiendo"): a gerund after a comma is no verb of the person ("…, garantendo …").
    static func isGerund(_ word: String, language: String) -> Bool {
        guard word.count >= 6, let endings = gerundEndings[language], endings.contains(where: word.hasSuffix) else { return false }
        return !(firstPersonsAsGerunds[language] ?? []).contains(word)
    }

    private static let gerundEndings: [String: [String]] = ["it": ["ando", "endo"], "es": ["ando", "endo"], "pt": ["ando", "endo", "indo"]]

    /// The first persons that end as a gerund, folded.
    static let firstPersonsAsGerunds: [String: Set<String>] = [
        "it": [
            "mando", "comando", "domando", "raccomando", "rimando", "prendo", "comprendo", "apprendo", "riprendo", "sorprendo",
            "intraprendo", "vendo", "rendo", "difendo", "attendo", "intendo", "pretendo", "estendo", "tendo", "stendo", "spendo",
            "dipendo", "sospendo", "accendo", "scendo", "ascendo", "espando", "contendo", "offendo",
        ],
        "es": [
            "mando", "comando", "demando", "ando", "atiendo", "entiendo", "extiendo", "defiendo", "enciendo", "desciendo", "asciendo",
            "tiendo", "pretendo", "vendo", "comprendo", "aprendo", "emprendo", "sorprendo", "dependo", "suspendo", "ofendo",
            "enmiendo", "recomiendo", "expando",
        ],
        "pt": [
            "mando", "comando", "demando", "ando", "recomendo", "vendo", "entendo", "atendo", "defendo", "estendo", "aprendo",
            "compreendo", "empreendo", "prendo", "surpreendo", "dependo", "suspendo", "acendo", "pretendo", "brindo", "expando",
        ],
    ]

    /// Whether an Italian, Spanish or Portuguese sentence opens with a past participle (`isParticiple`) and nothing else in it speaks
    /// as the person: no word of the person, and no verb of the first person first after a comma ("Abituato al rumore, controllo …"
    /// speaks).
    static func opensWithAParticiple(_ sentence: String, language: String) -> Bool {
        let words = letterWords(of: sentence)
        guard let first = words.first, isParticiple(first, language: language),
              !words.contains(where: (speakerWords[language] ?? []).contains) else { return false }
        let firsts = sentence.split(separator: ",").dropFirst().compactMap { letterWords(of: String($0)).first { !connectors.contains($0) } }
        return !firsts.contains {
            $0.count >= 3 && $0.hasSuffix("o") && !determiners.contains($0) && !isParticiple($0, language: language)
                && !isGerund($0, language: language)
        }
    }

    /// Whether a folded word of six letters or more ends as a past participle: "-ato", "-ito" or "-uto" in Italian, "-ado" or "-ido"
    /// in Spanish and Portuguese, and is no first person of the same ending that a summary writes ("valuto", "decido"). A rough rule:
    /// a first person missing from the list reads as a participle.
    static func isParticiple(_ word: String, language: String) -> Bool {
        guard word.count >= 6, let endings = participleEndings[language], endings.contains(where: word.hasSuffix) else { return false }
        return !(firstPersonsAsParticiples[language] ?? []).contains(word)
    }

    private static let participleEndings: [String: [String]] = ["it": ["ato", "ito", "uto"], "es": ["ado", "ido"], "pt": ["ado", "ido"]]

    /// The first persons that end as a participle, folded.
    static let firstPersonsAsParticiples: [String: Set<String>] = [
        "it": [
            "valuto", "saluto", "rifiuto", "discuto", "disputo", "computo", "recluto", "visito", "medito", "facilito", "sollecito",
            "esercito", "accredito", "deposito", "abilito", "riabilito", "delimito", "limito", "invito", "recito", "agito", "ospito",
        ],
        "es": [
            "decido", "divido", "subdivido", "valido", "convalido", "consolido", "liquido", "presido", "resido", "coincido", "impido",
            "despido", "expido", "traslado", "persuado", "disuado", "agrado", "degrado", "olvido", "invado", "evado",
        ],
        "pt": [
            "decido", "divido", "subdivido", "valido", "consolido", "liquido", "presido", "resido", "coincido", "duvido", "convido",
            "agrido", "agrado", "degrado", "persuado", "dissuado",
        ],
    ]

    /// The words of the person, and the auxiliaries of the first person, by language, folded.
    private static let speakerWords: [String: Set<String>] = [
        "it": ["io", "mi", "me", "mio", "mia", "miei", "mie", "ho", "sono", "sto", "posso"],
        "es": ["yo", "me", "mi", "mis", "mio", "mia", "conmigo", "he", "soy", "estoy", "tengo", "puedo"],
        "pt": ["eu", "me", "meu", "minha", "meus", "minhas", "comigo", "sou", "estou", "tenho", "posso"],
    ]

    /// The words in "-o" that open a sentence and are no verb: articles, determiners, prepositions.
    private static let determiners: Set<String> = [
        "uno", "ogni", "questo", "quello", "nello", "dello", "allo", "dallo", "sullo", "como", "todo", "cada", "este", "ese", "aquello",
        "esto", "eso", "durante", "dentro", "fuera", "nuestro", "vuestro", "nosso", "nao", "cuando", "quando", "tanto", "molto", "ciascuno",
        "isso", "isto", "aquilo", "ovunque", "solo",
    ]

    /// The clauses of German `text` after "dass", "weil", "sodass" or "ob" that end with a noun, a word with a capital, while
    /// a word in lower case in "-en" or "-t" before it is the verb: the finite verb stands before the end ("dass alle Anlagen funktionieren
    /// einwandfrei durch die Prüfung"; #354, round 5). A clause of fewer than three words is not read.
    static func verbsBeforeTheEnd(in text: String) -> [String] {
        text.split { ",;.!?".contains($0) }.compactMap { clause in
            let words = clause.split { !$0.isLetter }.map(String.init)
            guard let start = words.firstIndex(where: { ["dass", "weil", "sodass", "ob"].contains($0.lowercased()) }) else { return nil }
            let rest = words[(start + 1)...]
            guard rest.count >= 3, let last = rest.last, last.first?.isUppercase == true,
                  rest.dropLast().contains(where: { $0.count >= 4 && $0.first?.isLowercase == true && ($0.hasSuffix("en") || $0.hasSuffix("t")) })
            else { return nil }
            return clause.trimmingCharacters(in: .whitespaces)
        }
    }

    /// Whether a technology names a person, an activity or a document: its head noun (the last word in English and German, the
    /// first in the other languages) is a role, the noun of an activity, or a document (`nonToolHeads`), or, of two words or more,
    /// ends as the noun of an action ("generación de informes"). A name or an acronym in it names a tool ("analisi FMEA").
    static func isNonTool(_ name: String, language: String) -> Bool {
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.contains(where: { $0.count >= 2 && $0 == $0.uppercased() || $0.contains(where: \.isNumber) }) else { return false }
        let folded = words.map(fold).filter { !linkWords.contains($0) && $0.count > 1 }
        guard let head = ["en", "de"].contains(language) ? folded.last : folded.first else { return false }
        return nonToolHeads.contains(head)
            || folded.count > 1 && ["zione", "cion", "cao", "tion", "sione", "sion", "sao"].contains(where: head.hasSuffix)
    }

    /// Whether a technology is stationery: its head noun (the last word in English and German, the first in the other languages)
    /// is in `stationeryHeads`, and no word of it makes it a device (`deviceWords`).
    static func isStationery(_ name: String, language: String) -> Bool {
        let folded = name.split { !$0.isLetter && !$0.isNumber }.map { fold(String($0)) }
            .filter { !linkWords.contains($0) && $0.count > 1 }
        guard let head = ["en", "de"].contains(language) ? folded.last : folded.first else { return false }
        return stationeryHeads.contains(head) && folded.allSatisfy { !deviceWords.contains($0) }
    }

    /// The head nouns of stationery, folded, singular and plural, in the six languages.
    static let stationeryHeads: Set<String> = [
        "pen", "pens", "pencil", "pencils", "paper", "notepad", "notepads",
        "cahier", "cahiers", "carnet", "carnets", "stylo", "stylos", "crayon", "crayons", "feutre", "feutres", "papier",
        "quaderno", "quaderni", "penna", "penne", "matita", "matite", "taccuino", "taccuini", "pennarello", "pennarelli",
        "cuaderno", "cuadernos", "libreta", "libretas", "boligrafo", "boligrafos", "lapiz", "lapices", "rotulador", "rotuladores",
        "caderno", "cadernos", "caneta", "canetas", "lapis", "caderneta", "cadernetas",
        "heft", "hefte", "stift", "stifte", "bleistift", "bleistifte", "kugelschreiber", "notizblock",
    ]

    /// The words, folded, that make a pen a device of a trade ("penna ottica", "digital pens").
    static let deviceWords: Set<String> = [
        "digital", "digitale", "digitali", "numerique", "numeriques", "optique", "ottica", "ottiche", "optico", "opticos", "optica",
        "otica", "otico", "optical", "electronic", "elettronica", "electronico", "eletronica", "elektronisch", "elektronische",
        "interactive", "interattiva", "interactivo", "interativa", "interaktiv", "interaktive", "smart", "3d",
    ]

    /// The head nouns of a role, an activity or a document, folded, in the six languages.
    static let nonToolHeads: Set<String> = [
        "interprete", "analista", "analyst", "programmatore", "programador", "developer", "entwickler", "tecnico", "technician",
        "techniker", "operatore", "operador", "operator", "assistente", "assistant", "consulente", "consultor", "consultant",
        "escaneo", "scansione", "escaneamento", "scanning", "registro", "registros", "registrazione", "analisi", "analisis", "analise",
        "analysis", "analyse", "monitoraggio", "monitoreo", "monitoramento", "monitoring", "riparazione", "reparacion", "reparo",
        "repair", "pulizia", "limpieza", "limpeza", "cleaning", "nettoyage", "reinigung",
        "fatture", "fattura", "facturas", "factura", "faturas", "fatura", "invoices", "invoice", "rechnungen", "rechnung", "factures",
        "facture", "report", "reports", "rapporti", "informes", "informe", "relatorios", "relatorio", "rapports", "berichte", "bericht",
        "contratti", "contratos", "contracts", "contrats", "vertrage", "documentos", "dokumente",
    ]

    /// The technologies of one word that the description writes as the second of two modifiers of another technology's noun, cut
    /// from it: after "and" and the other's last word, with the same ending, in the languages that put the modifier after its noun
    /// ("pneumatici" of "schemi elettrici e pneumatici", with "schemi elettrici" listed; #354, round 5); before "and" and the
    /// other's first word in English (an adjective: "hydraulic" of "hydraulic and electric diagrams") and German (in lower case).
    /// A noun joined to another technology ("tubi flessibili e valvole", "valves and flexible hoses") is not one.
    static func clippedModifiers(in cv: CVData, of input: DraftingInput) -> [ReaderFinding] {
        let technologies = cv.skills.enumerated().filter { $0.element.kind == .technology }
        let phrases = technologies.map { letterWords(of: $0.element.name) }.filter { $0.count > 1 }
        let raw = input.description.split { !$0.isLetter }.map(String.init)
        let said = raw.map(fold)
        let joins: Set<String> = ["e", "ed", "and", "und", "y", "et", "ou", "oder", "or", "o"]
        let adjectiveEndings = ["ic", "al", "ive", "ous", "able", "ible", "ary", "ful"]
        let first = ["en", "de"].contains(input.language)
        return technologies.compactMap { index, skill in
            let words = letterWords(of: skill.name)
            guard words.count == 1, let word = words.first, skill.name != skill.name.uppercased() else { return nil }
            let clipped = said.indices.contains { at in
                guard said[at] == word else { return false }
                if first {
                    guard at + 2 < said.count, joins.contains(said[at + 1]), phrases.contains(where: { $0.first == said[at + 2] })
                    else { return false }
                    return input.language == "de" ? raw[at].first?.isLowercase == true : adjectiveEndings.contains(where: word.hasSuffix)
                }
                return at >= 2 && joins.contains(said[at - 1])
                    && phrases.contains { $0.last == said[at - 2] && said[at - 2].suffix(2) == word.suffix(2) }
            }
            return clipped ? ReaderFinding(kind: .clippedModifier, path: "skills[\(index)].name", value: skill.name) : nil
        }
    }

    /// Words of five letters or more of any text, folded.
    private static let commonWords: Set<String> = [
        "every", "their", "there", "which", "while", "where", "these", "those", "about", "after", "before", "other", "always",
        "being", "ensure", "ensures", "della", "delle", "degli", "dello", "nella", "nelle", "negli", "sulla", "sulle", "sempre",
        "molto", "grande", "grandi", "mentre", "quando", "stato", "stata", "essere", "avere", "tutti", "tutte", "tutto", "costante",
        "constant", "consistent", "chaque", "leurs", "toute", "toutes", "faire", "avoir", "einer", "einem", "einen", "eines",
        "jeden", "jedes", "immer", "durch", "nicht", "sowie", "wobei", "damit", "dabei", "indem", "siempre", "entre", "sobre",
        "desde", "hasta", "mediante", "todos", "todas", "muito",
    ]

    /// The separable verbs of German written apart at the end of a subordinate clause ("dass ich die Leitungen sicher stelle"): a
    /// clause with a subordinating word whose last two words are a verb particle and a finite verb. In a main clause the particle
    /// ends the clause apart ("Ich stelle die Funktion sicher"), and is no finding.
    static func splitVerbs(in text: String) -> [String] {
        text.split { ",;.!?".contains($0) }.compactMap { clause in
            let words = letterWords(of: String(clause))
            // A particle is in lower case: "jedes Teil achte" is a noun before the verb (#354, round 8).
            let particle = clause.split { !$0.isLetter }.dropLast().last
            guard words.count >= 3, !subordinators.isDisjoint(with: words), let verb = words.last, verb.count >= 4,
                  particle?.first?.isLowercase == true,
                  verbParticles.contains(words[words.count - 2]), ["e", "t", "en", "st"].contains(where: verb.hasSuffix) else { return nil }
            return words.suffix(2).joined(separator: " ")
        }
    }

    private static let subordinators: Set<String> = [
        "dass", "weil", "wenn", "indem", "ob", "damit", "als", "wobei", "sodass", "nachdem", "bevor", "wahrend", "obwohl", "falls",
    ]

    private static let verbParticles: Set<String> = [
        "sicher", "fest", "her", "dar", "an", "auf", "aus", "ein", "mit", "vor", "zuruck", "fort", "weiter", "bereit",
        "instand", "statt", "teil", "nach", "ab", "zusammen", "vorbei", "hin", "los",
    ]

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

    static let linkWords: Set<String> = [
        "the", "and", "for", "with", "del", "dei", "della", "delle", "degli", "dello", "per", "con", "und", "von", "der", "die", "das",
        "des", "les", "pour", "avec", "los", "las", "para", "com", "dos",
    ]

    /// A skill of more than four words, unless it is three words joined by prepositions ("logiciel de suivi de lecture", #354, round 6).
    static func isClause(_ name: String, language: String) -> Bool {
        let words = letterWords(of: name)
        guard words.count > 4 else { return false }
        let joining = joiningWords[language] ?? []
        guard words.count <= 6, let first = words.first, let last = words.last, !joining.contains(first), !joining.contains(last) else {
            return true
        }
        return words.filter { !joining.contains($0) }.count > 3
    }

    /// The prepositions that join the words of a tool's name, folded; the French "à" is left out, as folded it is "a" (has).
    static let joiningWords: [String: Set<String>] = [
        "en": ["of", "for"], "it": ["di", "del", "dello", "della", "dei", "degli", "delle", "per"], "es": ["de", "del", "para"],
        "fr": ["de", "du", "des", "d", "au", "aux", "pour"], "pt": ["de", "do", "da", "dos", "das", "para"],
        "de": ["von", "fur", "zur", "zum"],
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
        // A kind with a word of its trade names what it is for ("software de contabilidad", "editor de código"); a bare kind, or one
        // with only a word of any trade ("editor de texto", "development platform"), names none (#354, round 5).
        let modifiers = folded.filter { $0 != head && !linkWords.contains($0) && !shortLinkWords.contains($0) }
        return !named && modifiers.allSatisfy(genericModifiers.contains)
    }

    /// The link words of two letters or less of the six languages ("de", "di", "of"), folded.
    static let shortLinkWords: Set<String> = ["de", "di", "da", "do", "du", "of", "d", "l", "a", "e", "y", "et", "el", "la", "le", "il"]

    /// The words that tell no trade's kind of tool from another, folded.
    static let genericModifiers: Set<String> = [
        "texto", "text", "testo", "texte", "desenvolvimento", "desarrollo", "development", "sviluppo", "developpement", "entwicklung",
        "dados", "datos", "data", "dati", "donnees", "daten",
    ]

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

    /// Whether a technology is a part, a material or a work object the person handles (`DraftingInputs.parts`), by the stem of its
    /// head noun (the last word in English and German, the first in the other languages), unless the description writes it after
    /// a verb of use ("uso i PLC"): a work object is no tool of the trade.
    static func isPart(_ name: String, of input: DraftingInput) -> Bool {
        guard let parts = DraftingInputs.parts[input.id], let head = headWord(of: name, language: input.language) else { return false }
        let heads = Set(parts.compactMap { headWord(of: $0, language: input.language) }.map(stem))
        guard heads.contains(stem(head)) else { return false }
        let words = letterWords(of: input.description)
        return !words.indices.contains { index in
            useVerbs.contains(words[index]) && words[(index + 1)...].prefix(3).contains { stem($0) == stem(head) }
        }
    }

    /// The head noun of a name: its last word in English and German, its first in the other languages.
    static func headWord(of name: String, language: String) -> String? {
        let words = letterWords(of: name).filter { $0.count >= 3 }
        return ["en", "de"].contains(language) ? words.last : words.first
    }

    /// The verbs of use of the first person, folded: their object is a tool the person uses.
    static let useVerbs: Set<String> = [
        "use", "using", "uso", "utilizzo", "adopero", "utilizo", "benutze", "nutze", "verwende", "utilise", "usei", "utilizei",
    ]

    /// Whether a technology is a generic system (`ReaderClass.genericSystemTechnology`): the description does not state it and the
    /// reader's list of the trade (`DraftingInputs.vocabularies`) does not hold it as it is; its head noun (the last word in English
    /// and German, the first in the other languages, or the end of a German compound with a word before it) is in `genericHeads`;
    /// it has another word, and none of its words is a name, an acronym, a number or a word of a device (`deviceWords`).
    static func isGenericSystem(_ name: String, of input: DraftingInput) -> Bool {
        let whole = fold(name)
        guard !fold(input.description).contains(whole),
              !(DraftingInputs.vocabularies[input.id] ?? []).contains(where: { fold($0) == whole }) else { return false }
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let named = words.enumerated().contains { index, word in
            word.count > 1 && word == word.uppercased() && word.contains(where: \.isLetter)
                || word.dropFirst().contains(where: \.isUppercase)
                || index > 0 && word.first?.isUppercase == true && input.language != "de"
                || word.contains(where: \.isNumber)
        }
        let content = words.map(fold).filter { !linkWords.contains($0) && !shortLinkWords.contains($0) }
        guard !named, !content.contains(where: deviceWords.contains) else { return false }
        if input.language == "de", content.count == 1, let word = content.first {
            return genericCompoundEnds.contains { word.count > $0.count + 2 && word.hasSuffix($0) }
        }
        guard content.count > 1, let head = ["en", "de"].contains(input.language) ? content.last : content.first else { return false }
        return genericHeads.contains(head)
    }

    /// The head nouns of a generic system, software, machine, set of tools or equipment, folded, in the six languages.
    static let genericHeads: Set<String> = [
        "system", "systems", "sistema", "sistemi", "sistemas", "systeme", "systemes",
        "software", "softwares", "logiciel", "logiciels", "programma", "programmi", "programa", "programas", "programme", "programm",
        "machine", "machines", "maquina", "maquinas", "macchina", "macchine", "maschine", "maschinen",
        "tool", "tools", "strumento", "strumenti", "herramienta", "herramientas", "outil", "outils", "werkzeug", "werkzeuge",
        "ferramenta", "ferramentas", "device", "devices", "gerat", "gerate", "dispositivo", "dispositivi", "dispositivos", "dispositif",
        "dispositifs", "equipment", "attrezzatura", "attrezzature", "apparecchiatura", "apparecchiature", "equipo", "equipos",
        "equipement", "equipements", "equipamento", "equipamentos", "ausrustung",
    ]

    /// The ends of a German compound whose head is a generic system ("Montagesystem"), folded.
    static let genericCompoundEnds = ["system", "systeme", "software", "gerat", "gerate", "maschine", "maschinen", "werkzeuge"]

    /// Whether a technology the description does not state holds a word of the name of a person, an employer or a school of
    /// `input`: a word the description writes only with a capital ("Kestrel" of "Kestrel Foods"; "Logistics" is also "logistics").
    static func holdsAName(_ name: String, of input: DraftingInput) -> Bool {
        guard !fold(input.description).contains(fold(name)) else { return false }
        let lowered = Set(input.description.split { !$0.isLetter }.filter { $0.first?.isLowercase == true }.map { fold(String($0)) })
        let names = Set(input.facts.filter { [.name, .employer, .school].contains($0.kind) }
            .flatMap(\.forms).flatMap { $0.split { !$0.isLetter } }
            .filter { $0.count >= 3 && $0.first?.isUppercase == true }.map { fold(String($0)) })
            .subtracting(lowered)
        return name.split { !$0.isLetter }.contains { $0.first?.isUppercase == true && names.contains(fold(String($0))) }
    }

    /// The titles a summary sentence says the person works or worked as ("I worked as a forklift driver at…") that are no title
    /// the draft keeps nor a part of one; of a sentence that says the person is something ("Sono X"), only those with a word of a
    /// name, an employer, a school or a trap, or of a title the input states and the draft does not keep.
    static func inventedTitles(in sentence: String, of cv: CVData, for input: DraftingInput) -> [String] {
        let joined = { (text: String) in letterWords(of: text).joined(separator: " ") }
        let stated = input.facts.filter { $0.kind == .title }.flatMap(\.forms)
        let kept = ([cv.personalInfo.title ?? ""] + cv.experience.map(\.title) + stated).map(joined).filter { !$0.isEmpty }
        let isKept = { (title: String) in kept.contains { " \($0) ".contains(" \(title) ") } }
        let unkept = input.facts.filter { $0.kind == .title }.map(\.forms[0])
            .filter { form in !([cv.personalInfo.title ?? ""] + cv.experience.map(\.title)).map(joined).contains(joined(form)) }
        let foreign = Set((input.facts.filter { [.name, .employer, .school].contains($0.kind) }.flatMap(\.forms) + input.traps + unkept)
            .flatMap(letterWords(of:)).filter { $0.count >= 4 })
        let words = sentence.replacingOccurrences(of: ",", with: " , ").split(whereSeparator: \.isWhitespace)
            .flatMap { $0 == "," ? [","] : letterWords(of: String($0)) }
        var found: [String] = []
        for (index, word) in words.enumerated() {
            let next = index + 1 < words.count ? words[index + 1] : ""
            let isWork = workAs[input.language]?.contains { $0 == [word, next] } ?? false
            let isBeing = beingAs[input.language]?.contains(word) ?? false
            guard isWork || isBeing,
                  isWork || index == 0 || pronouns.union(["e", "and", "y", "et", "und"]).contains(words[index - 1]) else { continue }
            var rest = Array(words[(index + (isWork ? 2 : 1))...])
            while let first = rest.first, ["stato", "stata", "a", "an", "un", "una", "uno", "une", "um", "uma", "ein", "eine"].contains(first) {
                rest.removeFirst()
            }
            // A title after the last "and" is one of a list ("A, B and C") or ends the sentence: "programador e crio soluções
            // para…" joins a verb, not a title.
            let cut = Array(rest.prefix { !titleEnds.contains($0) })
            let parts = cut.split { [",", "e", "and", "y", "et", "und"].contains($0) }.map { $0.joined(separator: " ") }
            let isAList = cut.contains(",") || cut.count == rest.count
            let titles = isAList ? parts : Array(parts.prefix(1))
            for title in titles where !title.isEmpty && !isKept(title) {
                if isWork || !Set(title.split(separator: " ").map(String.init)).isDisjoint(with: foreign) { found.append(title) }
            }
        }
        return found
    }

    /// The two words that say the person works or worked as a title ("lavorato come"), folded, by language.
    static let workAs: [String: [[String]]] = [
        "en": [["work", "as"], ["worked", "as"], ["working", "as"]],
        "it": [["lavoro", "come"], ["lavorato", "come"], ["lavoravo", "come"]],
        "de": [["arbeite", "als"], ["habe", "als"], ["arbeitete", "als"]],
        "fr": [["travaille", "comme"], ["travaillais", "comme"]],
        "es": [["trabajo", "como"], ["trabaje", "como"], ["trabajado", "como"]],
        "pt": [["trabalho", "como"], ["trabalhei", "como"], ["trabalhado", "como"]],
    ]

    /// The verbs that say the person is or was something, folded, by language.
    static let beingAs: [String: Set<String>] = [
        "en": ["am", "was"], "it": ["sono", "ero"], "de": ["bin", "war"], "fr": ["suis", "etais"], "es": ["soy", "era"],
        "pt": ["sou", "era"],
    ]

    /// The words a title in a sentence ends before: a place, an employer, a time or a clause.
    static let titleEnds: Set<String> = [
        "at", "in", "for", "with", "since", "from", "during", "where", "who", "that", "gearbeitet", "presso", "alla", "al", "allo", "ai",
        "a", "nel", "nella", "per", "da", "dal", "dalla", "con", "dove", "che", "bei", "fur", "seit", "im", "wo", "und", "chez",
        "au", "en", "dans", "depuis", "pour", "avec", "ou", "qui", "que", "em", "na", "no", "desde", "para", "durante", "onde",
        "donde", "con",
    ]

    /// The words of the summary and of the job descriptions of `cv` that are two adjacent words of one of `answers` (the raw answers
    /// of the requests, with the sentences a repair request was given), the first with a capital and the second without.
    static func gluedWords(in cv: CVData, answers: [String]) -> [ReaderFinding] {
        let split = { (text: String) in text.split { !$0.isLetter }.map(String.init) }
        var joined: Set<String> = []
        for answer in answers {
            let words = split(answer)
            for (first, second) in zip(words, words.dropFirst())
            where first.first?.isUppercase == true && second.first?.isLowercase == true && first.count >= 2 && second.count >= 2 {
                joined.insert((first + second).lowercased())
            }
        }
        let texts = [("summary", cv.summary ?? "")] + cv.experience.enumerated().map { ("experience[\($0.offset)].description", $0.element.description ?? "") }
        return texts.flatMap { path, text in
            split(text).filter { joined.contains($0.lowercased()) }
                .map { ReaderFinding(kind: .gluedWord, path: path, value: $0) }
        }
    }

    /// "<noun> <adjective> / <noun> <other adjective>" for each noun of 7 letters or more, not a sentence's first word, that two
    /// sentences of `description` follow with two different words of 5 letters or more.
    static func rewordedDuties(in description: String) -> [String] {
        var seen: [String: (next: String, sentence: Int)] = [:]
        var found: [String] = []
        for (number, sentence) in WrittenMeasure.sentences(of: description).enumerated() {
            let words = letterWords(of: sentence)
            for (first, second) in zip(words.dropFirst(), words.dropFirst(2)) where first.count >= 7 && second.count >= 5 {
                if let earlier = seen[first], earlier.sentence != number, earlier.next != second {
                    found.append("\(first) \(earlier.next) / \(first) \(second)")
                } else if seen[first] == nil {
                    seen[first] = (second, number)
                }
            }
        }
        return found
    }

    /// The summary sentences whose last clause after a comma, of 3 words or more, opens and ends with the words of such a clause
    /// of an earlier sentence.
    static func repeatedTails(in sentences: [String]) -> [String] {
        var tails: Set<[String]> = []
        return sentences.filter { sentence in
            guard sentence.contains(","), let clause = sentence.split(separator: ",").last else { return false }
            let words = letterWords(of: String(clause))
            guard words.count >= 3, let first = words.first, let last = words.last else { return false }
            return !tails.insert([first, last]).inserted
        }
    }

    /// The summary sentences after the opening, in the present tense, whose words of the work (`anchorStems`) are at least three
    /// and at least half from the duties of the ended jobs and not from the titles and duties of the current ones, when a job is
    /// current and one has ended.
    static func endedDuties(in sentences: [String], of cv: CVData, language: String) -> [String] {
        let ended = cv.experience.filter { !$0.current }
        let current = cv.experience.filter(\.current)
        guard !ended.isEmpty, !current.isEmpty else { return [] }
        let endedStems = anchorStems(of: ended.map { $0.description ?? "" })
        let currentStems = anchorStems(of: current.map { $0.description ?? "" } + current.map(\.title))
        return sentences.dropFirst().filter { sentence in
            guard tense(of: withoutConnector(sentence), language: language) == .present else { return false }
            let stems = anchorStems(of: [sentence])
            let only = stems.intersection(endedStems).subtracting(currentStems)
            return only.count >= 3 && only.count * 2 >= stems.count
        }
    }

    /// The summary sentences with a clause after a comma that praises the person's own quality, after the first such sentence.
    static func selfPraiseTails(in sentences: [String]) -> [String] {
        Array(sentences.filter { sentence in
            let folded = " " + letterWords(of: sentence).joined(separator: " ") + " "
            return sentence.contains(",") && selfPraise.contains { folded.range(of: $0, options: .regularExpression) != nil }
        }.dropFirst())
    }

    /// The patterns of a self-praise clause over a sentence's folded words, joined by single spaces, in the six languages.
    static let selfPraise = [
        " was mein(e|en|er|em)? [a-z]+ [a-z]+ $", " which [a-z]+ my ", " che [a-z]+ (la mia|il mio|le mie|i miei) ",
        " ce qui [a-z]+ (mon|ma|mes) ", " lo que [a-z]+ (mi|mis) ", " o que [a-z]+ (o meu|a minha|os meus|as minhas) ",
    ]

    /// Whether a soft skill of three words or more opens with a gerund ("working closely with directors", "gestendo i rapporti
    /// con i clienti"), not followed by a conjunction ("planning and organising" is a pair of skills).
    static func isGerundClause(_ name: String, language: String) -> Bool {
        let words = letterWords(of: name)
        guard words.count >= 3, let first = words.first, !["and", "e", "y", "et", "und", "o", "or"].contains(words[1]) else { return false }
        switch language {
        case "en": return first.count > 5 && first.hasSuffix("ing")
        case "fr": return first == "en" && words[1].hasSuffix("ant")
        default: return isGerund(first, language: language)
        }
    }

    /// The words of how often in the summary and the job descriptions of `cv` whose frequency no word of `description` says.
    static func inventedFrequencies(in cv: CVData, of description: String) -> [ReaderFinding] {
        let said = Set(letterWords(of: description).compactMap(frequency(of:)))
        let texts = [("summary", cv.summary ?? "")]
            + cv.experience.enumerated().map { ("experience[\($0.offset)].description", $0.element.description ?? "") }
        return texts.flatMap { path, text in
            letterWords(of: text).filter { word in frequency(of: word).map { !said.contains($0) } ?? false }
                .map { ReaderFinding(kind: .inventedFrequency, path: path, value: $0) }
        }
    }

    // MARK: Round 11

    /// The summary sentences that name a kept technology whose words the description does not hold in a row.
    static func unstatedTools(in sentences: [String], of cv: CVData, for input: DraftingInput) -> [String] {
        let described = InventedFacts.words(of: input.description)
        let unstated = cv.skills.filter { $0.kind == .technology }.map { InventedFacts.words(of: $0.name) }
            .filter { !$0.isEmpty && !InventedFacts.holds(described, run: $0) }
        return sentences.filter { sentence in
            let words = InventedFacts.words(of: sentence)
            return unstated.contains { InventedFacts.holds(words, run: $0) }
        }
    }

    /// The summary sentences past the opening that share a word of the work with a duty the draft wrote (one of whose words of five
    /// letters or more fewer than half are in the description) and not with the description, at least as many as they share with
    /// the description. A description with no word of the work has no duty to tell apart.
    static func writtenDutySentences(in sentences: [String], of cv: CVData, for input: DraftingInput) -> [String] {
        let said = Set(longWords(of: input.description).map { $0.prefix(5) })
        let stated = anchorStems(of: [input.description])
        guard !stated.isEmpty else { return [] }
        let written = cv.experience.flatMap { WrittenMeasure.sentences(of: $0.description ?? "") }.filter { sentence in
            let words = longWords(of: sentence)
            return !words.isEmpty && Double(words.count { said.contains($0.prefix(5)) }) / Double(words.count) < 0.5
        }
        let writtenStems = anchorStems(of: written).subtracting(stated).subtracting(idleSummaryStems)
        return sentences.dropFirst().filter { sentence in
            let own = anchorStems(of: [sentence])
            let fromWritten = own.intersection(writtenStems)
            return !fromWritten.isEmpty && fromWritten.count >= own.intersection(stated).count
        }
    }

    /// Stems of words that say nothing of a duty ("during", "ensuring").
    static let idleSummaryStems: Set<String> = ["durin", "ensur"]

    /// The words of the job descriptions of `cv`, in lower case, that are a word of an employer's name of `input`, or one of its
    /// forms, and that the description writes nowhere outside the employers' names.
    static func employerWords(in cv: CVData, for input: DraftingInput) -> [ReaderFinding] {
        let employers = input.facts.filter { $0.kind == .employer }.flatMap(\.forms)
        let names = Set(employers.flatMap(letterWords(of:)).filter { $0.count >= 4 })
        guard !names.isEmpty else { return [] }
        var rest = fold(input.description)
        for name in employers.sorted(by: { $0.count > $1.count }) {
            rest = rest.replacingOccurrences(of: fold(name), with: " ")
        }
        let outside = Set(rest.split { !$0.isLetter }.filter { $0.count >= 4 }.map { String($0.prefix(6)) })
        return cv.experience.enumerated().flatMap { index, job in
            (job.description ?? "").split { !$0.isLetter }.filter { $0.first?.isLowercase == true }.map { fold(String($0)) }
                .filter { word in
                    word.count >= 4 && names.contains { isFormOf(word, $0) } && !outside.contains(String(word.prefix(6)))
                }
                .map { ReaderFinding(kind: .employerWordInDuty, path: "experience[\(index)].description", value: $0) }
        }
    }

    /// Whether two folded words are one, or forms of one: of five letters or more, at most two letters apart in length, and
    /// alike but for their last two letters ("transporte", "transportes").
    static func isFormOf(_ first: String, _ second: String) -> Bool {
        guard first != second else { return true }
        let shorter = min(first.count, second.count)
        guard abs(first.count - second.count) <= 2, shorter >= 5 else { return false }
        return zip(first, second).prefix { $0 == $1 }.count >= max(5, shorter - 2)
    }

    /// Whether a duty holds a phrase that names no task but a field of tasks, in the six languages; the reader's own list.
    static func isVague(_ duty: String) -> Bool {
        let folded = fold(duty)
        return vaguePhrases.contains(where: folded.contains)
    }

    static let vaguePhrases = [
        "compiti legat", "compiti relativ", "attivita legat", "attivita relativ", "mansioni legat", "mansioni relativ",
        "tasks related to", "duties related to", "various tasks", "tareas relacionadas", "tareas vinculadas", "taches liees",
        "taches relatives", "aufgaben im bereich", "aufgaben rund um", "tarefas relacionadas", "atividades relacionadas",
    ]

    /// The frequency a folded word says, by the beginnings of its words in the six languages.
    static func frequency(of word: String) -> String? {
        frequencyWords.first { _, beginnings in beginnings.contains(where: word.hasPrefix) }?.key
    }

    static let frequencyWords: [String: [String]] = [
        "daily": ["daily", "quotidian", "quotidien", "giornalier", "giornalment", "diari", "taglich"],
        "weekly": ["weekly", "settimanal", "semanal", "hebdomadaire", "wochentlich"],
        "monthly": ["monthly", "mensil", "mensual", "mensal", "mensais", "mensuel", "monatlich"],
        "yearly": ["yearly", "annual", "annuel", "anual", "jahrlich"],
        "quarterly": ["quarterly", "trimestr", "quartalsweise", "vierteljahrlich"],
    ]

    /// The summary sentences that open with the verb of a sentence that opens as code writes the opening ("Lavoro come X."):
    /// the opening repeats the verb of the person's own sentence.
    static func floorCollisions(in sentences: [String]) -> [String] {
        let openings = sentences.filter { sentence in
            let words = letterWords(of: sentence)
            return workAs.values.flatMap { $0 }.contains { pair in
                words.starts(with: pair) || (pronouns.contains(words.first ?? "") && words.dropFirst().starts(with: pair))
                    || (words.first == "ho" && words.dropFirst().starts(with: pair))
                    || (words.starts(with: ["j", "ai"]) && words.dropFirst(2).starts(with: pair))
            }
        }
        let verb = { (sentence: String) in letterWords(of: sentence).first { !pronouns.contains($0) } }
        return sentences.filter { sentence in
            openings.contains { $0 != sentence && verb($0) == verb(sentence) }
        }
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
