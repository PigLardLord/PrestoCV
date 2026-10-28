import Foundation

/// The checks of a draft written a section at a time (ADR 0031, "A request per section"): each job's duties, the skills and the
/// summary, read sentence by sentence as the final check reads them, with the reason each dropped sentence goes. A repair request
/// reads the reasons; the final check (`sanitize(_:writing:against:)`) still reads all the text again.
extension CVDataSanitizer {
    // MARK: - The context of each job

    /// What the request of each job reads of the description: the clauses that belong to the job, and the clause in which the
    /// person says their field.
    struct DraftContext: Equatable, Sendable {
        struct Job: Equatable, Sendable {
            /// The job's index in the extracted draft's `experience`.
            let job: Int
            /// The clauses of the description that name the job, back it or join it.
            let clauses: [String]
        }

        /// One for one with the jobs that `sanitize(cvData, against: description)` keeps, in their order.
        let jobs: [Job]
        let field: String?
    }

    func draftContext(of cvData: CVData, against description: String) throws(CVGenerationError) -> DraftContext {
        try reading(description) { source in
            let entries = entries(of: cvData, source)
            let jobs = keptJobs(entries.jobs, source, entries).compactMap { kept -> DraftContext.Job? in
                guard let index = entries.jobs.firstIndex(where: { $0.subject == kept.job.subject }) else { return nil }
                return DraftContext.Job(job: index, clauses: entries.evidence(of: kept.job.subject).context)
            }
            return DraftContext(jobs: jobs, field: entries.fieldClause())
        }
    }

    /// The place the description names right after `company`, with the preposition of a place ("the Fenwick Playhouse in Norwich",
    /// "la Conserve Albarella di Termoli"), as the description writes it: its capitalised words, up to the first other word. Nil when
    /// no mention of the company is followed by one. A location filled from it is checked by the rules as any location.
    static func place(after company: String, in description: String) -> String? {
        guard let company = company.presentValue else { return nil }
        var searched = description.startIndex..<description.endIndex
        while let found = description.range(of: company, options: .caseInsensitive, range: searched) {
            if let place = place(at: found.upperBound, in: description) { return place }
            searched = found.upperBound..<description.endIndex
        }
        return nil
    }

    /// The prepositions that introduce the place of an employer, in the six languages.
    private static let placePrepositions: Set<String> = ["in", "di", "a", "à", "en", "em", "bei"]

