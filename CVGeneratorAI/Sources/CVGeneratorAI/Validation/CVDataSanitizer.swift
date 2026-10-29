import Foundation

/// Removes from a generated CV whatever the person's description does not support (ADR 0023).
///
/// The on-device model sometimes invents details despite its instructions. The instructions ask; this guarantees.
/// Every retained field is checked against the description, deterministically:
/// - facts are quotes: contact details must be complete tokens of the description, and names (of people, employers, schools,
///   titles, places, certifications, skills, interests) must occur in it as a contiguous phrase, ignoring case and accents. The
///   person's name must not be a title, and an entry with nothing identifying left goes (a job needs its employer, or its
///   title with a date);
/// - a date the description does not write that way is cut to its years;
/// - everything an entry says beyond its name (dates, figures, place, issuer, link, texts, "still works there") comes only from
///   the clauses that back it: those that name its employer or school and in which every word is explained, by the closed
///   vocabulary or by the entry's own quotes, and from the clauses of nothing but time and years, or of one of its quoted
///   achievements, that stand next to them (see `Grounding`);
/// - prose (the summary, descriptions, achievements) keeps only sentences each of whose clauses quotes a clause of the description,
///   or of the clauses that back its entry (see `ProseQuotes`); a summary holds no number;
/// - when the draft keeps a fact about the person (a title, a job or a school), the model also writes around it (ADR 0031): the
///   summary and each job's description keep the sentences that state no fact of their own (see `WrittenText`), and the skills the
///   description does not name stay as plain technologies and soft skills, without a level (see `InferredSkills`). With no such
///   fact, the summary keeps only its quotes and the skills only those the description names;
/// - a skill level or language level stays only if the description states it, in a sentence with no negation or hedge, and a
///   language with a level that the description does not state stays without one (#354);
/// - a skill that is also an interest of the draft, and that the person mentions only as leisure, is a hobby, and goes;
/// - an employer or a school keeps no leading indefinite article, and a degree that only says graduating ("diplôme") goes;
/// - every fact is the person's: a language, a skill, an interest and the person's own name, contacts, place and title are kept only
///   as the clauses that speak for the person (or a list with no verb) give them, so a sister's French or a manager's email goes; a
///   contact, only as a label ("Email: ..."), the person's possession of the field ("My email is ..."), a verb of contacting whose
///   object is the person ("You can reach me at ...") or the person as reachable ("I can be reached at ...") gives it, with no other
///   person named ("I can put you in touch with the recruiter at ..." gives none), and never from the references on;
/// - a language, a skill, an interest and the person's headline title and place are kept only as a clause that claims them gives
///   them: one that denies, wishes or supposes ("I have never used Python", "I would like to work as a nurse in Turin") gives none;
/// - prose in another language than the description's is dropped, when a language detector is given;
/// - a description in English or German is grounded only with the device's lexical class of its language (`LexicalClasses`): without
///   it, nothing is grounded and `CVGenerationError.languageDataUnavailable` says which language data the device needs.
///
/// The rules are conservative by construction: what could be read two ways is not accepted, and a dropped fact costs less than an
/// invented one.
public struct CVDataSanitizer: Sendable {
    let languageOfText: @Sendable (String) -> String?
    let lexicalClasses: any LexicalTagger
    let wordList: any WordList

    /// - Parameters:
    ///   - languageOfText: The BCP 47 tag of the language a text is written in, or nil when it cannot tell. With it, prose in
    ///     another language than the description's is dropped: the model sometimes answers a French description with an English
    ///     summary. Without it, language is not checked.
    ///   - lexicalClasses: What tells the verbs of English and German (`LexicalClasses`), and the names of German (`WrittenText`):
    ///     the device's lexical class.
    ///   - wordList: What tells a word of the description's language from a name, in the text the model writes around the facts
    ///     (`WrittenText`): the device's dictionary.
    public init(
        languageOfText: @escaping @Sendable (String) -> String? = { _ in nil },
        lexicalClasses: any LexicalTagger = DeviceLexicalTagger(),
        wordList: any WordList = DeviceWordList()
    ) {
        self.languageOfText = languageOfText
        self.lexicalClasses = lexicalClasses
        self.wordList = wordList
    }

