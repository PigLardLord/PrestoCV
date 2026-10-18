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
/// - a skill level or language level stays only if the description states it, in a sentence with no negation or hedge, and a
///   language with a level that the description does not state goes whole; a language without a level may stay without one;
/// - a skill that is also an interest of the draft is a hobby, and goes;
/// - an employer or a school keeps no leading indefinite article;
/// - every fact is the person's: a language, a skill, an interest and the person's own name, contacts, place and title are kept only
///   as the clauses that speak for the person (or a list with no verb) give them, so a sister's French or a manager's email goes; a
///   contact, only as a label ("Email: ..."), the person's possession of the field ("My email is ..."), a verb of contacting whose
///   object is the person ("You can reach me at ...") or the person as reachable ("I can be reached at ...") gives it, with no other
///   person named ("I can put you in touch with the recruiter at ..." gives none), and never from the references on;
/// - prose in another language than the description's is dropped, when a language detector is given;
/// - a description in English or German is grounded only with the device's lexical class of its language (`LexicalClasses`): without
///   it, nothing is grounded and `CVGenerationError.languageDataUnavailable` says which language data the device needs.
///
/// The rules are conservative by construction: what could be read two ways is not accepted, and a dropped fact costs less than an
/// invented one.
public struct CVDataSanitizer: Sendable {
    private let languageOfText: @Sendable (String) -> String?
    private let lexicalClasses: any LexicalTagger

    /// - Parameters:
    ///   - languageOfText: The BCP 47 tag of the language a text is written in, or nil when it cannot tell. With it, prose in
    ///     another language than the description's is dropped: the model sometimes answers a French description with an English
    ///     summary. Without it, language is not checked.
    ///   - lexicalClasses: What tells the verbs of English and German (`LexicalClasses`): the device's lexical class.
    public init(
        languageOfText: @escaping @Sendable (String) -> String? = { _ in nil },
        lexicalClasses: any LexicalTagger = DeviceLexicalTagger()
    ) {
        self.languageOfText = languageOfText
        self.lexicalClasses = lexicalClasses
    }

    /// The draft, with what `description` does not support taken out.
    ///
    /// - Throws: `CVGenerationError.languageDataUnavailable`, and no draft, when the description is in English or German and the
    ///   device does not tag its language.
    public func sanitize(_ cvData: CVData, against description: String) throws(CVGenerationError) -> CVData {
        let source = DescriptionText(description, languageOfText: languageOfText)
        try requireLanguageData(of: source)
        return LexicalClasses.$tagger.withValue(lexicalClasses) { grounded(cvData, in: source) }
    }

    /// Whether the device has the language data that grounding `description` needs, asked before the model writes a draft.
    ///
    /// - Throws: `CVGenerationError.languageDataUnavailable` when the description is in English or German and the device does not
    ///   tag its language.
    public func requireLanguageData(for description: String) throws(CVGenerationError) {
        try requireLanguageData(of: DescriptionText(description, languageOfText: languageOfText))
    }

    private func requireLanguageData(of source: DescriptionText) throws(CVGenerationError) {
        guard let language = source.explainer.language, VerbForms.readsVerbsByTags(in: language),
              !lexicalClasses.tagsLexicalClass(inLanguage: language.rawValue) else { return }
        throw .languageDataUnavailable(languageCode: language.rawValue)
    }

    private func grounded(_ cvData: CVData, in source: DescriptionText) -> CVData {
        let jobTitles = cvData.experience.map(\.title)
        // The person's name, place and title explain themselves in the clauses of the entries, so they are read first, wherever they stand;
        // the clauses that speak for the person then tell which of them stand in the description for the person.
        let entries = Entries(cvData, personalInfo: sanitize(cvData.personalInfo, jobTitles: jobTitles, source), source)
        let spoken = entries.spoken(in: source)

        return CVData(
            personalInfo: sanitize(cvData.personalInfo, jobTitles: jobTitles, spoken, contacts: entries.contacts(in: source)),
            summary: source.grounded(cvData.summary, quoting: entries.summaryQuotes, allowsNumbers: false),
            experience: sanitize(entries.jobs, source, entries),
            education: sanitize(entries.studies, source, entries),
            skills: sanitize(cvData.skills, spoken, interests: cvData.interests),
            languages: sanitize(cvData.languages, spoken),
            certifications: sanitize(entries.certifications, entries),
            interests: unique(cvData.interests.compactMap(spoken.named)) { $0 }
        )
    }

