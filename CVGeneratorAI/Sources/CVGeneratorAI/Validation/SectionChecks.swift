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
        /// The sentences in which the person says what they do and what they are like at work, with no job: the skills requests
        /// read them (#354, round 1).
        var own: [String] = []
    }

    func draftContext(of cvData: CVData, against description: String) throws(CVGenerationError) -> DraftContext {
        try reading(description) { source in
            let entries = entries(of: cvData, source)
            let jobs = keptJobs(entries.jobs, source, entries).compactMap { kept -> DraftContext.Job? in
                guard let index = entries.jobs.firstIndex(where: { $0.subject == kept.job.subject }) else { return nil }
                return DraftContext.Job(job: index, clauses: entries.evidence(of: kept.job.subject).context)
            }
            return DraftContext(jobs: jobs, field: entries.fieldClause(), own: entries.ownSentences())
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

    /// The employer with the noun of its kind that the description writes right before it, after an article, a possessive or a
    /// preposition ("trabajé en la gestoría Aranda y Molina", "trabalhei na agência Pixel Gaúcho"): a word in lower case that no
    /// vocabulary explains. A clause backs a job only when each of its words is explained, and the words of the job's own employer
    /// explain themselves: without its noun the clause backs nothing, and the years it gives the job are lost (#354). `company`
    /// itself when no mention of it is written so, or when the language of the description is not known.
    static func employer(_ company: String, in description: String, language: Vocabulary.Language?) -> String {
        let name = Word.words(in: company).map(\.folded)
        let words = Word.words(in: description)
        guard let language, !name.isEmpty, words.count >= name.count + 2 else { return company }
        let characters = Array(Digits.ascii(description))
        for start in 2...(words.count - name.count) where (0..<name.count).allSatisfy({ words[start + $0].folded == name[$0] }) {
            let kind = words[start - 1]
            let sign = words[start - 2]
            guard !kind.isNumber, !kind.endsWithABreak, !sign.endsWithABreak, characters[kind.range.lowerBound].isLowercase,
                  !Vocabulary.explains(kind.folded, in: language), Voice.isNounSign(sign.accented, in: language) else { continue }
            return String(characters[kind.range.lowerBound..<words[start + name.count - 1].range.upperBound])
        }
        return company
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

        /// The characters of a job's text from which it is described: under them, it gets typical duties (ADR 0031, D6).
        static let describedLength = 40
        /// Why a typical duty goes from a job the person described.
        static let describedReason = "the person said what they did in this job: write only that"

        /// Whether the duties the person said for the job run to `describedLength`: it then keeps no typical duty (D6).
        var saysEnough: Bool { pinned.joined(separator: " ").count >= Self.describedLength }
    }

    /// The duties of the job at `index` of `cvData.experience`, sentence by sentence: a sentence that is no whole sentence, that the
    /// rules drop (`DutyRule`), that says again a duty of `earlier`, of the person's or of an earlier sentence, or that is written in
    /// another form than the job's first duty (`DutyForm`) goes with its reason, and so does any duty that quotes none of the job's
    /// own clauses when its stated duties run to 40 characters (D6). A duty said with a gerund is read, and kept, in the job's first
    /// person (`FirstPersonDuty`).
    func dutyCheck(
        of cvData: CVData, job index: Int, duties: String?, keeping earlier: [String] = [], against description: String
    ) throws(CVGenerationError) -> DutyVerdicts {
        try reading(description) { source in
            let entries = entries(of: cvData, source)
            guard entries.jobs.indices.contains(index) else { return DutyVerdicts() }
            let written = WrittenText(source: source, claimed: entries.claimed(in: source), wordList: wordList, tagger: lexicalClasses)
            let job = entries.jobs[index]
            let language = source.explainer.language
            let kept = keptJobs(entries.jobs, source, entries)
            let isGeneral = Self.generalDutyJob(among: kept.map(\.experience)).map { kept[$0].job.subject == job.subject } ?? false
            let rule = DutyRule(
                job: job, among: entries.jobs, source: source, entries: entries, written: written, takesGeneralDuties: isGeneral
            )
            let reason = { (sentence: String, quotes: ProseQuotes) -> String? in
                source.written(sentence, quoting: quotes, allowsNumbers: true) { _ in false } != nil ? nil : rule.rejection(of: sentence)
            }
            let current = job.entry.current && rule.evidence.statesCurrent
            var verdicts = DutyVerdicts()
            // The said duties are pinned with the job's own quotes, as the final check pins them: a clause that is one of the job's
            // achievements stays an achievement, so it counts toward none of the job's text (#354).
            let said = entries.pinnedDuties(of: job.subject) + (isGeneral ? entries.generalDuties() : [])
            verdicts.pinned = said.flatMap { $0.kept { reason($0, rule.evidence.quotable) == nil ? $0 : nil } }
                .map { FirstPersonDuty.written($0, current: current, language: language, wordList: wordList) }
            verdicts.avoid = rule.wordsToAvoid()

            var held = earlier + verdicts.pinned
            var form = held.first.flatMap { Self.form($0, language: language) }.flatMap { $0 == .infinitive ? nil : $0 }
            let quotes = rule.evidence.quotable.adding(rule.evidence.quotableByAchievements)
            for raw in SentenceSplitter.sentences(in: duties ?? "") {
                var sentence = FirstPersonDuty.written(
                    raw.trimmingCharacters(in: .whitespacesAndNewlines), current: current, language: language, wordList: wordList
                )
                guard !sentence.isEmpty else { continue }
                // A count the person gave in digits that the model wrote in words is the person's: a sentence that goes for it is
                // written as they wrote it, and stays (#354, round 6). Another count still goes.
                let counted = WrittenTextWords.inDigits(sentence, language: language)
                if counted != sentence, reason(sentence, quotes) != nil, reason(counted, quotes) == nil { sentence = counted }
                let words = Self.letterWords(of: sentence)
                var rejection: String?
                if words.count < 3 || words.last.map(Self.dutyConjunctions.contains) == true {
                    rejection = "it is not a whole sentence"
                } else if let ruled = reason(sentence, quotes) {
                    rejection = ruled
                } else if held.contains(where: { Self.saysAgain(sentence, $0) }) {
                    rejection = "it repeats a duty already written"
                } else if let own = Self.form(sentence, language: language) {
                    if let form, form != own {
                        rejection = "it is written in another form: " + form.advice
                    } else if own == .infinitive {
                        rejection = "it starts with an infinitive: start it with a verb in the first person"
                    } else if form == nil {
                        form = own
                    }
                }
                if rejection == nil, !current, Self.tense(of: sentence, language: language) == .present,
                   held.contains(where: { Self.tense(of: $0, language: language) == .past }) {
                    rejection = "it is in the present, and the job has ended: write it in the past, as the other duties"
                }
                if rejection == nil, verdicts.saysEnough, !rule.quotesOwnClauses(sentence) {
                    rejection = DutyVerdicts.describedReason
                }
                if rejection == nil, let opening = Self.opening(of: sentence), held.count { Self.opening(of: $0) == opening } >= 2 {
                    rejection = Self.opensAsTwoEarlierOnes
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

    static let opensAsTwoEarlierOnes = "it opens with the words of two earlier duties: start it with another verb"

    /// The first two words of a duty, folded, unless the second is an auxiliary ("J'ai formé…", "Ich habe…"), whose verb comes
    /// later: a job of three duties that open alike reads as a list, not as a person's work ("Je veillais à…", #354, round 2).
    static func opening(of duty: String) -> [String]? {
        let words = Word.words(in: duty).prefix(2).map(\.folded)
        guard words.count == 2, !auxiliaries.contains(words[1]) else { return nil }
        return words
    }

    /// The topics of `duties`, at most `limit`, that the summary request reads (#354, round 3): each clause with its subject, its
    /// auxiliary and its verb gone ("Je range les dossiers et j'accueille les clients." gives "les dossiers" and "les clients"), so
    /// that the summary says what the work is about without a duty to copy, which its check drops. A clause with a number goes:
    /// the summary states none.
    static func workTopics(of duties: String, limit: Int = 4) -> [String] {
        var topics: [String] = []
        var seen = Set<String>()
        for sentence in SentenceSplitter.sentences(in: duties) {
            let characters = Array(Digits.ascii(sentence))
            var pieces: [[Word]] = [[]]
            for word in Word.words(in: sentence) {
                if dutyConjunctions.contains(word.folded), !word.isHyphenated {
                    pieces.append([])
                    continue
                }
                pieces[pieces.count - 1].append(word)
                if word.endsWithABreak { pieces.append([]) }
            }
            for (index, piece) in pieces.enumerated() {
                guard let topic = topic(of: piece, opensTheSentence: index == 0), !topic.contains(where: \.isNumber),
                      let first = topic.first, let last = topic.last else { continue }
                let text = String(characters[first.range.lowerBound..<last.range.upperBound])
                if seen.insert(text.lowercased()).inserted { topics.append(text) }
            }
        }
        return Array(topics.prefix(limit))
    }

    /// What the work of a job's own lines is done on, which its tools request reads as no tool (#354, round 6): their topics,
    /// none that names a tool or its kind, holds an acronym or, but in German, whose nouns all take a capital, a name. Asked for
    /// the tools of all jobs at once, the request listed the panels and the belts the person repairs.
    static func workObjects(of lines: [String], capitalNouns: Bool) -> [String] {
        let clauses = lines.map { line -> String in
            // A job's line may open with the "where" that tied it to the employer ("dove coordino tre tecnici").
            guard let first = Word.words(in: line).first, relativeOpenings.contains(first.folded) else { return line }
            return String(Array(Digits.ascii(line))[first.range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return workTopics(of: clauses.joined(separator: " "), limit: 4).filter { topic in
            let named = topic.split { !$0.isLetter }.contains { word in
                word.filter(\.isUppercase).count > 1 || !capitalNouns && word.first?.isUppercase == true
            }
            return !named && !Word.words(in: topic).contains { toolKinds.contains($0.folded) }
        }
    }

    /// The words that tie a job's line to its employer, folded.
    private static let relativeOpenings: Set<String> = ["where", "dove", "wo", "ou", "donde", "onde"]

    /// The words of a clause of a duty after its subject, auxiliary and verb; a single word after a conjunction is a topic as it
    /// is ("le fatture e i preventivi"). The German perfect has its participle last ("Ich habe die Regale montiert").
    private static func topic(of piece: [Word], opensTheSentence: Bool) -> ArraySlice<Word>? {
        var words = piece[...]
        while let first = words.first, subjectWords.contains(first.folded) { words = words.dropFirst() }
        guard opensTheSentence || words.count > 1 else { return words.isEmpty ? nil : words }
        if let first = words.first, germanAuxiliaries.contains(first.folded) {
            words = words.dropFirst().dropLast()
        } else if let first = words.first, auxiliaries.contains(first.folded) {
            words = words.dropFirst(2)
        } else {
            words = words.dropFirst()
        }
        return words.isEmpty ? nil : words
    }

    /// The subject pronouns of the first person, and the reflexive ones before a verb, folded ("j" of "j'accueille").
    private static let subjectWords: Set<String> = ["i", "ich", "je", "j", "io", "yo", "eu", "mi", "me", "m", "mich", "se", "si"]

    /// The German auxiliaries of the perfect and the passive, folded: their participle ends the clause.
    private static let germanAuxiliaries: Set<String> = ["habe", "hat", "hatte", "bin", "wurde"]

    /// The auxiliaries a past or a perfect tense opens with after its subject, folded.
    private static let auxiliaries: Set<String> = [
        "have", "has", "had", "am", "was", "were", "habe", "hat", "hatte", "bin", "war", "wurde", "ai", "avais", "suis", "etais",
        "ho", "avevo", "sono", "ero", "he", "habia", "tengo", "tenho", "tinha",
    ]

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

    /// The tense of a duty said in the first person (#354): an ended job's duties keep the past they started in.
    enum DutyTense: Equatable, Sendable { case past, present }

    /// The tense of a duty by the ending of its first word, in Italian, Spanish and Portuguese, whose duties start with the verb in the
    /// first person ("Gestivo", "Coordiné", "Colaboro"); nil in the other languages, whose verbs do not tell it by their ending, and
    /// for a first word with no ending of a tense.
    static func tense(of sentence: String, language: Vocabulary.Language?) -> DutyTense? {
        // "Sono" starts the present ("Sono responsabile") and the past ("Sono stato responsabile") alike.
        guard let first = sentence.split(whereSeparator: { !$0.isLetter }).first.map({ $0.lowercased() }), first.count > 1,
              first != "sono" else { return nil }
        let (pastWords, past, present): (Set<String>, [String], [String]) = switch language {
        case .italian: (["ho", "ero"], ["avo", "evo", "ivo"], ["o"])
        case .spanish: (["he", "fui"], ["é", "í", "aba", "ía"], ["o"])
        case .portuguese: (["fui"], ["ei", "ava", "ia", "i"], ["o"])
        case .english, .german, .french, nil: ([], [], [])
        }
        if pastWords.contains(first) || past.contains(where: first.hasSuffix) { return .past }
        return present.contains(where: first.hasSuffix) ? .present : nil
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
        private let generalQuotes: ProseQuotes?

        /// `takesGeneralDuties` when the job is the current one, which takes the duties the person said with no job (ADR 0031, D7):
        /// a sentence that quotes them is then the person's own too.
        init(
            job: Entries.Job, among jobs: [Entries.Job], source: DescriptionText, entries: Entries, written: WrittenText,
            takesGeneralDuties: Bool
        ) {
            let title = entries.jobTitle(of: job)
            let otherJobs = jobs.filter { $0.subject != job.subject }
            self.job = job
            evidence = entries.evidence(of: job.subject)
            generalQuotes = takesGeneralDuties ? entries.generalDutyQuotes : nil
            ownWords = CVDataSanitizer.words(of: [title])
            foreignWords = CVDataSanitizer.foreignWords(of: otherJobs.map(\.company), own: ownWords, language: source.explainer.language)
            otherTitles = CVDataSanitizer.otherTitles(otherJobs.map(\.title), own: title)
            otherEmployers = otherJobs.compactMap(\.company)
            self.source = source
            self.written = written
        }

        /// Whether `sentence` quotes, with no number, the clauses of this job alone: then it is the person's own.
        func quotesOwnClauses(_ sentence: String) -> Bool {
            [evidence.quotableByAttribution, generalQuotes].compactMap { $0 }.contains { quotes in
                source.written(sentence, quoting: quotes, allowsNumbers: false, orPlain: { _ in false }) != nil
            }
        }

        /// Why `sentence` goes from the job's text; nil when it stays.
        func rejection(of sentence: String) -> String? {
            if quotesOwnClauses(sentence) { return nil }
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

    /// Whether `sentence`, in a language that drops the subject pronoun (Spanish, Italian, Portuguese), speaks of the person in the
    /// third person (#354): after one of the person's `titles`, with or without its article ("Contable gestiona los registros."),
    /// it starts with the reflexive pronoun of the third person ("Se encarga de…", "Si occupa di…"), or with a verb of the third
    /// person, read by its ending in an unstressed -a or -e and the article right after it ("Analiza los movimientos de caja.").
    /// A rough rule: a verb with no article after it is not read, nor is the imperfect, whose first and third person agree.
    static func speaksInTheThirdPerson(_ sentence: String, titles: [String], language: Vocabulary.Language?) -> Bool {
        guard let language, let articles = articlesAfterAVerb[language] else { return false }
        var words = Word.words(in: sentence).map(\.accented)
        let folded = Word.words(in: sentence).map(\.folded)
        let skip = words.first.map(articles.contains) == true ? 1 : 0
        if let title = titles.map(EntryEvidence.foldedWords).first(where: { !$0.isEmpty && folded.dropFirst(skip).starts(with: $0) }) {
            words.removeFirst(skip + title.count)
        }
        guard words.count >= 2 else { return false }
        let (verb, next) = (words[0], words[1])
        if verb == reflexivePronouns[language], next != "me", next != "mi" { return true }
        let imperfect = ["aba", "ía", "ava"].contains { verb.hasSuffix($0) }
        return verb.count >= 4 && (verb.hasSuffix("a") || verb.hasSuffix("e")) && articles.contains(next) && !imperfect
            && !(language == .italian && verb.hasSuffix("re")) && !notThirdPersonVerbs.contains(verb)
    }

    /// The articles and possessives that follow a verb before its object, in the languages that drop the subject pronoun.
    private static let articlesAfterAVerb: [Vocabulary.Language: Set<String>] = [
        .spanish: ["el", "la", "los", "las", "un", "una", "unos", "unas", "su", "sus"],
        .italian: ["il", "lo", "la", "i", "gli", "le", "l", "un", "uno", "una"],
        .portuguese: ["o", "a", "os", "as", "um", "uma", "uns", "umas", "seu", "sua", "seus", "suas"],
    ]

    /// The reflexive pronoun of the third person that starts a sentence ("Se encarga…"); Portuguese "se" starts a condition.
    private static let reflexivePronouns: [Vocabulary.Language: String] = [.spanish: "se", .italian: "si"]

    /// The words ending in -a or -e that an article can follow and that are no verb of the third person: prepositions, adverbs and
    /// determiners ("Para la empresa…", "Durante il giorno…"), and the irregular past of the first person ("Hice la contabilidad…").
    private static let notThirdPersonVerbs: Set<String> = [
        "para", "desde", "hasta", "entre", "sobre", "contra", "durante", "mediante", "siempre", "donde", "ante", "ahora", "nunca",
        "toda", "hice", "tuve", "estuve", "pude", "puse", "supe", "quise", "vine", "dije", "traje", "anduve", "conduje", "produje",
        "traduje", "come", "dove", "mentre", "oltre", "sopra", "insieme", "sempre", "ancora", "anche", "prima", "fuori", "tutta",
        "tutte", "circa", "tramite", "grazie", "perante", "onde", "ainda", "agora", "tive", "estive", "trouxe", "disse", "soube",
    ]

    /// The summary of `cvData`, sentence by sentence: a sentence about the person in the third person goes, and so does one with no
    /// word of the person in a language that keeps its pronoun, and one whose subject is a bare word of the person's work
    /// (`hasABareSubject`); so does a sentence that starts with the verb of an earlier one, one
    /// with no word beyond a sentence of the kept `duties` (one that joins several duties stays), a second one that names nothing of the `work` (the kept duties and tools) or
    /// of the titles, and one the rules drop (`WrittenText`). A summary that names no title whole gets an opening from the facts,
    /// and a kept sentence that starts with the opening's verb then goes. The `field` names the topic only when no title does, and
    /// only when it reads as a name.
    func summaryCheck(
        of cvData: CVData, summary: String?, field: String?, work: [String] = [], duties: [String] = [], against description: String
    ) throws(CVGenerationError) -> SummaryVerdict {
        try summaryCheck(of: cvData, summary: summary, field: field, work: work, duties: duties, qualities: [], against: description)
    }

    /// The summary check, where a sentence whose subject is one of the kept `qualities` also goes (`hasAQualitySubject`), and so
    /// does every sentence that ends with the last three words of an earlier one kept (#354, round 2).
    func summaryCheck(
        of cvData: CVData, summary: String?, field: String?, work: [String], duties: [String], qualities: [String],
        against description: String
    ) throws(CVGenerationError) -> SummaryVerdict {
        try summaryCheck(
            of: cvData, summary: summary, field: field, work: work, duties: duties, qualities: qualities, tools: [], against: description
        )
    }

    /// The summary check, where a sentence that lists three or more of the kept `tools` and `qualities` also goes (#354, round 3).
    func summaryCheck(
        of cvData: CVData, summary: String?, field: String?, work: [String], duties: [String], qualities: [String], tools: [String],
        against description: String
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
            let workWords = ownWords.union(Self.words(of: [cleanField])).filter { $0.count >= 4 }
            let workStems = Self.workStems(of: work + titles.compactMap { $0 })
            let namesWork = { (sentence: String) in !Self.workStems(of: [sentence]).isDisjoint(with: workStems) }

            let language = source.explainer.language
            let dutySentences = duties.flatMap { SentenceSplitter.sentences(in: $0) }.map(Self.stems).filter { !$0.isEmpty }
            var verdict = SummaryVerdict()
            var seen = Set<String>()
            var idleFirst: String?
            var verbs = Set<String>()
            var endings = Set<[String]>()
            let qualityWords = qualities.map { Word.words(in: $0).map(\.folded) }.filter { !$0.isEmpty }
            let skillWords = qualityWords + tools.map { Word.words(in: $0).map(\.folded) }.filter { !$0.isEmpty }
            for raw in SentenceSplitter.sentences(in: summary ?? "") {
                let sentence = writtenAsThePerson(raw.trimmingCharacters(in: .whitespacesAndNewlines), qualities: qualityWords, language: language)
                let key = sentence.lowercased().filter(\.isLetter)
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                let lower = sentence.lowercased()
                let verb = Self.leadingVerb(of: sentence)
                let own = Self.stems(of: sentence)
                if Self.thirdPersonOpeners.contains(where: lower.hasPrefix)
                    || Self.speaksInTheThirdPerson(sentence, titles: titles.compactMap { $0 }, language: language) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.speaksInTheThirdPerson))
                } else if let language, let words = Self.firstPersonWords[language],
                          !Self.letterWords(of: sentence).contains(where: words.contains) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.saysNothingOfThePerson))
                } else if let language, Self.hasABareSubject(sentence, workWords: workWords, language: language) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.hasABareSubject))
                } else if let language, Self.isAFragment(sentence, workWords: workWords, language: language) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.hasNoVerb))
                } else if let language, Self.dropsThePronoun.contains(language), !Self.speaksAsThePerson(sentence, language: language) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.hasNoVerbOfThePerson))
                } else if language == .german, Self.putsTheVerbBeforeTheEnd(sentence) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.putsTheVerbBeforeTheEnd))
                } else if Self.hasAQualitySubject(sentence, qualities: qualityWords) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.hasAQualitySubject))
                } else if Self.listsSkills(sentence, skills: skillWords) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.listsSkills))
                } else if let verb, verbs.contains(verb) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.startsAsAnEarlierOne))
                } else if let ending = Self.ending(of: sentence), endings.contains(ending) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.endsAsAnEarlierOne))
                } else if dutySentences.contains(where: own.isSubset) {
                    verdict.rejected.append(Rejection(
                        sentence: sentence, reason: "it says again a duty of a job: say what the person's work has in common"
                    ))
                } else if !work.isEmpty, !namesWork(sentence), !verdict.kept.isEmpty {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: Self.namesNoWork))
                } else if source.written(sentence, quoting: entries.summaryQuotes, allowsNumbers: false, orPlain: { _ in false }) == nil,
                          let reason = written.rejection(of: sentence, ownWords: ownWords) {
                    verdict.rejected.append(Rejection(sentence: sentence, reason: reason))
                } else {
                    if !work.isEmpty, verdict.kept.isEmpty, !namesWork(sentence) { idleFirst = sentence }
                    if let verb { verbs.insert(verb) }
                    if let ending = Self.ending(of: sentence) { endings.insert(ending) }
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
            if verdict.opening != nil, let idleFirst {
                verdict.kept.removeAll { $0 == idleFirst }
                verdict.rejected.append(Rejection(sentence: idleFirst, reason: Self.namesNoWork))
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

    /// The summary's opening for `cvData`, as `summaryCheck` writes it from the facts it keeps: the summary request writes what
    /// follows it (#354, round 3). Nil when the facts hold no title or the description's language is none of the six.
    func summaryOpening(of cvData: CVData, against description: String) throws(CVGenerationError) -> String? {
        try reading(description) { source in
            Self.opening(of: grounded(cvData, writing: nil, in: source), language: source.explainer.language)
        }
    }

    /// The summary with a floor written by code from the grounded `facts` (#354, round 6): a summary of fewer than 2 sentences or
    /// 120 characters, as the requests left it, else the person's own, gets the opening (`opening(of:language:)`) when it names no
    /// title, and a sentence of the earlier titles it does not name, the latest first, within `most` sentences. Every impersonal
    /// sentence of a summary and of its repair went, and the draft kept the person's own sentence alone. Nil when the summary needs
    /// no floor or the facts give it no sentence.
    func summaryFloor(of facts: CVData, summary: String?, most: Int, against description: String) throws(CVGenerationError) -> String? {
        try reading(description) { source in
            let sentences = SentenceSplitter.sentences(in: summary ?? facts.summary ?? "")
            guard sentences.count < 2 || sentences.joined(separator: " ").count < 120,
                  let language = source.explainer.language else { return nil }
            let text = Word.words(in: sentences.joined(separator: " ")).map(\.folded)
            let named = { (title: String) in
                let run = EntryEvidence.foldedWords(of: title)
                return !run.isEmpty && text.indices.contains { text[$0...].prefix(run.count).elementsEqual(run) }
            }
            var seen = Set<String>()
            let end = { (job: Experience) in job.current ? "~" : job.endDate ?? "" }
            let latest = facts.experience.enumerated()
                .sorted { (end($0.element), $1.offset) > (end($1.element), $0.offset) }
                .map(\.element.title)
            let titles = ([facts.personalInfo.title] + latest).compactMap { $0?.presentValue }
                .filter { seen.insert($0.lowercased()).inserted }
            let opening = titles.contains(where: named) ? nil : Self.opening(of: facts, language: language)
            let earlier = titles.filter { title in !named(title) && opening.map { !Self.endsWithTitle($0, title) } ?? true }
            let head = opening.map { [$0] } ?? []
            let tail = earlier.isEmpty ? [] : [Self.earlier(as: earlier, after: !(head + sentences).isEmpty, language: language)]
            let floor = Array((head + sentences + tail).prefix(most))
            return floor.count > sentences.count ? floor.joined(separator: " ") : nil
        }
    }

    /// Whether `sentence` ends with `title` and its full stop: the opening that names it.
    private static func endsWithTitle(_ sentence: String, _ title: String) -> Bool {
        sentence.lowercased().hasSuffix(" \(title.lowercased()).")
    }

    /// The sentence of the earlier titles of a summary's floor, after another sentence or alone: "Before that, I worked as a
    /// fitter and an electrician."
    static func earlier(as titles: [String], after: Bool, language: Vocabulary.Language) -> String {
        let ands: [Vocabulary.Language: String] = [.english: "and", .german: "und", .spanish: "y", .french: "et"]
        let and = ands[language] ?? "e"
        let named = language == .english ? titles.map { ("aeiou".contains($0.lowercased().first ?? "x") ? "an " : "a ") + $0 } : titles
        let list = named.count < 2 ? named.joined() : named.dropLast().joined(separator: ", ") + " \(and) " + (named.last ?? "")
        switch (language, after) {
        case (.english, true): return "Before that, I worked as \(list)."
        case (.english, false): return "I worked as \(list)."
        case (.italian, true): return "In passato ho lavorato come \(list)."
        case (.italian, false): return "Ho lavorato come \(list)."
        case (.german, true): return "Davor habe ich als \(list) gearbeitet."
        case (.german, false): return "Ich habe als \(list) gearbeitet."
        case (.french, true): return "Auparavant, j'ai travaillé comme \(list)."
        case (.french, false): return "J'ai travaillé comme \(list)."
        case (.spanish, true): return "Antes trabajé como \(list)."
        case (.spanish, false): return "Trabajé como \(list)."
        case (.portuguese, true): return "Antes trabalhei como \(list)."
        case (.portuguese, false): return "Trabalhei como \(list)."
        }
    }

    /// A summary sentence that shares no word with the titles, the kept descriptions and the tools: only the first of a summary
    /// with no opening may (#354, round 6), as the first sentence is the one a reader takes for the person's own introduction.
    static let namesNoWork = "it says nothing of the work: name a duty or a tool of the lists"
    static let speaksInTheThirdPerson = "it speaks of the person in the third person: write it as the person, with no subject"
    static let hasNoVerbOfThePerson = "it says nothing of the person: write it as the person, with the verb of the person first"
    static let saysNothingOfThePerson = "it says nothing of the person: write it as the person, with \"I\" and what the person does"
    static let startsAsAnEarlierOne = "it starts with the verb of an earlier sentence: say something else"
    static let hasABareSubject = "its subject is a bare word of the person's work: write it as the person, with what they do"
    static let hasAQualitySubject = "its subject is a quality: write it as the person, with what they do and how"
    static let hasNoVerb = "it has no verb: write it as the person, with what they do"
    static let putsTheVerbBeforeTheEnd = "the verb of a clause after dass, weil or ob comes last: write it at the end of that clause"

    /// Whether a German sentence has a clause after dass, weil, sodass or ob whose verb stands before its end: the clause ends on a
    /// noun while an earlier lowercase word of four letters or more ends as a verb ("dass alle Maschinen laufen ruhig durch genaue
    /// Pflege"). A clause with a comparison ("wie am ersten Tag", "als je") may end on a noun after its verb, and it stays.
    private static func putsTheVerbBeforeTheEnd(_ sentence: String) -> Bool {
        sentence.split { ",;.!?".contains($0) }.contains { clause in
            let words = clause.split { !$0.isLetter }.map(String.init)
            guard let start = words.firstIndex(where: { ["dass", "weil", "sodass", "ob"].contains($0.lowercased()) }) else { return false }
            let rest = words[(start + 1)...]
            guard rest.count >= 3, let last = rest.last, last.first?.isUppercase == true,
                  !rest.contains(where: { ["wie", "als"].contains($0) }) else { return false }
            return rest.dropLast().contains { $0.count >= 4 && $0.first?.isLowercase == true && ($0.hasSuffix("en") || $0.hasSuffix("t")) }
        }
    }
    static let listsSkills = "it lists skills: say how the person uses one or two of them in the work"
    static let endsAsAnEarlierOne = "it ends with the words of an earlier sentence: say something else"

    /// Whether `sentence` starts with the words of one of `qualities` (folded) in a clause of five words or more before its first
    /// comma: a quality spoken of as the subject ("Precisione e calma sono le mie doti."), a summary made of a list of qualities
    /// (#354, round 2). A quality before a comma ("Calma e attenta, seguo…") describes the person who speaks after it.
    static func hasAQualitySubject(_ sentence: String, qualities: [[String]]) -> Bool {
        let words = Word.words(in: sentence).map(\.folded)
        let clause = Word.words(in: String(sentence.prefix { $0 != "," }))
        guard clause.count >= 5, let first = words.first, !wordsOfThePerson.contains(first) else { return false }
        return qualities.contains { words.starts(with: $0) }
    }

    /// The last three words of `sentence`, folded, when it has five or more: two sentences that end alike repeat a phrase
    /// ("…con enfoque organizado.", #354, round 2).
    static func ending(of sentence: String) -> [String]? {
        let words = Word.words(in: sentence).map(\.folded)
        return words.count >= 5 ? Array(words.suffix(3)) : nil
    }

    /// Whether `sentence` starts with a word of the person's work (`workWords`, folded) with no article, and has a form of "to be"
    /// of `language` among its next three words with no word of the person before it: the work spoken of as a thing
    /// ("Manutenzione è la mia attività principale.", #354). The language that drops the pronoun has no other sign of it. After an
    /// article, the work or a word of it is the subject with any verb ("Il lavoro richiede…", round 3).
    static func hasABareSubject(_ sentence: String, workWords: Set<String>, language: Vocabulary.Language) -> Bool {
        let words = Word.words(in: sentence)
        if let first = words.first, subjectArticles[language]?.contains(first.folded) == true, words.count > 2 {
            // "La manutenzione è…", "O trabalho exige…": the work after its article, and no word of the person right after it.
            return (workWords.contains(words[1].folded) || workNouns.contains(words[1].folded))
                && !words[2...].prefix(2).contains { isOfThePerson($0, in: language) }
        }
        guard let first = words.first, workWords.contains(first.folded), let be = toBe[language],
              let verb = words.dropFirst().prefix(3).firstIndex(where: { be.contains($0.accented) }) else { return false }
        return !words[..<verb].contains { isOfThePerson($0, in: language) }
    }

    /// Whether `word` is a word of the person in `language`: the Italian "i" is an article and "ma" a "but" ("con occhio per i
    /// dettagli", #354, round 3), not the English "I" or the French "ma".
    private static func isOfThePerson(_ word: Word, in language: Vocabulary.Language) -> Bool {
        wordsOfThePerson.contains(word.folded) && !(notOfThePerson[language]?.contains(word.folded) ?? false)
    }

    /// The words of the person in another language that a language uses for something else, folded.
    private static let notOfThePerson: [Vocabulary.Language: Set<String>] = [.italian: ["i", "ma"]]

    /// Whether `sentence` is a bare word of the person's work (`workWords`, folded) and the language's "with", with no comma, no
    /// form of "to be" and no word of the person: a title with its qualities and no verb ("Fornaio con mani svelte e pazienza.",
    /// #354, round 3). A comma may open the person's own clause ("Fornaio con calma, impasto…").
    static func isAFragment(_ sentence: String, workWords: Set<String>, language: Vocabulary.Language) -> Bool {
        let words = Word.words(in: sentence)
        guard words.count > 2, workWords.contains(words[0].folded), withWords[language]?.contains(words[1].folded) == true,
              !words.contains(where: \.endsWithABreak) else { return false }
        let be = toBe[language] ?? []
        return !words.contains { be.contains($0.accented) || isOfThePerson($0, in: language) }
    }

    /// The word for "with" that joins a title to its qualities, per language.
    private static let withWords: [Vocabulary.Language: Set<String>] = [
        .english: ["with"], .italian: ["con"], .german: ["mit"], .spanish: ["con"], .french: ["avec"], .portuguese: ["com"],
    ]

    /// Whether `sentence` holds three or more of `skills` (each its words, folded) whole: a list of the draft's skills, not the
    /// person's work (#354, round 3). Two named inside the work ("…con la pala e il forno…") stay.
    static func listsSkills(_ sentence: String, skills: [[String]]) -> Bool {
        let words = Word.words(in: sentence).map(\.folded)
        let held = Set(skills.filter { run in words.indices.contains { words[$0...].starts(with: run) } })
        return held.count >= 3
    }

    /// The articles and demonstratives that open a subject, folded, per language ("l" of "l'attività"; the English "I" is none).
    private static let subjectArticles: [Vocabulary.Language: Set<String>] = [
        .english: ["the", "this"], .italian: ["il", "lo", "la", "l", "i", "gli", "le", "questo", "questa"], .german: ["der", "die", "das"],
        .spanish: ["el", "la", "los", "las", "este", "esta"], .portuguese: ["o", "a", "os", "as", "este", "esta"],
        .french: ["le", "la", "l", "les", "ce", "cette"],
    ]

    /// The words for work itself, folded, which after an article are the work as a subject ("Il lavoro", "O trabalho").
    private static let workNouns: Set<String> = ["work", "job", "lavoro", "arbeit", "travail", "trabajo", "trabalho"]

    /// The forms of "to be" of the third person, accented: the Italian "è" is a verb, "e" is "and".
    private static let toBe: [Vocabulary.Language: Set<String>] = [
        .english: ["is", "are", "was", "were"],
        .italian: ["è", "sono", "era", "erano", "fu"],
        .german: ["ist", "sind", "war", "waren"],
        .spanish: ["es", "son", "era", "eran", "fue"],
        .french: ["est", "sont", "était", "étaient", "fut"],
        .portuguese: ["é", "são", "era", "eram", "foi"],
    ]

    /// The words of the person in the six languages, folded: a subject that has one ("my work is") is the person's.
    private static let wordsOfThePerson: Set<String> = [
        "i", "my", "me", "io", "mio", "mia", "miei", "mie", "mi", "ich", "mein", "meine", "mich", "mir", "je", "j", "mon", "ma",
        "mes", "moi", "yo", "mis", "eu", "meu", "minha", "meus", "minhas",
    ]

    /// The words of the person, in the languages whose sentences keep the subject pronoun: a summary sentence there with none of them
    /// ("Sound design is the core of every project") says nothing of the person (#354). Italian, Spanish and Portuguese drop it.
    private static let firstPersonWords: [Vocabulary.Language: Set<String>] = [
        .english: ["i", "my", "me", "myself"],
        .german: ["ich", "mich", "mir", "mein", "meine", "meinen", "meinem", "meiner", "meines"],
        .french: ["je", "j", "moi", "me", "m", "mon", "ma", "mes"],
    ]

    /// The languages whose sentences drop the subject pronoun: the person speaks there by the verb.
    private static let dropsThePronoun: Set<Vocabulary.Language> = [.italian, .spanish, .portuguese]

    /// The words of the person and the auxiliaries of the first person in Italian, Spanish and Portuguese, folded as `letterWords`
    /// writes them.
    private static let wordsOfTheSpeaker: Set<String> = [
        "io", "mi", "me", "mio", "mia", "miei", "mie", "ho", "sono", "sto", "posso", "yo", "mis", "conmigo", "he", "soy", "estoy",
        "tengo", "puedo", "eu", "meu", "minha", "meus", "minhas", "comigo", "sou", "estou", "tenho",
    ]

    /// The words in "-o" that open a clause and are no verb of the person: articles, determiners, prepositions, adverbs.
    private static let openersInO: Set<String> = [
        "uno", "ogni", "questo", "quello", "nello", "dello", "allo", "dallo", "sullo", "como", "todo", "cada", "este", "ese", "aquello",
        "esto", "eso", "durante", "dentro", "fuera", "nuestro", "vuestro", "nosso", "nao", "não", "cuando", "quando", "tanto", "molto",
        "ciascuno", "isso", "isto", "aquilo", "ovunque", "solo", "o", "lo", "no", "do", "ao", "pelo", "neo", "dopo", "presso",
    ]

    /// The words that join a clause to the one before it, and come before its verb.
    private static let clauseConnectors: Set<String> = [
        "poi", "inoltre", "anche", "e", "quindi", "dopo", "luego", "también", "y", "después", "depois", "além", "ma", "pero", "mas",
    ]

    /// Whether an Italian, Spanish or Portuguese summary sentence speaks as the person (#354, round 5): it holds a word of the
    /// person or an auxiliary of the first person ("mi", "tengo", "sou"), or its first word, or the first word after a comma, is a
    /// verb of the first person, in "-o" ("Controllo …", "Con cura, verifico …") or in the past of the first person in Spanish and
    /// Portuguese ("Revisé …", "Organizei …"). A past participle (`isParticiple`) is no verb of the person (#354, round 6):
    /// "Mantenido un control riguroso …" speaks as no one, nor does a gerund (`isGerund`): "…, garantendo conti in ordine". A rough
    /// rule: "Con cura verifico" is not read.
    private static func speaksAsThePerson(_ sentence: String, language: Vocabulary.Language) -> Bool {
        if letterWords(of: sentence).contains(where: wordsOfTheSpeaker.contains) { return true }
        let firsts = sentence.split(separator: ",").compactMap { letterWords(of: String($0)).first { !clauseConnectors.contains($0) } }
        return firsts.contains { word in
            word.count >= 3 && !openersInO.contains(word) && !isParticiple(word, language: language) && !isGerund(word, language: language)
                && (word.hasSuffix("o") || word.count >= 5 && (word.hasSuffix("é") || word.hasSuffix("ei")))
        }
    }

    /// Whether a folded word of six letters or more ends as a past participle, "-ato", "-ito" or "-uto" in Italian and "-ado" or
    /// "-ido" in Spanish and Portuguese, and is no first person of the same ending that a summary writes ("valuto", "decido"). A
    /// rough rule: a first person missing from the list reads as a participle, and its sentence goes.
    private static func isParticiple(_ word: String, language: Vocabulary.Language) -> Bool {
        guard word.count >= 6, let endings = participleEndings[language], endings.contains(where: word.hasSuffix) else { return false }
        return !(firstPersonsAsParticiples[language] ?? []).contains(word)
    }

    /// Whether a folded word of six letters or more ends as a gerund, "-ando" or "-endo", and "-indo" in Portuguese, and is no first
    /// person of the same ending that a summary writes ("comprendo", "atiendo"; #354, round 6). A rough rule: a first person missing
    /// from the list reads as a gerund.
    private static func isGerund(_ word: String, language: Vocabulary.Language) -> Bool {
        guard word.count >= 6, let endings = gerundEndings[language], endings.contains(where: word.hasSuffix) else { return false }
        return !(firstPersonsAsGerunds[language] ?? []).contains(word)
    }

    /// The endings of the gerund of the languages that drop the pronoun.
    private static let gerundEndings: [Vocabulary.Language: [String]] = [
        .italian: ["ando", "endo"], .spanish: ["ando", "endo"], .portuguese: ["ando", "endo", "indo"],
    ]

    /// The first persons of the present that end as a gerund, folded as `letterWords` writes them.
    private static let firstPersonsAsGerunds: [Vocabulary.Language: Set<String>] = [
        .italian: [
            "mando", "comando", "domando", "raccomando", "rimando", "prendo", "comprendo", "apprendo", "riprendo", "sorprendo",
            "intraprendo", "vendo", "rendo", "difendo", "attendo", "intendo", "pretendo", "estendo", "tendo", "stendo", "spendo",
            "dipendo", "sospendo", "accendo", "scendo", "ascendo", "espando", "contendo", "offendo",
        ],
        .spanish: [
            "mando", "comando", "demando", "ando", "atiendo", "entiendo", "extiendo", "defiendo", "enciendo", "desciendo", "asciendo",
            "tiendo", "pretendo", "vendo", "comprendo", "aprendo", "emprendo", "sorprendo", "dependo", "suspendo", "ofendo",
            "enmiendo", "recomiendo", "expando",
        ],
        .portuguese: [
            "mando", "comando", "demando", "ando", "recomendo", "vendo", "entendo", "atendo", "defendo", "estendo", "aprendo",
            "compreendo", "empreendo", "prendo", "surpreendo", "dependo", "suspendo", "acendo", "pretendo", "brindo", "expando",
        ],
    ]

    /// The endings of the past participle of the languages that drop the pronoun.
    private static let participleEndings: [Vocabulary.Language: [String]] = [
        .italian: ["ato", "ito", "uto"], .spanish: ["ado", "ido"], .portuguese: ["ado", "ido"],
    ]

    /// The first persons of the present that end as a past participle, folded as `letterWords` writes them.
    private static let firstPersonsAsParticiples: [Vocabulary.Language: Set<String>] = [
        .italian: [
            "valuto", "saluto", "rifiuto", "discuto", "disputo", "computo", "recluto", "visito", "medito", "facilito", "sollecito",
            "esercito", "accredito", "deposito", "abilito", "riabilito", "delimito", "limito", "invito", "recito", "agito", "ospito",
        ],
        .spanish: [
            "decido", "divido", "subdivido", "valido", "convalido", "consolido", "liquido", "presido", "resido", "coincido", "impido",
            "despido", "expido", "traslado", "persuado", "disuado", "agrado", "degrado", "olvido", "invado", "evado",
        ],
        .portuguese: [
            "decido", "divido", "subdivido", "valido", "consolido", "liquido", "presido", "resido", "coincido", "duvido", "convido",
            "agrido", "agrado", "degrado", "persuado", "dissuado",
        ],
    ]

    /// `sentence` as the person says it, in Italian, Spanish or Portuguese (#354, round 5): a sentence that opens with a verb of the
    /// third person (`speaksInTheThirdPerson`), alone or after a lone word of the kept `qualities` ("Precisa gestisce la contabilità"),
    /// opens with its first person in "-o" when the word list knows that form ("Gestisco la contabilità"). Any other sentence, one
    /// with a title or a noun as its subject, and one whose first person the list does not know keep their words.
    private func writtenAsThePerson(_ sentence: String, qualities: [[String]], language: Vocabulary.Language?) -> String {
        guard let language, Self.dropsThePronoun.contains(language) else { return sentence }
        var tokens = sentence.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if tokens.count > 2, let first = Word.words(in: tokens[0]).map(\.folded).first, qualities.contains([first]) {
            tokens.removeFirst()
        }
        let candidate = tokens.joined(separator: " ")
        guard let verb = tokens.first, verb.allSatisfy(\.isLetter), verb.count >= 4, verb.hasSuffix("a") || verb.hasSuffix("e"),
              Self.speaksInTheThirdPerson(candidate, titles: [], language: language) else { return sentence }
        let form = String(verb.dropLast()) + "o"
        guard wordList.knows(form.lowercased(), inLanguage: language.rawValue) == true else { return sentence }
        return ([String(form.prefix(1)).uppercased() + form.dropFirst()] + tokens.dropFirst()).joined(separator: " ")
    }

    /// The first word of a sentence after a subject pronoun of the first person: its verb, in a summary written as the person.
    static func leadingVerb(of sentence: String) -> String? {
        letterWords(of: sentence).first { !["i", "ich", "je", "j", "io", "yo", "eu"].contains($0) }
    }

    /// The first five letters of each word of five letters or more of `texts` that says nothing of a work: how a summary sentence
    /// is matched to the work. Matched by four letters, "with" and "each" tied a sentence of qualities to any duty (#354, round 6).
    private static func workStems(of texts: [String]) -> Set<String> {
        Set(texts.flatMap { letterWords(of: $0).filter { $0.count >= 5 && !idleWords.contains($0) }.map { String($0.prefix(5)) } })
            .subtracting(idleStems)
    }

    /// The words of five letters or more that say nothing of a work, in the six languages: quantifiers, connectives, auxiliaries.
    private static let idleWords: Set<String> = [
        "every", "their", "there", "which", "while", "where", "these", "those", "about", "after", "before", "other", "always",
        "being", "ensure", "ensures", "through", "della", "delle", "degli", "dello", "nella", "nelle", "negli", "sulla", "sulle",
        "sempre", "molto", "grande", "grandi", "mentre", "quando", "stato", "stata", "essere", "avere", "tutti", "tutte", "tutto",
        "costante", "constant", "consistent", "chaque", "leurs", "toute", "toutes", "faire", "avoir", "toujours", "einer", "einem",
        "einen", "eines", "jeden", "jedes", "jeder", "immer", "durch", "nicht", "sowie", "wobei", "damit", "dabei", "indem",
        "siempre", "entre", "sobre", "desde", "hasta", "mediante", "todos", "todas", "muito",
    ]

    /// The stems of the words for work of any trade ("lavoro", "tâche", "Aufgabe", "process"): a sentence that shares only one of
    /// them with the work names none of it.
    private static let idleStems: Set<String> = [
        "lavor", "attiv", "compi", "traba", "tarea", "taref", "trava", "tâche", "arbei", "aufga", "eleme", "proce", "activ",
        "tasks", "teams", "works",
    ]

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
    /// skill, and a tool named by an activity ("software di gestione fermi") goes; so does a technology that names an activity
    /// (`namesAnActivity`); the singular and the plural of one skill count
    /// once, and of two tools of one kind, by their head noun ("studio monitors", "nearfield monitor"), the second goes; a fragment, a
    /// verb, a skill in another language and a soft skill that names a tool go, and so does stationery, furniture or protective wear
    /// (`namesAnEverydayObject`); so does a technology that is a bare kind of tool
    /// ("software"; `namesAKindOfTool`), while a kind with a word of its trade ("software di rilievo") stays (#354, round 4). A technology the verb it starts with leads ("usare i PLC") is
    /// cut to its object; a tool word ("software") never leads as a verb. A lone English quality in -ed ("organized") is an adjective,
    /// and a soft skill the description writes only as a name goes (`namesAName`).
    func skillCheck(technologies: [String], softSkills: [String], against description: String) -> SkillVerdict {
        skillCheck(technologies: technologies, softSkills: softSkills, stated: [], against: description)
    }

    /// The written skills, cleaned by code, against the tools the person names (`stated`): of a written technology of the kind of
    /// one of them, by its head noun, the written one goes (#354, round 2).
    func skillCheck(technologies: [String], softSkills: [String], stated: [String], against description: String) -> SkillVerdict {
        let language = DescriptionText(description, languageOfText: languageOfText).explainer.language?.rawValue
        let tagsVerbs = language.map { lexicalClasses.tagsLexicalClass(inLanguage: $0) } ?? false
        var verdict = SkillVerdict()
        var keys = Set<String>()
        let check = { (raw: String, cutsVerb: Bool) -> String? in
            let item = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            let words = item.split(separator: " ").map(String.init)
            guard let first = words.first?.lowercased(), !Self.isTooLong(words), !item.contains("."), !item.contains(":"),
                  let last = words.last, !Self.skillEndWords.contains(last.lowercased()) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "fragment"))
                return nil
            }
            let second = words.count > 1 ? words[1].lowercased() : nil
            // A lone English quality in -ed is an adjective the tagger reads as a past verb ("organized"; #354, round 2).
            let adjective = !cutsVerb && second == nil && language == "en" && first.hasSuffix("ed")
            let taggedVerb = tagsVerbs && !adjective
                && language.flatMap { lexicalClasses.verbs(in: item, language: $0).first?.lowerBound } == 0
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
            if let language, let loanwords = Self.loanwords[language], words.contains(where: { word in
                word.count >= 4 && word.first?.isLowercase == true && word.allSatisfy(\.isLetter)
                    && !Self.vowels.contains(word.last?.lowercased() ?? "") && !loanwords.contains(word)
                    && wordList.knows(word, inLanguage: "en") == true
            }) {
                verdict.dropped.append(Rejection(sentence: raw, reason: "another language"))
                return nil
            }
            guard !Self.skillWords.contains(DescriptionText.normalized(kept)) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "a word for a skill"))
                return nil
            }
            return kept
        }
        var heads = Set(stated.compactMap { Self.headKey(of: $0, language: language) })
        for raw in Self.joiningClippedModifiers(technologies, in: description, language: language) {
            guard let item = check(raw, true), keys.insert(Self.skillKey(item)).inserted else { continue }
            let lower = item.lowercased()
            let soft = Self.softStems.contains(where: lower.contains)
            let namesATool = !Set(letterWordsKeepingCase(lower)).isDisjoint(with: Self.toolWords) || Self.namesATool(item, language: language)
            if soft, namesATool, !Self.hasAWordOfItsTrade(item) {
                // A kind of tool named by a quality alone is no tool of a trade ("Präzisionswerkzeug").
                verdict.dropped.append(Rejection(sentence: raw, reason: "a kind of tool, not its name"))
            } else if !soft || namesATool {
                // A tool named by the quality it serves and a word of its trade is a tool ("logiciel de gestion de classe"; #354, round 5).
                if Self.namesAnActivity(item, language: language) {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "activity"))
                } else if Self.namesAPart(item, language: language) {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "a part or a material, not a tool"))
                } else if Self.namesAnEverydayObject(item) || Self.namesStationery(item, language: language) {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "an everyday object, not a tool of the trade"))
                } else if Self.namesABareKind(item, language: language) {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "a kind of tool, not its name"))
                } else if let head = Self.headKey(of: item, language: language), !heads.insert(head).inserted {
                    verdict.dropped.append(Rejection(sentence: raw, reason: "same kind as an earlier tool"))
                } else {
                    verdict.technologies.append(item)
                }
            } else {
                verdict.softSkills.append(item)
            }
        }
        for raw in softSkills {
            guard let item = check(raw, false), keys.insert(Self.skillKey(item)).inserted else { continue }
            guard !Self.emptyQualities.contains(DescriptionText.normalized(item)) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "an empty word, not a quality"))
                continue
            }
            guard !Self.namesATool(item, language: language) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "a tool"))
                continue
            }
            guard !Self.namesAName(item, in: description) else {
                verdict.dropped.append(Rejection(sentence: raw, reason: "a name"))
                continue
            }
            verdict.softSkills.append(item)
        }
        let qualities = Self.oneOfEachQuality(verdict.softSkills)
        verdict.softSkills = qualities.kept
        verdict.dropped += qualities.dropped
        return verdict
    }

    /// The words that name a skill or a knowledge and no skill ("compétence", "skills", "Wissen"), without accents: alone, they are
    /// no quality (#354).
    static let skillWords: Set<String> = [
        "skill", "skills", "ability", "abilities", "competence", "competences", "competencies", "competenza", "competenze", "abilita",
        "capacita", "kompetenz", "kompetenzen", "fahigkeit", "fahigkeiten", "competencia", "competencias", "habilidad",
        "habilidades", "capacidad", "capacidades", "capacite", "capacites", "aptitude", "aptitudes", "habilidade", "capacidade",
        "soft skill", "soft skills", "qualita", "qualities", "quality",
        "knowledge", "understanding", "expertise", "wissen", "verstandnis", "kenntnis", "kenntnisse", "fachwissen", "conoscenza",
        "conoscenze", "comprensione", "conocimiento", "conocimientos", "comprension", "connaissance", "connaissances",
        "comprehension", "conhecimento", "conhecimentos", "compreensao",
    ]

    /// Whether a technology's head noun is a part or a material a person installs or lays, by its key: a cable, a switch or a pipe
    /// is what the work is done on, not a tool of it ("Leitungen", "Schalter"; #354, round 3). A tool named after one stays
    /// ("Kabelschere", "cable tester": its head is the tool).
    static func namesAPart(_ item: String, language: String?) -> Bool {
        let words = item.lowercased().split { !$0.isLetter }.map(String.init)
        guard let head = ["en", "de"].contains(language ?? "") ? words.last : words.first else { return false }
        return partKeys.contains(skillKey(head))
    }

    /// The keys (`skillKey`) of the parts and materials of the trades that install them, singular and plural, in each language.
    private static let partKeys: Set<String> = Set([
        "cable", "cables", "wire", "wires", "wiring", "outlet", "outlets", "fuse", "fuses",
        "pipe", "pipes", "screw", "screws", "bolt", "bolts", "nail", "nails",
        "kabel", "leitung", "leitungen", "schalter", "steckdose", "steckdosen", "sicherung", "sicherungen", "rohr", "rohre",
        "schraube", "schrauben", "dübel", "stecker",
        "cavo", "cavi", "interruttore", "interruttori", "presa", "prese", "fusibile", "fusibili", "tubo", "tubi", "vite", "viti",
        "tubatura", "tubature",
        "cableado", "interruptor", "interruptores", "enchufe", "enchufes", "fusible", "fusibles", "tubería", "tuberías",
        "tornillo", "tornillos",
        "câble", "câbles", "interrupteur", "interrupteurs", "prise", "prises", "tuyau", "tuyaux",
        "cabo", "cabos", "tomada", "tomadas", "fusível", "fusíveis", "parafuso", "parafusos",
    ].map(skillKey))

    /// Whether a technology, as a whole, is stationery, furniture or protective wear, which a person of any trade uses: the tools
    /// request named a teacher's pen and notebooks and a warehouse's safety harness though it asks for none (#354, round 4). It
    /// reads the whole item, not its head: a tool named with such a word stays ("tableau numérique", "Rigging Harness").
    static func namesAnEverydayObject(_ item: String) -> Bool {
        everydayObjectKeys.contains(skillKey(item))
    }

    /// Whether a technology is stationery named with a word after or before its noun ("cahiers d'exercices", "gel pens"): the tools
    /// request named a teacher's exercise books once the whole-item list kept them out (#354, round 6). A board is no stationery
    /// ("tableau interactif"), and a pen that is a device stays ("lápiz óptico", "digital pens").
    static func namesStationery(_ item: String, language: String?) -> Bool {
        guard let head = headKey(of: item, language: language), stationeryHeadKeys.contains(head) else { return false }
        return item.lowercased().split { !$0.isLetter && !$0.isNumber }.allSatisfy { !deviceWords.contains(String($0)) }
    }

    /// The keys (`skillKey`) of the head nouns of stationery in each language.
    private static let stationeryHeadKeys: Set<String> = Set([
        "pens", "pencil", "pencils", "paper",
        "cahier", "cahiers", "carnet", "carnets", "stylo", "stylos", "crayon", "crayons", "feutre", "feutres", "papier",
        "quaderno", "quaderni", "penna", "penne", "matita", "matite", "taccuino", "taccuini", "pennarello", "pennarelli",
        "cuaderno", "cuadernos", "libreta", "libretas", "bolígrafo", "bolígrafos", "lápiz", "lápices", "rotulador", "rotuladores",
        "caderno", "cadernos", "caneta", "canetas", "lápis", "caderneta", "cadernetas",
        "heft", "hefte", "stift", "stifte", "bleistift", "bleistifte", "kugelschreiber", "notizblock",
    ].map(skillKey))

    /// The words that make a pen or a pencil a device of a trade ("penna ottica", "Digitalstift" is one word and no stationery head).
    private static let deviceWords: Set<String> = [
        "digital", "digitale", "digitali", "numérique", "numériques", "optique", "optiques", "ottica", "ottiche", "óptico", "ópticos",
        "óptica", "ótica", "ótico", "optical", "electronic", "elettronica", "electrónico", "eletrônica", "elektronisch", "elektronische",
        "interactive", "interattiva", "interactivo", "interativa", "interaktiv", "interaktive", "smart", "3d",
    ]

    /// The keys (`skillKey`) of stationery, furniture and protective wear, singular and plural, in each language.
    private static let everydayObjectKeys: Set<String> = Set([
        "pen", "ballpoint pen", "pencil", "paper", "sticky notes", "stapler", "ring binder", "blackboard", "chalkboard", "chalk",
        "desk", "chair", "office chair", "table", "gloves", "safety gloves", "work gloves", "safety helmet", "hard hat",
        "safety shoes", "safety boots", "safety vest", "hi-vis vest", "safety harness", "safety glasses", "goggles",
        "stylo", "stylos", "crayon", "crayons", "cahier", "carnet", "papier", "classeur", "tableau noir", "tableau blanc", "craie",
        "feutres", "chaise", "gants", "gants de protection", "casque de protection", "chaussures de sécurité", "gilet de sécurité",
        "harnais de sécurité", "lunettes de protection",
        "penna", "penne", "matita", "matite", "quaderno", "quaderni", "taccuino", "carta", "raccoglitore", "lavagna", "gesso",
        "gessetti", "scrivania", "sedia", "guanti", "guanti da lavoro", "casco", "casco di protezione", "scarpe antinfortunistiche",
        "gilet ad alta visibilità", "imbracatura", "occhiali protettivi",
        "bolígrafo", "lápiz", "lápices", "cuaderno", "libreta", "papel", "carpeta", "archivador", "pizarra", "tiza", "escritorio",
        "silla", "guantes", "guantes de trabajo", "botas de seguridad", "chaleco reflectante", "arnés", "gafas de protección",
        "caneta", "lápis", "caderno", "fichário", "quadro negro", "quadro branco", "giz", "cadeira", "luvas", "capacete",
        "botas de segurança", "colete refletor", "arnês", "óculos de proteção",
        "kugelschreiber", "stift", "stifte", "bleistift", "heft", "hefte", "notizblock", "ordner", "tafel", "kreide",
        "schreibtisch", "stuhl", "handschuhe", "schutzhandschuhe", "arbeitshandschuhe", "helm", "schutzhelm", "sicherheitsschuhe",
        "warnweste", "auffanggurt", "schutzbrille",
    ].map(skillKey))

    /// The words that say only that the person is a professional or has experience, folded: no quality a reader can weigh, so no
    /// soft skill (#354, round 3). A quality said with one of them ("atteggiamento professionale") stays.
    static let emptyQualities: Set<String> = [
        "professional", "professionale", "professionell", "professionnel", "professionnelle", "profesional", "profissional",
        "experience", "experienced", "esperienza", "esperto", "esperta", "erfahrung", "erfahren", "experiencia", "experimentado",
        "experimentada", "experimente", "experimentee", "experiente", "competent", "competente", "kompetent",
        "qualified", "qualificato", "qualificata", "qualifiziert", "qualifie", "qualifiee",
        "cualificado", "cualificada", "qualificado", "qualificada",
    ]

    /// The languages whose own words end in a vowel, each with the words of English it writes as its own: there, a lower-case word
    /// of English of four letters or more that ends in a consonant and is none of them is a word of another language, though the
    /// device's dictionary of the language lists it ("printer"; #354, round 3).
    static let loanwords: [String: Set<String>] = [
        "it": [
            "computer", "scanner", "server", "router", "tablet", "laptop", "desktop", "notebook", "mixer", "timer", "laser",
            "container", "tester", "plotter", "monitor", "display", "email", "chat", "internet", "account", "password", "backup",
            "budget", "check", "chip", "click", "cloud", "cluster", "controller", "cutter", "dimmer", "driver", "flyer", "jack",
            "leasing", "link", "marketing", "meeting", "network", "pallet", "planning", "podcast", "poster", "report", "reset",
            "scooter", "social", "spot", "staff", "stand", "standard", "team", "test", "ticket", "toner", "tour", "trailer",
            "transpallet", "tutor", "workshop", "freezer", "bulldozer", "dumper", "joystick", "flash", "film", "sport", "camion",
            "virus", "problem", "solving", "leadership", "working", "teamwork", "multitasking", "management", "public", "speaking",
            "feedback", "coaching", "networking", "hardware", "software", "badge", "mouse", "file", "smartphone", "touch", "screen",
            "touchscreen", "editor", "format", "layout", "design", "designer", "webinar", "blog", "post", "brand", "branding",
        ],
    ]

    private static let vowels: Set<String> = ["a", "e", "i", "o", "u", "y", "à", "è", "é", "ì", "ò", "ù"]

    /// The beginnings of the words of one quality, by quality: two soft skills with a word of one group say one quality twice
    /// ("precisione", "attenzione ai dettagli"; #354, round 2).
    static let qualityGroups: [[String]] = [
        ["precis", "präzis", "prazis", "attent", "attenz", "atenc", "atenç", "accura", "genau", "sorgf", "exact", "rigor",
         "rigueur", "meticul", "minuz", "esmero", "cuidad"],
        ["teamw", "teamf", "collab", "colab", "coope", "zusammenarb", "squadra", "equipo", "équipe", "equipe"],
    ]

    /// The soft skills without the second of one quality (`qualityGroups`), and those dropped, with the reason.
    static func oneOfEachQuality(_ softSkills: [String]) -> (kept: [String], dropped: [Rejection]) {
        var seen = Set<Int>()
        var kept: [String] = []
        var dropped: [Rejection] = []
        for skill in softSkills {
            let words = skill.lowercased().split { !$0.isLetter }.map(String.init)
            let group = qualityGroups.indices.first { group in words.contains { word in qualityGroups[group].contains(where: word.hasPrefix) } }
            if let group, !seen.insert(group).inserted {
                dropped.append(Rejection(sentence: skill, reason: "the same quality as an earlier one"))
            } else {
                kept.append(skill)
            }
        }
        return (kept, dropped)
    }

    /// The technologies with a one-word one clipped from a phrase of two joined by a conjunction joined back to the phrase it was
    /// cut from, as the description writes it ("schemi elettrici e pneumatici", "hydraulic and pneumatic valves"; #354, round 5):
    /// alone, the clipped word reads as another thing ("pneumatici", tyres). The word is clipped when it shares the ending of the
    /// phrase's last word (Romance languages) or has an adjective's ending and comes before the phrase (English, German, in lower
    /// case); two tools joined by a conjunction stay apart ("PLC e HMI").
    private static func joiningClippedModifiers(_ technologies: [String], in description: String, language: String?) -> [String] {
        let text = " " + description.split { !$0.isLetter && !$0.isNumber }.joined(separator: " ") + " "
        let lowered = text.lowercased()
        let before = ["en", "de"].contains(language ?? "")
        var joined = technologies
        var clipped = Set<Int>()
        for (index, word) in technologies.enumerated() {
            let lower = word.lowercased()
            guard !word.contains(" "), word.count >= 4, word != word.uppercased(), !word.contains(where: \.isNumber) else { continue }
            for (other, phrase) in joined.enumerated() where other != index && !clipped.contains(other) && phrase.contains(" ") {
                let words = phrase.lowercased().split(separator: " ").map(String.init)
                guard let edge = before ? words.first : words.last else { continue }
                let agrees = before
                    ? clippedEndings.contains(where: lower.hasSuffix) && (language != "de" || text.contains(" \(lower) "))
                    : edge.count >= 4 && edge.suffix(2) == lower.suffix(2)
                guard agrees, let conjunction = clippedConjunctions.first(where: { conjunction in
                    lowered.contains(before ? " \(lower) \(conjunction) \(words.joined(separator: " ")) "
                                            : " \(words.joined(separator: " ")) \(conjunction) \(lower) ")
                }) else { continue }
                joined[other] = before ? "\(word) \(conjunction) \(phrase)" : "\(phrase) \(conjunction) \(word)"
                clipped.insert(index)
                break
            }
        }
        return joined.enumerated().filter { !clipped.contains($0.offset) }.map(\.element)
    }

    private static let clippedConjunctions = ["e", "ed", "and", "und", "y", "et"]

    /// The endings of an English or German adjective.
    private static let clippedEndings = ["ic", "al", "ive", "ous", "able", "ible", "ary", "ful", "ische", "ischen", "liche", "lichen"]

    /// The most words of a skill: a longer one is a clause ("edit the sound effects for the shows"), not the name of a skill.
    static let mostSkillWords = 4

    /// Whether a skill's words are too many for the name of a skill: more than `mostSkillWords` besides its link words, or more than
    /// two link words. The link words do not count up to two, so a name of a language that joins its words with them stays
    /// ("logiciel de gestion de classe"; #354, round 5).
    private static func isTooLong(_ words: [String]) -> Bool {
        let links = words.filter { skillLinkWords.contains($0.lowercased()) }.count
        return words.count - links > mostSkillWords || links > 2
    }

    /// Whether a kind of tool named with a quality has a word besides the kind, the quality and its link words: the trade it serves
    /// ("classe" of "logiciel de gestion de classe"; #354, round 5).
    private static func hasAWordOfItsTrade(_ item: String) -> Bool {
        item.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).contains { word in
            !skillLinkWords.contains(word) && !toolWords.contains(word) && !toolKinds.contains(DescriptionText.normalized(word))
                && !softStems.contains(where: word.contains)
                && !toolWords.contains(where: { word.count > $0.count && word.hasSuffix($0) })
        }
    }

    /// A skill the facts request quoted with its verb ("usare i PLC") as the object the verb names ("PLC"); none for one of more than
    /// `mostSkillWords` words, a clause of the person's that names no skill (#354); any other as it is.
    func statedSkill(_ name: String, against description: String) -> String? {
        guard !Self.isTooLong(name.split(whereSeparator: \.isWhitespace).map(String.init)) else { return nil }
        let verdict = skillCheck(technologies: [name], softSkills: [], against: description)
        guard verdict.dropped.contains(where: { $0.reason == "verb cut" }) else { return name }
        return verdict.technologies.first ?? verdict.softSkills.first ?? name
    }

    private func letterWordsKeepingCase(_ text: String) -> [String] {
        text.split { !$0.isLetter }.map(String.init)
    }

    /// The key of a tool's head noun, the word that names its kind ("monitors" of "studio monitors", "pince" of "pince à dénuder"):
    /// the last word in English and German, the first in the other languages, past an elided article ("l'oscilloscope"); none when
    /// that word has fewer than 4 letters ("Logic Pro"). A mixer, a desk and a console are one kind (#354, round 2).
    private static func headKey(of item: String, language: String?) -> String? {
        let words = item.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 1 }
        guard let head = ["en", "de"].contains(language ?? "") ? words.last : words.first, head.count >= 4 else { return nil }
        let key = skillKey(head)
        return headGroups[key] ?? key
    }

    /// The keys of head nouns that name one tool, by the key that stands for them: a mixer and a desk are a mixing console.
    private static let headGroups = ["mixer": "consol", "desk": "consol"]

    /// Whether a skill's head noun is a tool word ("communication tools", "strumenti di misura"), or, in German, ends with one
    /// ("Präzisionswerkzeug"): a tool is no quality of the person (#354). A skill that only starts with a tool word ("Systemdenken",
    /// "systems thinking") names a quality.
    static func namesATool(_ item: String, language: String?) -> Bool {
        let words = item.lowercased().split { !$0.isLetter }.map(String.init)
        guard let head = ["en", "de"].contains(language ?? "") ? words.last : words.first else { return false }
        return toolWords.contains(head) || language == "de" && toolWords.contains { head.count > $0.count && head.hasSuffix($0) }
    }

    /// Whether a soft skill of one word is written in the description only as a name: with a capital past the start of a sentence,
    /// and never in lower case ("Chiara" of "Mi chiamo Chiara Riva"). An address ("chiara.riva@...") is no word of the text. The
    /// final check drops such a word as a claim about the person, after the request for missing skills (#354, round 2).
    static func namesAName(_ item: String, in description: String) -> Bool {
        let key = DescriptionText.normalized(item)
        guard !key.isEmpty, !key.contains(" ") else { return false }
        var capitalised = false
        var sentenceStart = true
        for token in description.split(whereSeparator: \.isWhitespace).map(String.init) {
            defer { sentenceStart = token.last.map { ".!?".contains($0) } ?? false }
            guard !token.contains("@"), !token.contains("://"), !token.lowercased().hasPrefix("www.") else { continue }
            let word = token.trimmingCharacters(in: .punctuationCharacters)
            guard DescriptionText.normalized(word) == key else { continue }
            guard word.first?.isUppercase == true else { return false }
            capitalised = capitalised || !sentenceStart
        }
        return capitalised
    }

    /// Whether a technology names an activity, not a tool: its head noun ends as a noun of an action does ("frequency calibration",
    /// "manutenzione preventiva"). A kind of tool named by what it does is a tool ("software di tracciamento", "logiciel de gestion
    /// de classe"; #354, round 5: dropping it left trades with too few tools). A skill with an acronym or a digit names a tool ("PLC
    /// programming"); a noun of a thing with such an ending ("docking station", "stazione di saldatura") is no activity. German,
    /// whose nouns of actions and of machines share their endings ("Steuerung"), is not read.
    static func namesAnActivity(_ item: String, language: String?) -> Bool {
        if language == "de" { return isGermanActivity(item) }
        guard let language, let endings = activityEndings[language] else { return false }
        let words = item.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.contains(where: { word in
            word.contains(where: \.isNumber) || word.count >= 2 && word.allSatisfy(\.isUppercase)
        }) else { return false }
        let lower = words.map { $0.lowercased() }.filter { !skillLinkWords.contains($0) }
        guard let head = language == "en" ? lower.last : lower.first else { return false }
        return head.count >= 6 && endings.contains(where: head.hasSuffix) && !activityLookalikes.contains(where: head.hasSuffix)
    }

    /// Whether a German technology of one word is the infinitive of an activity written as a noun ("Messen", "Installieren"; #354,
    /// round 2): a word of `germanActivities`, or one of more than 7 letters ending in "-ieren".
    static func isGermanActivity(_ item: String) -> Bool {
        let words = DescriptionText.normalized(item.replacingOccurrences(of: "ß", with: "ss")).split { !$0.isLetter }.map(String.init)
        guard words.count == 1, let word = words.first else { return false }
        return germanActivities.contains(word) || word.count > 7 && word.hasSuffix("ieren")
    }

    /// German infinitives of the trades' activities, without accents.
    static let germanActivities: Set<String> = [
        "messen", "prufen", "bohren", "loten", "schweissen", "verdrahten", "montieren", "schneiden", "planen", "kochen", "backen",
        "reinigen", "reparieren", "warten", "verlegen", "anschliessen", "einbauen", "frasen", "schleifen",
    ]

    /// Whether a technology names a kind of tool and no tool of it ("sound design software", "editor de código", "software"; #354,
    /// round 2): its head noun (the last word in English and German, the first in the other languages) is a word of `toolKinds`,
    /// and none of its words is a name, an acronym or a number ("Pro Tools", "software CMMS", "aplicativos Android"). In German,
    /// whose nouns all have a capital, a capital past the first word names nothing.
    static func namesAKindOfTool(_ item: String, language: String?) -> Bool {
        let words = item.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let folded = words.map { DescriptionText.normalized($0) }
        guard let head = ["en", "de"].contains(language ?? "") ? folded.last : folded.first, toolKinds.contains(head) else { return false }
        return !words.enumerated().contains { index, word in
            word.count > 1 && word == word.uppercased() && word.contains(where: \.isLetter)
                || word.dropFirst().contains(where: \.isUppercase)
                || index > 0 && word.first?.isUppercase == true && language != "de"
                || word.contains(where: \.isNumber)
        }
    }

    /// Whether a technology is a kind of tool with no word of its trade: the kind alone ("software", "Maschine"), or with generic
    /// words only ("editor de texto", "plataforma de desenvolvimento"; #354, round 5). A kind with a word of its trade stays
    /// ("software di rilievo", "machine à coudre").
    private static func namesABareKind(_ item: String, language: String?) -> Bool {
        guard namesAKindOfTool(item, language: language) else { return false }
        let folded = item.split { !$0.isLetter && !$0.isNumber }.map { DescriptionText.normalized(String($0)) }
        let others = ["en", "de"].contains(language ?? "") ? folded.dropLast() : folded.dropFirst()
        return others.allSatisfy { skillLinkWords.contains($0) || genericToolWords.contains($0) }
    }

    /// The words that name no trade beside a kind of tool, without accents.
    private static let genericToolWords: Set<String> = [
        "text", "texto", "testo", "texte", "development", "desenvolvimento", "desarrollo", "sviluppo", "developpement", "entwicklung",
        "data", "dados", "datos", "dati", "donnees", "daten",
    ]

    /// The nouns of a kind of tool, without accents. A system and a machine name a whole of tools and are none of them alone; with
    /// a word of their trade, a name or an acronym they name one ("PA systems", "Steuerungssystem", "macchina da cucire").
    static let toolKinds: Set<String> = [
        "machine", "machines", "maschine", "maschinen", "macchina", "macchine", "maquina", "maquinas", "gerat", "gerate", "equipment",
        "attrezzatura", "equipo", "equipos", "equipamento", "equipamentos", "equipement", "system", "systems", "systeme", "systemes",
        "sistema", "sistemi", "sistemas",
        "software", "softwares", "program", "programs", "programma", "programmi", "programa", "programas", "programm", "programme",
        "application", "applications", "app", "apps", "applicazione", "applicazioni", "aplicacion", "aplicaciones", "aplicacao",
        "aplicativo", "aplicativos", "anwendung", "anwendungen", "logiciel", "logiciels", "platform", "platforms", "piattaforma",
        "plataforma", "plataformas", "plattform", "plateforme", "editor", "editors", "editeur", "workstation", "workstations",
        "tool", "tools", "ferramenta", "ferramentas", "herramienta", "herramientas", "strumento", "strumenti", "outil", "outils",
        "werkzeug", "werkzeuge",
    ]

    /// The endings of the nouns of an action, by language: "-ing" and "-tion" of English, "-zione" and "-mento" of Italian.
    private static let activityEndings: [String: [String]] = [
        "en": ["ing", "tion", "sion", "control"],
        "it": ["zione", "sione", "mento", "aggio", "controllo"],
        "es": ["ción", "sión", "miento", "control"],
        "fr": ["tion", "sion", "contrôle"],
        "pt": ["ção", "são", "controle"],
    ]

    /// The nouns of a thing that end as a noun of an action does.
    private static let activityLookalikes = [
        "station", "stazione", "postazione", "estación", "estação", "strumento", "instrumento", "equipamento", "equipaggiamento",
        "string", "ceiling", "building", "bearing", "housing", "casing", "fitting", "coupling",
    ]

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
