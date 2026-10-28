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
///   language with a level that the description does not state goes whole; a language without a level may stay without one;
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
    private let languageOfText: @Sendable (String) -> String?
    private let lexicalClasses: any LexicalTagger
    private let wordList: any WordList

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

    private func requireLanguageData(of source: DescriptionText) throws(CVGenerationError) {
        try languageCheck(of: source).require()
    }

    private func languageCheck(of source: DescriptionText) -> LanguageCheck {
        guard let language = source.explainer.language, VerbForms.readsVerbsByTags(in: language) else {
            return LanguageCheck(language: source.explainer.language, data: .notNeeded)
        }
        return LanguageCheck(language: language, data: lexicalClasses.tagsLexicalClass(inLanguage: language.rawValue) ? .present : .missing)
    }

    private func grounded(_ cvData: CVData, writing: DraftWriting?, in source: DescriptionText) -> CVData {
        let jobTitles = cvData.experience.map(\.title)
        // The person's name, place and title explain themselves in the clauses of the entries, so they are read first, wherever they stand;
        // the clauses that speak for the person then tell which of them stand in the description for the person.
        let entries = Entries(cvData, personalInfo: sanitize(cvData.personalInfo, jobTitles: jobTitles, source), source)
        let spoken = entries.spoken(in: source)
        let claimed = entries.claimed(in: source)
        let interests = unique(cvData.interests.compactMap(claimed.named)) { $0 }
        let written = WrittenText(source: source, claimed: claimed, wordList: wordList, tagger: lexicalClasses)

        let personalInfo = Self.withStatedTitle(
            sanitize(cvData.personalInfo, jobTitles: jobTitles, spoken, claimed: claimed, contacts: entries.contacts(in: source)),
            from: cvData.experience, claimed, said: source
        )
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
                cvData.skills + roleSkills, source, claimed: claimed, interests: interests, entries,
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
    private func sanitize(
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

    /// A job needs its employer, or its title together with a date: a title alone is the person's own ("I'm a nurse"),
    /// not a job, and a job built on it carries whatever the model made up around it.
    ///
    /// Its description also keeps the sentences that state no fact of their own (`WrittenText`), with no word of the title or the
    /// employer of another job, and that restate no sentence of the description about another job alone (ADR 0031): those of its own
    /// description, then those of its `duties`, the text the second pass wrote for the job at the same position of the result.
    private func sanitize(
        _ jobs: [Entries.Job], _ source: DescriptionText, _ entries: Entries, written: WrittenText, duties: [String?]
    ) -> [Experience] {
        let cleaned = jobs.compactMap { job -> (job: Entries.Job, experience: Experience)? in
            guard entries.hasFactualMention(of: job.subject) else { return nil }
            let evidence = entries.evidence(of: job.subject)
            let title = entries.supportedTitle(of: job.subject, job.title)
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
        return unique(cleaned) { "\($0.experience.title)|\($0.experience.company)" }.enumerated().map { position, kept in
            let (job, experience) = kept
            let ownWords = Self.words(of: [experience.title])
            let others = jobs.filter { $0.subject != job.subject }.flatMap { [$0.title, $0.company] }
            let foreignWords = Self.words(of: others).subtracting(ownWords).filter { !Vocabulary.isNeutral($0, in: source.explainer.language) }
            let otherEmployers = jobs.filter { $0.subject != job.subject }.compactMap(\.company)
            let description = { (text: String?) in
                source.written(text, quoting: entries.evidence(of: job.subject).quotable, allowsNumbers: true) { sentence in
                    written.isPlain(sentence, ownWords: ownWords, foreignWords: foreignWords)
                        && !source.repeats(sentence, ofSentencesNaming: otherEmployers, notNaming: [job.company].compactMap { $0 })
                }
            }
            let duties = position < duties.count ? description(duties[position]) : nil
            return Experience(
                title: experience.title, company: experience.company, location: experience.location,
                startDate: experience.startDate, endDate: experience.endDate, current: experience.current,
                description: Self.joined(description(experience.description), duties),
                achievements: experience.achievements
            )
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
    private static func joined(_ first: String?, _ second: String?) -> String? {
        guard let second else { return first }
        guard let first else { return second }
        let held = Set(SentenceSplitter.sentences(in: first).map { DescriptionText.normalized($0) })
        let added = SentenceSplitter.sentences(in: second).filter { !held.contains(DescriptionText.normalized($0)) }
        guard !added.isEmpty else { return first }
        return ([Self.ended(first)] + added.map(Self.capitalized)).joined(separator: " ")
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
            let dates = evidence.supportedDates([study.entry.endDate, study.entry.startDate], graduationDate: 0)

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
    /// the person never claimed, so it goes, and the interest stays. A skill the person mentions anywhere else ("proficient in
    /// Python", a job's clause, a list of skills) stays; another person's clause counts for neither (see `LeisureMentions`).
    ///
    /// A skill the description does not name is one the model wrote for the person's role (ADR 0031): it stays, without a level, only
    /// when `inferring` accepts it, and within `InferredSkills.caps` once the named skills of its kind are counted.
    private func sanitize(
        _ skills: [Skill], _ source: DescriptionText, claimed: DescriptionText, interests: [String], _ entries: Entries,
        inferring inferred: InferredSkills?
    ) -> [Skill] {
        let names = skills.compactMap { claimed.named($0.name) }
        let hobbies = Set(interests.map { DescriptionText.normalized($0) })
        let cleaned = skills.compactMap { skill -> (skill: Skill, isNamed: Bool)? in
            guard source.named(skill.name) != nil else {
                return inferred?.accepted(skill.name).map { (skill: Skill(name: $0, kind: skill.kind), isNamed: false) }
            }
            guard let name = claimed.named(skill.name) else { return nil }
            let isAHobby = hobbies.contains(DescriptionText.normalized(name)) && entries.mentionsOnlyAsLeisure(name, interests: interests)
            guard !isAHobby else { return nil }
            let allowed = claimed.levels(of: name, among: names, vocabulary: .skills)
            return (skill: Skill(name: name, level: statedLevel(skill.level, allowed: allowed), kind: skill.kind), isNamed: true)
        }
        let kept = unique(cleaned) { $0.skill.name }
        var room = InferredSkills.caps
        for named in kept where named.isNamed { room[named.skill.kind, default: 0] -= 1 }
        return kept.compactMap { item in
            guard !item.isNamed else { return item.skill }
            guard room[item.skill.kind, default: 0] > 0 else { return nil }
            room[item.skill.kind, default: 0] -= 1
            return item.skill
        }
    }

    /// A language the draft gives a level is kept only if the description states that level for it: any other level would be made up.
    /// A language the draft gives no level may stay without one.
    private func sanitize(_ languages: [Language], _ source: DescriptionText) -> [Language] {
        let names = languages.compactMap { source.named($0.name) }
        let cleaned = languages.compactMap { language -> Language? in
            guard let name = source.named(language.name) else { return nil }
            guard language.proficiency != nil else { return Language(name: name) }

            let allowed = source.levels(of: name, among: names, vocabulary: .languages, codes: LevelVocabulary<LanguageProficiency>.codes)
            guard let level = statedLevel(language.proficiency, allowed: allowed) else { return nil }
            return Language(name: name, proficiency: level)
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

    /// The model's level, if the description allows it.
    private func statedLevel<Level: Hashable>(_ level: Level?, allowed: Set<Level>?) -> Level? {
        guard let level, allowed?.contains(level) == true else { return nil }
        return level
    }

    /// The words of `texts`, as `Word.folded` writes them.
    private static func words(of texts: [String?]) -> Set<String> {
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