    /// The draft, with what `description` does not support taken out.
    ///
    /// - Parameters:
    ///   - cvData: The facts the first pass of the model extracted (ADR 0031).
    ///   - writing: What the second pass wrote around the grounded facts of `cvData`, its roles one for one with the jobs that
    ///     `sanitize(cvData, against: description)` keeps. Its summary replaces the first pass's when a sentence of it stays; its
    ///     duties follow each job's own description; its skills follow the skills of `cvData`. All of it is text written around the
    ///     facts, and stays only as such (`WrittenText`, `InferredSkills`).
    /// - Throws: `CVGenerationError.languageDataUnavailable`, and no draft, when the description is in English or German and the
    ///   device does not tag its language.
    public func sanitize(_ cvData: CVData, writing: DraftWriting? = nil, against description: String) throws(CVGenerationError) -> CVData {
        let source = DescriptionText(description, languageOfText: languageOfText)
        try requireLanguageData(of: source)
        return LexicalClasses.$tagger.withValue(lexicalClasses) { grounded(cvData, writing: writing, in: source) }
    }

    /// The language of `description`, when it is one of the six, and whether grounding it needs the device's language data and
    /// finds it, asked before the model writes a draft: the use case logs it, then has it `require()` the data.
    func languageCheck(of description: String) -> LanguageCheck {
        languageCheck(of: DescriptionText(description, languageOfText: languageOfText))
    }

    func requireLanguageData(of source: DescriptionText) throws(CVGenerationError) {
        try languageCheck(of: source).require()
    }

    private func languageCheck(of source: DescriptionText) -> LanguageCheck {
        guard let language = source.explainer.language, VerbForms.readsVerbsByTags(in: language) else {
            return LanguageCheck(language: source.explainer.language, data: .notNeeded)
        }
        return LanguageCheck(language: language, data: lexicalClasses.tagsLexicalClass(inLanguage: language.rawValue) ? .present : .missing)
    }

    func grounded(_ cvData: CVData, writing: DraftWriting?, in source: DescriptionText) -> CVData {
        let jobTitles = cvData.experience.map(\.title)
        // The person's name, place and title explain themselves in the clauses of the entries, so they are read first, wherever they stand;
        // the clauses that speak for the person then tell which of them stand in the description for the person.
        let entries = Entries(cvData, personalInfo: sanitize(cvData.personalInfo, jobTitles: jobTitles, source), source)
        let spoken = entries.spoken(in: source)
        let claimed = entries.claimed(in: source)
        let titles = ([cvData.personalInfo.title] + jobTitles).compactMap(\.presentValue)
        let interests = unique(cvData.interests.compactMap(claimed.named).filter {
            !Self.isWork($0, titles: titles, source) && !Self.isQualityAtWork($0, in: source.explainer.language)
        }.map { pastime(of: $0, in: source) }) { $0 }
        let written = WrittenText(source: source, claimed: claimed, wordList: wordList, tagger: lexicalClasses)

        let personalInfo = Self.withWholeTitle(Self.withStatedTitle(
            sanitize(cvData.personalInfo, jobTitles: jobTitles, spoken, claimed: claimed, contacts: entries.contacts(in: source)),
            from: cvData.experience, claimed, said: source
        ), claimed)
        let experience = sanitize(entries.jobs, source, entries, written: written, duties: writing?.roleDescriptions ?? [])
        let education = sanitize(entries.studies, source, entries)
        // The model writes around the facts only when it has one to write around (ADR 0031): with no title, job or school, a summary
        // or a skill of its own would say who the person is with nothing the person said.
        let hasAFact = personalInfo.title != nil || !experience.isEmpty || !education.isEmpty
        let ownWords = Self.words(of: [personalInfo.title] + experience.map(\.title) + education.map(\.degree))
        let summary = { (text: String?) in
            source.written(text, quoting: entries.summaryQuotes, allowsNumbers: false) { written.isPlain($0, ownWords: ownWords) }
        }
        let roleSkills = (writing?.technologies ?? []).map { Skill(name: $0, kind: .technology) }
            + (writing?.softSkills ?? []).map { Skill(name: $0, kind: .softSkill) }

        return CVData(
            personalInfo: personalInfo,
            summary: hasAFact
                ? summary(writing?.summary) ?? summary(cvData.summary)
                : Self.withoutLiking(source.grounded(cvData.summary, quoting: entries.summaryQuotes, allowsNumbers: false), source),
            experience: experience,
            education: education,
            skills: sanitize(
                cvData.skills + roleSkills, source, claimed: claimed, interests: interests,
                titles: ([personalInfo.title] + experience.map(\.title)).compactMap(\.presentValue), entries,
                inferring: hasAFact ? InferredSkills(cvData, language: source.explainer.language, written: written) : nil
            ),
            languages: sanitize(cvData.languages, claimed),
            certifications: sanitize(entries.certifications, entries),
            interests: interests
        )
    }

    // MARK: - Sections