    // MARK: - Sections

    /// The name must not be a title: for "I'm a nurse" the model writes "Nurse" as the name, and the description does
    /// contain the word.
    ///
    /// - Parameter contacts: What the email, the phone and the links are looked up in, when it is not `source`.
    private func sanitize(_ info: PersonalInfo, jobTitles: [String], _ source: DescriptionText, contacts: DescriptionText? = nil) -> PersonalInfo {
        let contacts = contacts ?? source
        let titles = ([info.title] + jobTitles.map { Optional($0) }).compactMap { $0.presentValue }.map { DescriptionText.normalized($0) }
        let name = source.named(info.name).flatMap { titles.contains(DescriptionText.normalized($0)) ? nil : $0 }

        return PersonalInfo(
            name: name,
            email: contacts.supportedEmail(info.email),
            phone: contacts.supportedPhone(info.phone),
            location: source.named(info.location),
            website: contacts.supportedLink(info.website),
            linkedin: contacts.supportedLink(info.linkedin),
            github: contacts.supportedLink(info.github),
            title: source.named(info.title)
        )
    }

    /// A job needs its employer, or its title together with a date: a title alone is the person's own ("I'm a nurse"),
    /// not a job, and a job built on it carries whatever the model made up around it.
    private func sanitize(_ jobs: [Entries.Job], _ source: DescriptionText, _ entries: Entries) -> [Experience] {
        let cleaned = jobs.compactMap { job -> Experience? in
            guard entries.hasFactualMention(of: job.subject) else { return nil }
            let evidence = entries.evidence(of: job.subject)
            let title = entries.supportedTitle(of: job.subject, job.title)
            let dates = evidence.supportedDates([job.entry.startDate, job.entry.endDate])
            guard job.company != nil || (title != nil && dates.contains { $0 != nil }) else { return nil }

            return Experience(
                title: title ?? "",
                company: job.company.map { withoutArticle($0, source) } ?? "",
                location: job.location.flatMap { evidence.backs($0) ? $0 : nil },
                startDate: dates[0],
                endDate: dates[1],
                current: job.entry.current && evidence.statesCurrent,
                description: source.grounded(job.entry.description, quoting: evidence.quotable, allowsNumbers: true),
                achievements: unique(job.entry.achievements.enumerated().compactMap { number, achievement in
                    source.grounded(achievement, quoting: evidence.quotable(byAchievement: number), allowsNumbers: true)
                }) { $0 }
            )
        }
        return unique(cleaned) { "\($0.title)|\($0.company)" }
    }

    private func sanitize(_ studies: [Entries.Study], _ source: DescriptionText, _ entries: Entries) -> [Education] {
        let cleaned = studies.compactMap { study -> Education? in
            guard entries.hasFactualMention(of: study.subject) else { return nil }
            let evidence = entries.evidence(of: study.subject)
            let degree = entries.supportedTitle(of: study.subject, study.degree)
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

    /// A skill whose name is one of the draft's interests is a hobby ("chess", "hiking"): as a skill it would claim an ability the
    /// person never claimed, so it goes, and the interest stays.
    private func sanitize(_ skills: [Skill], _ source: DescriptionText, interests: [String]) -> [Skill] {
        let names = skills.compactMap { source.named($0.name) }
        let hobbies = Set(interests.map { DescriptionText.normalized($0) })
        let cleaned = skills.compactMap { skill -> Skill? in
            guard let name = source.named(skill.name), !hobbies.contains(DescriptionText.normalized(name)) else { return nil }
            let allowed = source.levels(of: name, among: names, vocabulary: .skills)
            return Skill(name: name, level: statedLevel(skill.level, allowed: allowed))
        }
        return unique(cleaned) { $0.name }
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

    /// Keeps the first of the items sharing a key, ignoring case and accents: the model sometimes repeats an entry.
    private func unique<T>(_ items: [T], by key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return items.filter { seen.insert(DescriptionText.normalized(key($0))).inserted }
    }
}