    /// The place at `start` of `text`: spaces, an optional comma, at least one space, a preposition of a place, spaces, then
    /// capitalised words of two letters or more, joined by spaces.
    private static func place(at start: String.Index, in text: String) -> String? {
        var index = start
        func skipSpaces() -> Bool {
            let from = index
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            return index > from
        }
        func word() -> String {
            let from = index
            while index < text.endIndex, text[index].isLetter || "'’-".contains(text[index]) { index = text.index(after: index) }
            return String(text[from..<index])
        }
        var spaced = skipSpaces()
        if index < text.endIndex, text[index] == "," {
            index = text.index(after: index)
            spaced = skipSpaces()
        }
        guard spaced, placePrepositions.contains(word()), skipSpaces() else { return nil }
        var words: [String] = []
        while true {
            let restart = index
            let next = word()
            guard next.count >= 2, next.first?.isUppercase == true else { index = restart; break }
            words.append(next)
            let beforeSpaces = index
            guard skipSpaces() else { break }
            if index == text.endIndex { index = beforeSpaces; break }
        }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    // MARK: - The duties of a job

    /// A sentence the check drops, and why: the repair request reads both.
    struct Rejection: Equatable, Sendable {
        let sentence: String
        let reason: String
    }

    /// One job's written duties, as the final check reads them.
    struct DutyVerdicts: Equatable, Sendable {
        /// The duties the person said for the job, copied from its clauses, in its first person: they come first.
        var pinned: [String] = []
        /// The written duties that stay, each a sentence of its own.
        var kept: [String] = []
        var rejected: [Rejection] = []
        /// The words of the job's clauses that the check drops in a written duty: the request avoids them.
        var avoid: [String] = []

        /// The characters of the job's text once kept.
        var length: Int { (pinned + kept).joined(separator: " ").count }
    }

    /// The duties of the job at `index` of `cvData.experience`, sentence by sentence: a sentence that is no whole sentence, that the
    /// rules drop (`DutyRule`), that says again a duty of `earlier`, of the person's or of an earlier sentence, or that is written in
    /// another form than the job's first duty (`DutyForm`) goes with its reason. A duty said with a gerund is read, and kept, in the
    /// job's first person (`FirstPersonDuty`).
    func dutyCheck(
        of cvData: CVData, job index: Int, duties: String?, keeping earlier: [String] = [], against description: String
    ) throws(CVGenerationError) -> DutyVerdicts {
        try reading(description) { source in
            let entries = entries(of: cvData, source)
            guard entries.jobs.indices.contains(index) else { return DutyVerdicts() }
            let written = WrittenText(source: source, claimed: entries.claimed(in: source), wordList: wordList, tagger: lexicalClasses)
            let job = entries.jobs[index]
            let language = source.explainer.language
            let rule = DutyRule(job: job, among: entries.jobs, source: source, entries: entries, written: written)
            let quotes = rule.evidence.quotable.adding(rule.evidence.quotableByAchievements)
            let reason = { (sentence: String) -> String? in
                source.written(sentence, quoting: quotes, allowsNumbers: true) { _ in false } != nil ? nil : rule.rejection(of: sentence)
            }
            let current = job.entry.current && rule.evidence.statesCurrent
            var verdicts = DutyVerdicts()
            verdicts.pinned = entries.pinnedDuties(of: job.subject).flatMap { $0.kept { reason($0) == nil ? $0 : nil } }
                .map { FirstPersonDuty.written($0, current: current, language: language, wordList: wordList) }
            verdicts.avoid = rule.wordsToAvoid()

            var held = earlier + verdicts.pinned
            var form = held.first.flatMap { Self.form($0, language: language) }
            for raw in SentenceSplitter.sentences(in: duties ?? "") {
                let sentence = FirstPersonDuty.written(
                    raw.trimmingCharacters(in: .whitespacesAndNewlines), current: current, language: language, wordList: wordList
                )
                guard !sentence.isEmpty else { continue }
                let words = Self.letterWords(of: sentence)
                var rejection: String?
                if words.count < 3 || words.last.map(Self.dutyConjunctions.contains) == true {
                    rejection = "it is not a whole sentence"
                } else if let ruled = reason(sentence) {
                    rejection = ruled
                } else if held.contains(where: { Self.saysAgain(sentence, $0) }) {
                    rejection = "it repeats a duty already written"
                } else if let own = Self.form(sentence, language: language) {
                    if let form, form != own {
                        rejection = "it is written in another form: " + form.advice
                    } else if form == nil {
                        form = own
                    }
                }
                if let rejection {
                    verdicts.rejected.append(Rejection(sentence: sentence, reason: rejection))
                } else {
                    let capitalised = sentence.prefix(1).uppercased() + sentence.dropFirst()
                    verdicts.kept.append(capitalised)
                    held.append(capitalised)
                }
            }
            return verdicts
        }
    }

    /// The words that end a fragment of a duty ("Riparavo i motori e").
    static let dutyConjunctions: Set<String> = [
        "and", "e", "ed", "und", "et", "y", "or", "o", "oder", "ou", "ma", "but", "aber", "mais", "pero", "mas",
    ]

    /// Whether `sentence` says again what `earlier` says: the words of one, by their first four letters, are all words of the other,
    /// or it says it with another verb (`restates`).
    static func saysAgain(_ sentence: String, _ earlier: String) -> Bool {
        let own = stems(of: sentence)
        let other = stems(of: earlier)
        return !other.isEmpty && (own.isSubset(of: other) || other.isSubset(of: own) || restates(sentence, earlier))
    }

    /// Whether `sentence` says again what `earlier` says with another verb: at least two of the words of 4 or more letters after its
    /// verb, and two thirds of them, are words of `earlier` ("Verifying the electrical panels" after "Checking the electrical
    /// panels"). Words compare by their first four letters.
    static func restates(_ sentence: String, _ earlier: String) -> Bool {
        var own = letterWords(of: sentence)
        if let first = own.first, ["i", "ich", "je", "j"].contains(first) { own.removeFirst() }
        let tail = Set(own.dropFirst().filter { $0.count >= 4 }.map { String($0.prefix(4)) })
        let other = Set(letterWords(of: earlier).filter { $0.count >= 4 }.map { String($0.prefix(4)) })
        let shared = tail.intersection(other)
        return shared.count >= 2 && shared.count * 3 >= tail.count * 2
    }

    /// The form a duty starts with (ADR 0031): one job's text keeps one.
    enum DutyForm: Equatable, Sendable {
        /// "I plan the menus".
        case withI
        /// "Planning the menus".
        case ing
        /// "Plans the menus".
        case verb
        /// "Controllavo i quadri".
        case firstPerson
        /// "Controllando i quadri".
        case gerund
        /// "Controllare i quadri".
        case infinitive

        /// What the repair request reads when a duty is in another form than this, the job's.
        var advice: String {
            switch self {
            case .withI: "start it with \"I\" as the other duties"
            case .ing: "start it with a verb ending in -ing as the other duties"
            case .verb: "start it with a verb as the other duties"
            case .firstPerson: "start it with a verb in the first person, as the other duties"
            case .gerund: "start it with a gerund, as the other duties"
            case .infinitive: "start it with an infinitive, as the other duties"
            }
        }
    }

    /// The form of a duty: in English "I", a verb in -ing or another verb; in Italian, Spanish and Portuguese a gerund, an infinitive
    /// or (any other first word) a verb in the first person; none in German and French, whose duties start with their subject.
    static func form(_ sentence: String, language: Vocabulary.Language?) -> DutyForm? {
        guard let first = sentence.split(whereSeparator: { !$0.isLetter && $0 != "'" }).first.map(String.init) else { return nil }
        let word = first.lowercased()
        switch language {
        case .english:
            if first == "I" { return .withI }
            return first.count > 4 && word.hasSuffix("ing") ? .ing : .verb
        case .italian, .spanish, .portuguese:
            if word.count > 5, ["ando", "endo", "iendo", "indo"].contains(where: word.hasSuffix) { return .gerund }
            let infinitives = language == .italian ? ["are", "ere", "ire"] : ["ar", "er", "ir"]
            return word.count > 4 && infinitives.contains(where: word.hasSuffix) ? .infinitive : .firstPerson
        case .german, .french, nil:
            return nil
        }
    }

    /// The rule a job's duty passes (ADR 0031, D3 and D4): a sentence that quotes, with no number, a clause of this job alone is the
    /// person's own; any other states no fact (`WrittenText`), names no other job's title whole, and restates no sentence of the
    /// description about another employer.
    struct DutyRule {
        let evidence: EntryEvidence
        private let job: Entries.Job
        private let ownWords: Set<String>
        private let foreignWords: Set<String>
        private let otherTitles: [String]
        private let otherEmployers: [String]
        private let source: DescriptionText
        private let written: WrittenText

        init(job: Entries.Job, among jobs: [Entries.Job], source: DescriptionText, entries: Entries, written: WrittenText) {
            let title = entries.jobTitle(of: job)
            let otherJobs = jobs.filter { $0.subject != job.subject }
            self.job = job
            evidence = entries.evidence(of: job.subject)
            ownWords = CVDataSanitizer.words(of: [title])
            foreignWords = CVDataSanitizer.foreignWords(of: otherJobs.map(\.company), own: ownWords, language: source.explainer.language)
            otherTitles = CVDataSanitizer.otherTitles(otherJobs.map(\.title), own: title)
            otherEmployers = otherJobs.compactMap(\.company)
            self.source = source
            self.written = written
        }

        /// Why `sentence` goes from the job's text; nil when it stays.
        func rejection(of sentence: String) -> String? {
            if let attributed = evidence.quotableByAttribution,
               source.written(sentence, quoting: attributed, allowsNumbers: false, orPlain: { _ in false }) != nil {
                return nil
            }
            if let other = CVDataSanitizer.namedTitle(in: sentence, among: otherTitles) {
                return "the words \"\(other)\" are another job's title"
            }
            let allowing = CVDataSanitizer.quotedWords(of: sentence, quoting: evidence.ownClauseQuotes, source)
            if let reason = written.rejection(of: sentence, ownWords: ownWords, foreignWords: foreignWords, allowing: allowing) {
                return reason
            }
            if source.repeats(sentence, ofSentencesNaming: otherEmployers, notNaming: [job.company].compactMap { $0 }) {
                return "it says what the person did at another job"
            }
            return nil
        }

        /// The words of the job's clauses that the rule drops in a written duty, then the other jobs' employers and titles, each
        /// once whatever its case.
        func wordsToAvoid() -> [String] {
            let context = evidence.context.joined(separator: ". ")
            let words = written.wordsToAvoid(among: Word.words(in: context), in: context, ownWords: ownWords, foreignWords: foreignWords)
                + foreignWords.sorted() + otherTitles
            var seen = Set<String>()
            return words.filter { seen.insert($0.lowercased()).inserted }
        }
    }

    // MARK: - The summary

    /// The written summary, sentence by sentence, as the final check reads it: the sentences it keeps, those it drops with their
    /// reasons, and what the kept ones miss (2 to 4 sentences, 120 characters, a word of the person's titles).
    struct SummaryVerdict: Equatable, Sendable {
        var kept: [String] = []
        var rejected: [Rejection] = []
        var problems: [String] = []
        /// The sentence code writes in front of the kept ones from the facts ("Je travaille comme institutrice."), when they name
        /// no word of the person's titles or are too short.
        var opening: String?
        /// The problem the opening solves, which the repair then does not read.
        var openingProblem: String?

        var text: String? { kept.joined(separator: " ").presentValue }
    }

    /// The openings a summary sentence about the person in the third person starts with.
    static let thirdPersonOpeners: [String] = [
        "he ", "she ", "they ", "his ", "her ", "the person", "the candidate", "the professional", "this professional", "the individual",
        "lui ", "lei ", "egli ", "il candidato", "la candidata", "il professionista", "la professionista", "er ", "sie ", "die person",
        "der bewerber", "elle ", "il est", "le candidat", "la candidate", "le professionnel", "él ", "ella ", "el candidato",
        "el profesional", "ele ", "ela ", "o candidato", "o profissional", "a profissional",
    ]

    /// The summary of `cvData`, sentence by sentence: a sentence about the person in the third person goes, and so does one with no
    /// word of the person in a language that keeps its pronoun; so does a sentence that starts with the verb of an earlier one, one
    /// with no word beyond a sentence of the kept `duties` (one that joins several duties stays), a second one that names nothing of the `work` (the kept duties and tools) or
    /// of the titles, and one the rules drop (`WrittenText`). A summary that names no title whole gets an opening from the facts,
    /// and a kept sentence that starts with the opening's verb then goes. The `field` names the topic only when no title does, and
    /// only when it reads as a name.
    func summaryCheck(
        of cvData: CVData, summary: String?, field: String?, work: [String] = [], duties: [String] = [], against description: String
    ) throws(CVGenerationError) -> SummaryVerdict {
        try reading(description) { source in
            let facts = grounded(cvData, writing: nil, in: source)
            let entries = entries(of: cvData, source)
            let written = WrittenText(source: source, claimed: entries.claimed(in: source), wordList: wordList, tagger: lexicalClasses)
            let titles = [facts.personalInfo.title] + facts.experience.map(\.title)
            let ownWords = Self.words(of: titles + facts.education.map(\.degree))
            let cleanField = field.flatMap { field in
                field.split(separator: " ").count <= 4 && field.allSatisfy { $0.isLetter || $0 == " " || $0 == "-" } ? field : nil
            }
            let topicWords = ownWords.isEmpty ? Self.words(of: [cleanField]).filter { $0.count >= 4 } : ownWords
            let workStems = Self.workStems(of: work + titles.compactMap { $0 })
            let namesWork = { (sentence: String) in !Self.workStems(of: [sentence]).isDisjoint(with: workStems) }

            let language = source.explainer.language
            let dutySentences = duties.flatMap { SentenceSplitter.sentences(in: $0) }.map(Self.stems).filter { !$0.isEmpty }
            var verdict = SummaryVerdict()
            var idle = 0
            var seen = Set<String>()
            var verbs = Set<String>()
            for raw in SentenceSplitter.sentences(in: summary ?? "") {
                let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = sentence.lowercased().filter(\.isLetter)
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                let lower = sentence.lowercased()
                let verb = Self.leadingVerb(of: sentence)
                let own = Self.stems(of: sentence)
                if Self.thirdPersonOpeners.contains(where: lower.hasPrefix) {
                    verdict.rejected.append(Rejection(
                        sentence: sentence, reason: "it speaks of the person in the third person: write it as the person, with no subject"
                    ))
                } else if let language, let words = Self.firstPersonWords[language],
                          !Self.letterWords(of: sentence).contains(where: words.contains) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.saysNothingOfThePerson))
                } else if let verb, verbs.contains(verb) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.startsAsAnEarlierOne))
                } else if dutySentences.contains(where: own.isSubset) {
                    verdict.rejected.append(Rejection(
                        sentence: sentence, reason: "it says again a duty of a job: say what the person's work has in common"
                    ))
                } else if !workStems.isEmpty, !namesWork(sentence), idle >= 1 {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: "it says nothing of the work: name a duty or a tool of the lists"))
                } else if source.written(sentence, quoting: entries.summaryQuotes, allowsNumbers: false, orPlain: { _ in false }) == nil,
                          let reason = written.rejection(of: sentence, ownWords: ownWords) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: reason))
                } else {
                    if !namesWork(sentence) { idle += 1 }
                    if let verb { verbs.insert(verb) }
                    verdict.kept.append(sentence)
                }
            }

            let opening = Self.opening(of: facts, language: language)
            let textWords = Word.words(in: verdict.kept.joined(separator: " ")).map(\.folded)
            let titleRuns = titles.compactMap { $0?.presentValue }.map(EntryEvidence.foldedWords).filter { !$0.isEmpty }
            let namesATitle = titleRuns.contains { run in
                textWords.indices.contains { textWords[$0...].prefix(run.count).elementsEqual(run) }
            }
            if !topicWords.isEmpty, titleRuns.isEmpty ? Set(textWords).isDisjoint(with: topicWords) : !namesATitle {
                let named = titles.compactMap { $0?.presentValue }
                var seenNames = Set<String>()
                let listed = (named.isEmpty ? [cleanField].compactMap { $0?.presentValue } : named).filter { seenNames.insert($0.lowercased()).inserted }
                let problem = "it names none of the person's job titles whole"
                    + (listed.isEmpty ? "" : "; name one of: " + listed.joined(separator: ", "))
                verdict.problems.append(problem)
                if let opening {
                    verdict.opening = opening
                    verdict.openingProblem = problem
                }
            }
            if verdict.opening == nil, !verdict.kept.isEmpty, verdict.kept.count < 2 || verdict.kept.joined(separator: " ").count < 120 {
                verdict.opening = opening
            }
            if let verb = verdict.opening.flatMap(Self.leadingVerb) {
                verdict.rejected += verdict.kept.filter { Self.leadingVerb(of: $0) == verb }
                    .map { Rejection(sentence: $0, reason: Self.startsAsAnEarlierOne) }
                verdict.kept.removeAll { Self.leadingVerb(of: $0) == verb }
            }
            var sizes: [String] = []
            if verdict.kept.count < 2 { sizes.append("it keeps fewer than 2 sentences") }
            if verdict.kept.count > 4 { sizes.append("it has more than 4 sentences") }
            if verdict.kept.joined(separator: " ").count < 120 { sizes.append("it is shorter than 120 characters") }
            verdict.problems = sizes + verdict.problems
            return verdict
        }
    }

    static let saysNothingOfThePerson = "it says nothing of the person: write it as the person, with \"I\" and what the person does"
    static let startsAsAnEarlierOne = "it starts with the verb of an earlier sentence: say something else"

    /// The words of the person, in the languages whose sentences keep the subject pronoun: a summary sentence there with none of them
    /// ("Sound design is the core of every project") says nothing of the person (#354). Italian, Spanish and Portuguese drop it.
    private static let firstPersonWords: [Vocabulary.Language: Set<String>] = [
        .english: ["i", "my", "me", "myself"],
        .german: ["ich", "mich", "mir", "mein", "meine", "meinen", "meinem", "meiner", "meines"],
        .french: ["je", "j", "moi", "me", "m", "mon", "ma", "mes"],
    ]

    /// The first word of a sentence after a subject pronoun of the first person: its verb, in a summary written as the person.
    static func leadingVerb(of sentence: String) -> String? {
        letterWords(of: sentence).first { !["i", "ich", "je", "j", "io", "yo", "eu"].contains($0) }
    }

    /// The first four letters of each word of 4 letters or more of `texts`: how a summary sentence is matched to the work.
    private static func workStems(of texts: [String]) -> Set<String> {
        Set(texts.flatMap { letterWords(of: $0).filter { $0.count >= 4 }.map { String($0.prefix(4)) } })
    }

    /// The opening of a summary that names no title: the current job's title, else the person's own, in the present; else the title
    /// of the job that ended last, in the past. Nil when the facts hold no title or the language is none of the six.
    static func opening(of facts: CVData, language: Vocabulary.Language?) -> String? {
        let current = facts.experience.first { $0.current && $0.title.presentValue != nil }?.title.presentValue
            ?? facts.personalInfo.title?.presentValue
        let past = facts.experience.filter { $0.title.presentValue != nil }.max { ($0.endDate ?? "") < ($1.endDate ?? "") }?.title
        guard let language, let title = current ?? past?.presentValue else { return nil }
        let article = "aeiou".contains(title.lowercased().first ?? "x") ? "an" : "a"
        switch (language, current != nil) {
        case (.english, true): return "I work as \(article) \(title)."
        case (.english, false): return "I worked as \(article) \(title)."
        case (.italian, true): return "Lavoro come \(title)."
        case (.italian, false): return "Ho lavorato come \(title)."
        case (.german, true): return "Ich arbeite als \(title)."
        case (.german, false): return "Ich habe als \(title) gearbeitet."
        case (.french, true): return "Je travaille comme \(title)."
        case (.french, false): return "J'ai travaillé comme \(title)."
        case (.spanish, true): return "Trabajo como \(title)."
        case (.spanish, false): return "Trabajé como \(title)."
        case (.portuguese, true): return "Trabalho como \(title)."
        case (.portuguese, false): return "Trabalhei como \(title)."
        }
    }

    // MARK: - The skills

    /// The written skills, cleaned by code.
    struct SkillVerdict: Equatable, Sendable {
        var technologies: [String] = []
        var softSkills: [String] = []
        var dropped: [Rejection] = []
    }

    /// The written skills, cleaned by code: a quality or an activity listed as a technology ("precisione", "Planung") is a soft
    /// skill, and a tool named by an activity ("software di gestione fermi") goes; the singular and the plural of one skill count
    /// once, and of two tools of one kind, by their head noun ("studio monitors", "nearfield monitor"), the second goes; a fragment, a
    /// verb and a skill in another language go. A technology the verb it starts with leads ("usare i PLC") is
    /// cut to its object; a tool word ("software") never leads as a verb.
    func skillCheck(technologies: [String], softSkills: [String], against description: String) -> SkillVerdict {
        let language = DescriptionText(description, languageOfText: languageOfText).explainer.language?.rawValue
        let tagsVerbs = language.map { lexicalClasses.tagsLexicalClass(inLanguage: $0) } ?? false
        var verdict = SkillVerdict()
        var keys = Set<String>()
        let check = { (raw: String, cutsVerb: Bool) -> String? in
            let item = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            let words = item.split(separator: " ").map(String.init)
            guard let first = words.first?.lowercased(), words.count <= 4, !item.contains("."), !item.contains(":"),
                  let last = words.last, !Self.skillEndWords.contains(last.lowercased()) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "fragment"))
                return nil
            }
            let second = words.count > 1 ? words[1].lowercased() : nil
            let taggedVerb = tagsVerbs && language.flatMap { lexicalClasses.verbs(in: item, language: $0).first?.lowerBound } == 0
                && (second == nil || !first.hasSuffix("ing") && Self.skillLinkWords.contains(second ?? ""))
            let saidVerb = second != nil && Self.saysAfterSubject(first, in: description, language: language)
            let infinitive = words.count > 2 && Self.skillArticles.contains(second ?? "")
                && (Self.infinitiveEndings[language ?? ""] ?? []).contains(where: first.hasSuffix)
            var kept = item
            if !Self.toolWords.contains(first), taggedVerb || saidVerb || infinitive {
                let rest = words.dropFirst().drop { Self.skillLinkWords.contains($0.lowercased()) }
                guard cutsVerb, rest.contains(where: { $0.count >= 3 }) else {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "verb"))
                    return nil
                }
                kept = rest.joined(separator: " ")
                verdict.dropped.append(Rejection(sentence: raw, reason: "verb cut"))
            }
            if let language, language != "en" {
                let letters = words.filter { $0.count >= 3 && $0.allSatisfy(\.isLetter) && $0 != $0.uppercased() }.map { $0.lowercased() }
                if !letters.isEmpty, letters.allSatisfy({
                    wordList.knows($0, inLanguage: "en") == true && wordList.knows($0, inLanguage: language) == false
                }) {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "another language"))
                    return nil
                }
            }
            return kept
        }
        var heads = Set<String>()
        for raw in technologies {
            guard let item = check(raw, true), keys.insert(Self.skillKey(item)).inserted else { continue }
            let lower = item.lowercased()
            if !Self.softStems.contains(where: lower.contains) {
                if let head = Self.headKey(of: item, language: language), !heads.insert(head).inserted {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "same kind as an earlier tool"))
                } else {
                    verdict.technologies.append(item)
                }
            } else if Set(letterWordsKeepingCase(lower)).isDisjoint(with: Self.toolWords) {
                verdict.softSkills.append(item)
            } else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "activity"))
            }
        }
        for raw in softSkills {
            guard let item = check(raw, false), keys.insert(Self.skillKey(item)).inserted else { continue }
            verdict.softSkills.append(item)
        }
        return verdict
    }

    /// A skill the facts request quoted with its verb ("usare i PLC") as the object the verb names ("PLC"); any other as it is.
    func statedSkill(_ name: String, against description: String) -> String {
        let verdict = skillCheck(technologies: [name], softSkills: [], against: description)
        guard verdict.dropped.contains(where: { $0.reason == "verb cut" }) else { return name }
        return verdict.technologies.first ?? verdict.softSkills.first ?? name
    }

    private func letterWordsKeepingCase(_ text: String) -> [String] {
        text.split { !$0.isLetter }.map(String.init)
    }

    /// The key of a tool's head noun, the word that names its kind ("monitors" of "studio monitors", "pince" of "pince à dénuder"):
    /// the last word in English and German, the first in the other languages, past an elided article ("l'oscilloscope"); none when
    /// that word has fewer than 4 letters ("Logic Pro").
    private static func headKey(of item: String, language: String?) -> String? {
        let words = item.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 1 }
        guard let head = ["en", "de"].contains(language ?? "") ? words.last : words.first, head.count >= 4 else { return nil }
        return skillKey(head)
    }

    /// The key by which two skills are one: their words without a plural ending or a last vowel ("PLC" and "PLCs").
    private static func skillKey(_ item: String) -> String {
        item.lowercased().split { !$0.isLetter && !$0.isNumber }.map { word -> String in
            var word = String(word)
            if word.count > 3, word.hasSuffix("s") || word.count > 5 && word.hasSuffix("x") { word.removeLast() }
            if word.count > 4, let last = word.last, "aeiou".contains(last) { word.removeLast() }
            return word
        }.joined(separator: " ")
    }

    /// Whether the description writes `word` right after a first-person subject of its language ("I mix on digital consoles"): the
    /// Italian article "i" ("controllando i quadri") is no "I".
    static func saysAfterSubject(_ word: String, in description: String, language: String?) -> Bool {
        let words = letterWords(of: description)
        let subjects = firstPersonSubjects[language ?? ""] ?? []
        return zip(words, words.dropFirst()).contains { subjects.contains($0.0) && $0.1 == word.lowercased() }
    }

    static let firstPersonSubjects: [String: Set<String>] = [
        "en": ["i"], "de": ["ich"], "fr": ["je", "j"], "it": ["io"], "es": ["yo"], "pt": ["eu"],
    ]

    /// The beginnings of the names of qualities and activities: listed as a technology, they are soft skills.
    static let softStems = [
        "communicat", "comunica", "kommunika", "organi", "teamwork", "team work", "collabor", "zusammenarbeit", "lavoro di squadra",
        "trabajo en equipo", "travail d'équipe", "trabalho em equipe", "leadership", "problem solving", "problem-solving", "empat",
        "flexib", "flessib", "adaptab", "adattab", "pünktlich", "zuverläss", "affidab", "gestion du temps", "time management",
        "gestione del tempo", "listening", "ascolto", "escuta", "attention to detail", "attenzione ai dettagli", "calm", "pazien", "patien",
        "precision", "précision", "präzision", "precisión", "precisão", "responsab", "responsib", "verantwort", "coordina", "koordin",
        "planung", "pianifica", "planifica", "planeja", "gestion", "gestão", "management", "mediazione", "mediação",
    ]

    /// The words that name a kind of tool, not a tool.
    static let toolWords: Set<String> = [
        "software", "system", "systems", "tool", "tools", "sistema", "sistemi", "strumento", "strumenti", "programma", "programmi",
        "logiciel", "logiciels", "outil", "outils", "système", "systèmes", "herramienta", "herramientas", "sistemas", "ferramenta",
        "ferramentas", "werkzeug", "werkzeuge", "programm", "platform", "plattform", "piattaforma", "plataforma", "plateforme",
    ]

    /// The words a skill's object starts with after the verb it lost ("edit the sound effects", "usare i PLC").
    static let skillLinkWords: Set<String> = [
        "the", "a", "an", "on", "with", "in", "of", "to", "for", "il", "lo", "la", "i", "gli", "le", "l", "un", "una", "con", "su", "di",
        "dei", "delle", "degli", "del", "della", "les", "une", "des", "du", "de", "avec", "sur", "el", "los", "las", "o", "os", "as", "um",
        "uma", "com", "do", "da", "dos", "das", "die", "der", "den", "mit", "auf",
    ]

    static let skillArticles: Set<String> = [
        "the", "a", "an", "il", "lo", "la", "i", "gli", "le", "un", "una", "les", "une", "des", "el", "los", "las", "o", "os", "as", "um", "uma",
    ]

    static let infinitiveEndings: [String: [String]] = [
        "it": ["are", "ere", "ire"], "es": ["ar", "er", "ir"], "pt": ["ar", "er", "ir"], "fr": ["er", "ir", "re"],
    ]

    /// The words a fragment of a skill ends with ("manutenzione di").
    static let skillEndWords: Set<String> = dutyConjunctions.union([
        "of", "for", "with", "to", "in", "on", "the", "a", "di", "per", "con", "da", "il", "la", "von", "für", "mit", "der", "die", "das",
        "de", "pour", "avec", "le", "les", "para", "el", "com",
    ])

    // MARK: - Helpers

    /// `body` with the description read, and its language data required, as the final check reads it.
    private func reading<Result>(_ description: String, _ body: (DescriptionText) -> Result) throws(CVGenerationError) -> Result {
        let source = DescriptionText(description, languageOfText: languageOfText)
        try requireLanguageData(of: source)
        return LexicalClasses.$tagger.withValue(lexicalClasses) { body(source) }
    }

    /// The entries of `cvData` as the final check reads them.
    private func entries(of cvData: CVData, _ source: DescriptionText) -> Entries {
        Entries(cvData, personalInfo: sanitize(cvData.personalInfo, jobTitles: cvData.experience.map(\.title), source), source)
    }
}