    /// The name must not be a title: for "I'm a nurse" the model writes "Nurse" as the name, and the description does
    /// contain the word.
    ///
    /// - Parameters:
    ///   - claimed: What the headline title and the place are looked up in, when it is not `source`: the clauses that claim them,
    ///     so "I would like to work as a nurse in Turin" gives neither.
    ///   - contacts: What the email, the phone and the links are looked up in, when it is not `source`.
    func sanitize(
        _ info: PersonalInfo, jobTitles: [String], _ source: DescriptionText, claimed: DescriptionText? = nil, contacts: DescriptionText? = nil
    ) -> PersonalInfo {
        let claimed = claimed ?? source
        let contacts = contacts ?? source
        let titles = ([info.title] + jobTitles.map { Optional($0) }).compactMap { $0.presentValue }.map { DescriptionText.normalized($0) }
        let name = source.named(info.name).flatMap { titles.contains(DescriptionText.normalized($0)) ? nil : $0 }

        return PersonalInfo(
            name: name,
            email: contacts.supportedEmail(info.email),
            phone: contacts.supportedPhone(info.phone),
            location: claimed.named(info.location),
            website: contacts.supportedLink(info.website),
            linkedin: contacts.supportedLink(info.linkedin),
            github: contacts.supportedLink(info.github),
            title: claimed.named(info.title)
        )
    }

    /// The person's headline, or when the draft gives none, the title of a job with no employer and no date that the person states as
    /// what they are (`StatedTitle`, #354): such a job goes (next), and its title is the person's own ("I am a plumber").
    private static func withStatedTitle(
        _ info: PersonalInfo, from jobs: [Experience], _ claimed: DescriptionText, said source: DescriptionText
    ) -> PersonalInfo {
        guard info.title == nil else { return info }
        let titleOnly = jobs.filter { $0.company.presentValue == nil && $0.startDate.presentValue == nil && $0.endDate.presentValue == nil }
        guard let title = titleOnly.lazy.compactMap({ StatedTitle.title($0.title, in: claimed, said: source) }).first else { return info }

        return PersonalInfo(
            name: info.name, email: info.email, phone: info.phone, location: info.location, website: info.website,
            linkedin: info.linkedin, github: info.github, title: title
        )
    }

    /// The person's headline as the whole title the person states (`StatedTitle.whole`): not a part of it the model cut (#354).
    private static func withWholeTitle(_ info: PersonalInfo, _ claimed: DescriptionText) -> PersonalInfo {
        guard let title = info.title.presentValue else { return info }
        return PersonalInfo(
            name: info.name, email: info.email, phone: info.phone, location: info.location, website: info.website,
            linkedin: info.linkedin, github: info.github, title: StatedTitle.whole(title, in: claimed)
        )
    }

    /// A job needs its employer, or its title together with a date: a title alone is the person's own ("I'm a nurse"),
    /// not a job, and a job built on it carries whatever the model made up around it.
    ///
    /// Its description also keeps the sentences that state no fact of their own (`WrittenText`), with no word of the title or the
    /// employer of another job, and that restate no sentence of the description about another job alone (ADR 0031): those of its own
    /// description, then those of its `duties`, the text the second pass wrote for the job at the same position of the result. When
    /// the job has duties, a sentence of its own description that only says the person held the job (`RoleStub`) goes: it restates
    /// the title and the employer in front of them; with none, it is the job's only text, and stays.
    ///
    /// With duties, the job's text also holds the duties the person said for it (ADR 0031): copied from the clauses of the description
    /// that belong to it, in front of the written ones, and all of it in the job's first person. A job named after another in one
    /// sentence ("a sound technician at Alpha ..., then at Beta ...") keeps the title the sentence gave the first (`jobTitle(of:)`).
    private func sanitize(
        _ jobs: [Entries.Job], _ source: DescriptionText, _ entries: Entries, written: WrittenText, duties: [String?]
    ) -> [Experience] {
        keptJobs(jobs, source, entries).enumerated().map { position, kept in
            let (job, experience) = kept
            let rule = DutyRule(job: job, among: jobs, source: source, entries: entries, written: written)
            let evidence = rule.evidence
            let description = { (text: String?, quotes: ProseQuotes) in
                source.written(text, quoting: quotes, allowsNumbers: true) { rule.rejection(of: $0) == nil }
            }
            let writtenDuties = position < duties.count
                ? description(duties[position], evidence.quotable.adding(evidence.quotableByAchievements)) : nil
            let quoteWords = Set(Self.letterWords(of: description(experience.description, evidence.quotable) ?? ""))
            // The duties the person said for the job (ADR 0031), copied from its clauses, pass the same check and come first, in
            // the job's first person (`FirstPersonDuty`); one the job's own quote already holds is not said twice.
            let pinned = entries.pinnedDuties(of: job.subject).flatMap { $0.kept { description($0, evidence.quotable) } }.filter { duty in
                !Self.letterWords(of: duty).filter { $0.count >= 3 }.allSatisfy(quoteWords.contains)
            }.map { FirstPersonDuty.written($0, current: experience.current, language: source.explainer.language, wordList: wordList) }
            // A written duty that restates a said one (the same words, by their first four letters) goes.
            let pinnedStems = Self.stems(of: pinned.joined(separator: " "))
            let newDuties = pinned.isEmpty ? writtenDuties : writtenDuties.flatMap { text in
                SentenceSplitter.sentences(in: text).filter { !Self.stems(of: $0).isSubset(of: pinnedStems) }.joined(separator: " ").presentValue
            }
            let roleDuties = position < duties.count ? Self.joined(pinned.joined(separator: " ").presentValue, newDuties) : nil
            let dutyWords = Set(Self.letterWords(of: roleDuties ?? ""))
            let jobWords = Self.words(of: [experience.title, experience.company])
            let quote = description(experience.description, evidence.quotable).flatMap { quote in
                roleDuties == nil ? quote : SentenceSplitter.sentences(in: quote)
                    .filter { !RoleStub.isStub($0, jobWords: jobWords, language: source.explainer.language) }
                    // A quoted sentence the duties restate goes, so the job's text keeps one voice.
                    .filter { !Self.letterWords(of: $0).filter { $0.count >= 3 }.allSatisfy(dutyWords.contains) }
                    .map { Self.withoutClausesSaid($0, in: pinned) }
                    .joined(separator: " ").presentValue
            }
            // A job written a section at a time is in the first person, even when none of its written duties stays: a quoted
            // sentence said with a gerund ("setting up the PA systems and mixing the support acts") is written in it too, so the
            // job's text keeps one form; its text ends with a full stop (#354).
            let firstPerson = { (text: String?) in
                position >= duties.count ? text : text.flatMap { text in
                    SentenceSplitter.sentences(in: text).map {
                        FirstPersonDuty.written($0, current: experience.current, language: source.explainer.language, wordList: wordList)
                    }.joined(separator: " ").presentValue
                }
            }
            return Experience(
                title: experience.title, company: experience.company, location: experience.location,
                startDate: experience.startDate, endDate: experience.endDate, current: experience.current,
                description: Self.joined(firstPerson(quote), firstPerson(roleDuties)).map(Self.ended),
                achievements: experience.achievements
            )
        }
    }

    /// The jobs of `jobs` the rules keep, in their order, each with its grounded entry before its text is written: a job needs a
    /// factual mention, and its employer or its title with a date; of the jobs with the same title and employer, the first stays.
    func keptJobs(_ jobs: [Entries.Job], _ source: DescriptionText, _ entries: Entries) -> [(job: Entries.Job, experience: Experience)] {
        let cleaned = jobs.compactMap { job -> (job: Entries.Job, experience: Experience)? in
            guard entries.hasFactualMention(of: job.subject) else { return nil }
            let evidence = entries.evidence(of: job.subject)
            let title = entries.jobTitle(of: job)
            let dates = evidence.supportedDates([job.entry.startDate, job.entry.endDate])
            guard job.company != nil || (title != nil && dates.contains { $0 != nil }) else { return nil }

            return (job: job, experience: Experience(
                title: title ?? "",
                company: job.company.map { withoutArticle($0, source) } ?? "",
                location: job.location.flatMap { evidence.backs($0) ? $0 : nil },
                startDate: dates[0],
                endDate: dates[1],
                current: job.entry.current && evidence.statesCurrent,
                description: job.entry.description,
                achievements: unique(job.entry.achievements.enumerated().compactMap { number, achievement in
                    source.grounded(achievement, quoting: evidence.quotable(byAchievement: number), allowsNumbers: true)
                }) { $0 }
            ))
        }
        return unique(cleaned) { "\($0.experience.title)|\($0.experience.company)" }
    }

    /// An interest quoted with a conjugated verb of its clause first ("spiele Schach" of "... und spiele Schach") as the pastime the
    /// verb names ("Schach"): a conjugated verb is no pastime (#354). The verb is the interest's first word where the description's
    /// sentence that quotes the interest tags it as one, or, in German, where "ich" and the interest do, in English and German, whose
    /// verbs grounding reads by their tags. A verb in the form of its infinitive is the pastime's phrase and stays (#354, round 1): an
    /// English verb with no "-s" and no "-ed" ("play football", "bake bread"), a gerund ("hiking in the Alps") and a German infinitive
    /// ("wandern gehen"). An interest of one word stays whole, and so does one whose rest holds no word of 3 letters or more, or, in
    /// German, no noun.
    func pastime(of interest: String, in source: DescriptionText) -> String {
        let language = source.explainer.language
        let words = Word.words(in: interest)
        guard let language, VerbForms.readsVerbsByTags(in: language), lexicalClasses.tagsLexicalClass(inLanguage: language.rawValue),
              words.count > 1, let first = words.first?.folded, Self.isConjugated(first, in: language) else { return interest }
        let folded = words.map(\.folded)
        for sentence in source.sentences {
            let said = Word.words(in: sentence.raw)
            guard let start = said.indices.first(where: { start in
                start + folded.count <= said.count && said[start..<(start + folded.count)].map(\.folded) == folded
            }) else { continue }
            let verbs = lexicalClasses.verbs(in: sentence.raw, language: language.rawValue)
            // A German verb that shares the subject of an earlier clause ("... und spiele Schach") is tagged as the person says it,
            // after "ich" and in lower case: in the sentence the tags read it as an adjective, and capitalized as a noun.
            let saidAlone = language == .german
                && lexicalClasses.verbs(in: "ich " + Self.lowercasingFirst(interest), language: language.rawValue).contains { $0.contains(4) }
            guard saidAlone || verbs.contains(where: { $0.contains(said[start].range.lowerBound) }) else { return interest }
            let rest = words.dropFirst().drop { Self.skillLinkWords.contains($0.folded) }
            guard let next = rest.first, rest.contains(where: { $0.folded.count >= 3 }) else { return interest }
            let kept = String(Array(interest)[next.range.lowerBound...])
            guard language != .german || kept.split(separator: " ").contains(where: { $0.first?.isUppercase == true }) else {
                return interest
            }
            return kept
        }
        return interest
    }

    /// Whether every sentence of the description that gives `interest` also names one of the draft's `titles` and says nothing of
    /// liking (`LeisureMentions.speaksOfLiking`): "I am a plumber and I fix pipes" gives the work, not a hobby, so neither "fix pipes"
    /// nor "plumber" is an interest (#354). A sentence that likes something ("I am a nurse and I love painting") keeps it.
    private static func isWork(_ interest: String, titles: [String], _ source: DescriptionText) -> Bool {
        let giving = source.sentences.filter { !DescriptionText.spans(of: DescriptionText.normalized(interest), in: $0.folded).isEmpty }
        return !giving.isEmpty && giving.allSatisfy { sentence in
            titles.contains { !DescriptionText.spans(of: DescriptionText.normalized($0), in: sentence.folded).isEmpty }
                && !LeisureMentions.speaksOfLiking(sentence.raw, in: source.explainer.language)
        }
    }

    /// The sentences of `summary` that say nothing of what the person likes (`LeisureMentions.speaksOfLiking`) and quote no sentence of
    /// the description that does, or nil when none is left: a summary with no fact to write around keeps only its quotes, and a hobby
    /// is no role ("Me gusta pasear con mi perro, leer novelas policíacas": neither it nor "Leer novelas policíacas" stays).
    private static func withoutLiking(_ summary: String?, _ source: DescriptionText) -> String? {
        guard let summary else { return nil }
        let language = source.explainer.language
        let kept = SentenceSplitter.sentences(in: summary).filter { sentence in
            !LeisureMentions.speaksOfLiking(sentence, in: language)
                && !source.restates(sentence, ofSentencesWhere: { LeisureMentions.speaksOfLiking($0.raw, in: language) })
        }
        return kept.isEmpty ? nil : kept.joined(separator: " ")
    }

    /// The sentences of `first`, then those of `second` that `first` does not hold already, each a sentence of its own: the role's
    /// quote ("I plan the night shifts") ends with a full stop when it has none, and a written sentence opens with a capital when its
    /// first word has none ("plans the menus"), so that neither reads as part of the other (ADR 0031).
    static func joined(_ first: String?, _ second: String?) -> String? {
        guard let second else { return first }
        guard let first else { return second }
        let held = Set(SentenceSplitter.sentences(in: first).map { DescriptionText.normalized($0) })
        let added = SentenceSplitter.sentences(in: second).filter { !held.contains(DescriptionText.normalized($0)) }
        guard !added.isEmpty else { return first }
        return ([Self.ended(first)] + added.map(Self.capitalized)).joined(separator: " ")
    }

    /// `sentence` without each clause after its first that one of the duties the person said holds, by the words after its verb:
    /// three or more of them, of three letters or more, all words of that duty ("dando una mano con gli ordini dei ricambi" and the
    /// person's own "Davo anche una mano con gli ordini dei ricambi"), so that the job's text says the duty once, in the person's
    /// words (#354). A clause with a word that no one of them has stays.
    static func withoutClausesSaid(_ sentence: String, in duties: [String]) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = trimmed.last.map { ".!?…".contains($0) ? String($0) : "" } ?? ""
        let clauses = trimmed.dropLast(end.count).components(separatedBy: ", ")
        guard clauses.count > 1 else { return sentence }
        let dutyWords = duties.map { Set(Self.letterWords(of: $0)) }
        let kept = [clauses[0]] + clauses.dropFirst().filter { clause in
            let said = Self.letterWords(of: clause).dropFirst().filter { $0.count >= 3 }
            return said.count < 3 || !dutyWords.contains { words in said.allSatisfy(words.contains) }
        }
        return kept.count == clauses.count ? sentence : kept.joined(separator: ", ") + end
    }

    /// `text` with a full stop after it, unless it ends with one, a question mark, an exclamation mark or an ellipsis.
    private static func ended(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?…".contains(last) else { return trimmed }
        return trimmed + "."
    }

    /// `sentence` with a capital on its first letter when its first word has none: a word written with a capital inside ("eBooks",
    /// "iOS") stays as written.
    private static func capitalized(_ sentence: String) -> String {
        let firstWord = sentence.prefix { !$0.isWhitespace }
        guard let first = firstWord.first, first.isLowercase, !firstWord.contains(where: \.isUppercase) else { return sentence }
        return first.uppercased() + sentence.dropFirst()
    }

    private func sanitize(_ studies: [Entries.Study], _ source: DescriptionText, _ entries: Entries) -> [Education] {
        let cleaned = studies.compactMap { study -> Education? in
            guard entries.hasFactualMention(of: study.subject) else { return nil }
            let evidence = entries.evidence(of: study.subject)
            let degree = entries.supportedTitle(of: study.subject, study.degree).flatMap {
                EntryWording.namesADegree($0, in: source.explainer.language) ? $0 : nil
            }
            guard degree != nil || study.institution != nil else { return nil }
            var dates = evidence.supportedDates([study.entry.endDate, study.entry.startDate], graduationDate: 0)
            // A study the model dated keeps the year the person says they finished it as its end date, whatever dates the model
            // wrote (#354); a study the model left undated stays so.
            let dated = study.entry.endDate != nil || study.entry.startDate != nil
            if dates[0] == nil, dated { dates[0] = evidence.completionYear(besides: dates) }

            return Education(
                degree: degree,
                institution: study.institution.map { withoutArticle($0, source) },
                startDate: dates[1],
                endDate: dates[0],
                description: source.grounded(study.entry.description, quoting: evidence.quotable, allowsNumbers: true)
            )
        }
        return unique(cleaned) { "\($0.degree ?? "")|\($0.institution ?? "")" }
    }

    /// A skill the description names is a fact of the person: it stays only as a clause that claims it gives it (`claimed`), so "I have
    /// never used Python" gives no Python. A skill whose name is one of the interests that the description gives, and that the
    /// person mentions only as leisure ("In my free time I like chess and hiking"), is a hobby: as a skill it would claim an ability
    /// the person never claimed, so it goes, and the interest stays. The same holds for a skill that is part of an interest ("cooking
    /// for friends" of "cooking for friends at the weekend"). A skill the person mentions anywhere else ("proficient in Python", a
    /// job's clause, a list of skills) stays; another person's clause counts for neither (see `LeisureMentions`). A skill whose words
    /// are all names of languages ("English", "Deutsch") is a language, which the draft lists apart: as a skill it goes.
    ///
    /// A skill the description does not name is one the model wrote for the person's role (ADR 0031): it stays, without a level, only
    /// when `inferring` accepts it, and within `InferredSkills.caps` once the named skills of its kind are counted. One whose name ends
    /// with a named skill ("Adobe Illustrator" beside "Illustrator") is that skill again, and goes; so does one whose words hold, or
    /// are held by, those of a skill the model wrote before it ("écoute active" after "écoute", #354): the first of them stays.
    ///
    /// A skill whose name is one of the grounded draft's `titles` ("sviluppatore iOS") says the title again, which the draft shows as the title,
    /// and goes, named or not (#354); a skill that is only a word of a title ("iOS" of "iOS developer") stays.
    private func sanitize(
        _ skills: [Skill], _ source: DescriptionText, claimed: DescriptionText, interests: [String], titles: [String],
        _ entries: Entries, inferring inferred: InferredSkills?
    ) -> [Skill] {
        let titleNames = Set(titles.map { DescriptionText.normalized($0) })
        let skills = skills.filter { !titleNames.contains(DescriptionText.normalized($0.name)) }
        let names = skills.compactMap { claimed.named($0.name) }
        let hobbies = interests.map { DescriptionText.normalized($0) }
        let cleaned = skills.compactMap { skill -> (skill: Skill, isNamed: Bool)? in
            guard source.named(skill.name) != nil else {
                return inferred?.accepted(skill.name).map { (skill: Skill(name: $0, kind: skill.kind), isNamed: false) }
            }
            guard let name = claimed.named(skill.name), !Self.isALanguage(name) else { return nil }
            let normalized = DescriptionText.normalized(name)
            let isAHobby = hobbies.contains { !DescriptionText.spans(of: normalized, in: $0).isEmpty }
                && entries.mentionsOnlyAsLeisure(name, interests: interests)
            guard !isAHobby else { return nil }
            let allowed = claimed.levels(of: name, among: names, vocabulary: .skills)
            return (skill: Skill(name: name, level: statedLevel(skill.level, allowed: allowed), kind: skill.kind), isNamed: true)
        }
        let named = cleaned.filter(\.isNamed).map { DescriptionText.normalized($0.skill.name) }
        var written: [String] = []
        let kept = unique(cleaned) { $0.skill.name }.filter { item in
            guard !item.isNamed else { return true }
            let name = DescriptionText.normalized(item.skill.name)
            guard !named.contains(where: { name.hasSuffix(" " + $0) }),
                  !written.contains(where: { Self.holds($0, name) || Self.holds(name, $0) }) else { return false }
            written.append(name)
            return true
        }
        var room = InferredSkills.caps
        for named in kept where named.isNamed { room[named.skill.kind, default: 0] -= 1 }
        return kept.compactMap { item in
            guard !item.isNamed else { return item.skill }
            guard room[item.skill.kind, default: 0] > 0 else { return nil }
            room[item.skill.kind, default: 0] -= 1
            return item.skill
        }
    }

    /// A language keeps the level the draft gives it only if the description states that level for it: any other level would be made
    /// up, and goes, but the language stays without one (#354: "Parlo italiano e inglese." lost both languages to a made-up "native").
    private func sanitize(_ languages: [Language], _ source: DescriptionText) -> [Language] {
        let names = languages.compactMap { source.named($0.name) }
        let cleaned = languages.compactMap { language -> Language? in
            guard let name = source.named(language.name) else { return nil }
            guard language.proficiency != nil else { return Language(name: name) }

            let allowed = source.levels(of: name, among: names, vocabulary: .languages, codes: LevelVocabulary<LanguageProficiency>.codes)
            return Language(name: name, proficiency: statedLevel(language.proficiency, allowed: allowed))
        }
        return unique(cleaned) { $0.name }
    }

    private func sanitize(_ certifications: [Entries.Certificate], _ entries: Entries) -> [Certification] {
        let cleaned = certifications.compactMap { certificate -> Certification? in
            guard entries.hasFactualMention(of: certificate.subject) else { return nil }
            let evidence = entries.evidence(of: certificate.subject)

            return Certification(
                name: certificate.name,
                issuer: certificate.issuer.flatMap { evidence.backs($0) ? $0 : nil },
                date: evidence.supportedDates([certificate.entry.date])[0],
                url: certificate.entry.url.presentValue.flatMap { evidence.links.contains(AddressTokens.normalizedLink($0)) ? $0 : nil }
            )
        }
        return unique(cleaned) { $0.name }
    }

    // MARK: - Helpers

    /// An employer or a school without its leading indefinite article ("a nursery"), when what is left is a quote too.
    private func withoutArticle(_ name: String, _ source: DescriptionText) -> String {
        source.named(EntryWording.withoutLeadingArticle(name, in: source.explainer.language)) ?? name
    }

    /// Whether the normalized name `outer` holds the normalized name `inner` as whole words ("ecoute active" holds "ecoute").
    private static func holds(_ outer: String, _ inner: String) -> Bool {
        !DescriptionText.spans(of: inner, in: outer).isEmpty
    }

    /// Whether every word of a skill's name is the name of a language ("English", "italiano inglese").
    private static func isALanguage(_ name: String) -> Bool {
        let words = Word.words(in: name)
        return !words.isEmpty && words.allSatisfy { InferredSkills.languageNames.contains($0.folded) }
    }

    /// The model's level, if the description allows it.
    private func statedLevel<Level: Hashable>(_ level: Level?, allowed: Set<Level>?) -> Level? {
        guard let level, allowed?.contains(level) == true else { return nil }
        return level
    }

    /// ADR 0031, D4: the words a job's duty may not hold: those of the other jobs' employers, past its own title's and the function
    /// words. A common noun of another job's title ("manutenzione") is no such word; the whole title is (`namedTitle`).
    static func foreignWords(of otherEmployers: [String?], own: Set<String>, language: Vocabulary.Language?) -> Set<String> {
        words(of: otherEmployers).subtracting(own).filter { !Vocabulary.isNeutral($0, in: language) }
    }

    /// ADR 0031, D4: the other jobs' titles that are not the job's own.
    static func otherTitles(_ titles: [String?], own: String?) -> [String] {
        let ownWords = Word.words(in: own ?? "").map(\.folded)
        var seen = Set<[String]>()
        return titles.compactMap { $0 }.filter { title in
            let folded = Word.words(in: title).map(\.folded)
            return !folded.isEmpty && folded != ownWords && seen.insert(folded).inserted
        }
    }

    /// ADR 0031, D4: the first of `titles` that `sentence` holds whole, word by word.
    static func namedTitle(in sentence: String, among titles: [String]) -> String? {
        let words = Word.words(in: sentence).map(\.folded)
        return titles.first { title in
            let phrase = Word.words(in: title).map(\.folded)
            guard !phrase.isEmpty, phrase.count <= words.count else { return false }
            return (0...(words.count - phrase.count)).contains { Array(words[$0..<($0 + phrase.count)]) == phrase }
        }
    }

    /// ADR 0031, D3: the words of `sentence` when it quotes one of the job's own clauses word for word, with no number; none
    /// otherwise.
    static func quotedWords(of sentence: String, quoting quotes: ProseQuotes?, _ source: DescriptionText) -> Set<String> {
        guard let quotes, source.written(sentence, quoting: quotes, allowsNumbers: false, orPlain: { _ in false }) != nil else { return [] }
        return Set(Word.words(in: sentence).map(\.folded))
    }

    /// Whether `verb`, folded, is in a form other than its infinitive: in English one with "-s" or "-ed" ("plays", "baked"), never
    /// the bare form a person says after "I" ("play") nor a gerund; in German one that does not end in "n" ("spiele", not "spielen").
    static func isConjugated(_ verb: String, in language: Vocabulary.Language) -> Bool {
        switch language {
        case .german: !verb.hasSuffix("n")
        default: verb.hasSuffix("ed") || verb.hasSuffix("s") && !verb.hasSuffix("ss")
        }
    }

    /// `text` with its first letter in lower case, the rest as written.
    static func lowercasingFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }

    /// The lowercased runs of letters of `text`.
    static func letterWords(of text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    /// The first four letters of each word of `text` of three letters or more: how a written duty is matched to a said one.
    static func stems(of text: String) -> Set<String> {
        Set(letterWords(of: text).filter { $0.count >= 3 }.map { String($0.prefix(4)) })
    }

    /// The words of `texts`, as `Word.folded` writes them.
    static func words(of texts: [String?]) -> Set<String> {
        Set(texts.compactMap { $0 }.flatMap { Word.words(in: $0).map(\.folded) })
    }

    /// Keeps the first of the items sharing a key, ignoring case and accents: the model sometimes repeats an entry.
    private func unique<T>(_ items: [T], by key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return items.filter { seen.insert(DescriptionText.normalized(key($0))).inserted }
    }
}

/// The language of a description and the state of the language data that grounding it needs (#270): English and German are read
/// with the device's lexical class of the language, which the system downloads on request; the other four need none.
struct LanguageCheck: Equatable, Sendable {
    enum LanguageData: Equatable, Sendable {
        /// The language is not one that is read with the device's language data, or is not one of the six.
        case notNeeded
        /// The device tags the language.
        case present
        /// The device has not got the data of the language yet.
        case missing
    }

    /// The language of the description, when it is one of the six.
    let language: Vocabulary.Language?
    let data: LanguageData

    /// - Throws: `CVGenerationError.languageDataUnavailable` when the device has not got the data the language needs.
    func require() throws(CVGenerationError) {
        guard data == .missing, let language else { return }
        throw .languageDataUnavailable(languageCode: language.rawValue)
    }
}
