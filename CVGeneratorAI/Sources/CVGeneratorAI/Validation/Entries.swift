import Foundation

/// The jobs, studies and certifications of a draft, each with what the clauses of the description say about it.
///
/// A value of an entry (employer, title, place, school, degree, certification, issuer) is kept here only if the description
/// writes it, as a quote. What the entry then says beyond its name is up to its `EntryEvidence`.
struct Entries {
    struct Job {
        let entry: Experience
        let company: String?
        let title: String?
        let location: String?
        let subject: Int
    }

    struct Study {
        let entry: Education
        let degree: String?
        let institution: String?
        let subject: Int
    }

    struct Certificate {
        let entry: Certification
        let name: String
        let issuer: String?
        let subject: Int
    }

    let jobs: [Job]
    let studies: [Study]
    let certifications: [Certificate]
    private let subjects: [Subject]
    private let clauses: DescriptionClauses
    private let grounding: Grounding
    private let person: [[String]]
    private let language: Vocabulary.Language?

    init(_ cvData: CVData, personalInfo: PersonalInfo, _ source: DescriptionText) {
        let companies = cvData.experience.map { (company: source.namedEmployer($0.company), title: source.named($0.title)) }
        let institutions = cvData.education.map { (institution: source.named($0.institution), degree: source.named($0.degree)) }
        var subjects: [Subject] = []

        jobs = zip(cvData.experience, companies).map { entry, named in
            let shared = companies.contains { Self.isSame($0.company, named.company) && !Self.isSame($0.title, named.title) }
            let location = source.named(entry.location)
            subjects.append(Self.subject(
                primary: named.company, secondary: named.title, isShared: shared,
                quotes: [named.title, named.company, location], achievements: entry.achievements
            ))
            return Job(entry: entry, company: named.company, title: named.title, location: location, subject: subjects.count - 1)
        }
        studies = zip(cvData.education, institutions).map { entry, named in
            let shared = institutions.contains { Self.isSame($0.institution, named.institution) && !Self.isSame($0.degree, named.degree) }
            subjects.append(Self.subject(
                primary: named.institution, secondary: named.degree, isShared: shared, quotes: [named.degree, named.institution],
                isEducation: true
            ))
            return Study(entry: entry, degree: named.degree, institution: named.institution, subject: subjects.count - 1)
        }
        certifications = cvData.certifications.compactMap { entry in
            guard let name = source.named(entry.name) else { return nil }
            let issuer = source.named(entry.issuer)
            subjects.append(Subject(names: [Self.words(of: name)], quotes: [name, issuer].compactMap { $0 }.map(Self.words(of:))))
            return Certificate(entry: entry, name: name, issuer: issuer, subject: subjects.count - 1)
        }

        person = [personalInfo.name, personalInfo.location, personalInfo.title].compactMap { $0 }.map(Self.words(of:))
        self.subjects = subjects
        language = source.explainer.language
        clauses = DescriptionClauses(
            sentences: source.sentences.map(\.raw), protecting: subjects.flatMap(\.quotes) + person, language: language,
            lineStarts: Set(source.sentences.indices.filter { source.sentences[$0].startsALine })
        )
        grounding = Grounding(clauses: clauses, explainer: source.explainer, subjects: subjects, person: person)
    }

    /// What a summary may quote.
    var summaryQuotes: ProseQuotes {
        grounding.summaryQuotes
    }

    /// The description as the person speaks it: `source` without the clauses that speak for someone else.
    func spoken(in source: DescriptionText) -> DescriptionText {
        DescriptionText(sentences: grounding.spokenSentences, of: source)
    }

    /// The description as the person claims skills, interests and languages in it: `source` without the clauses that speak for
    /// someone else, or that deny, wish or suppose ("I have never used Python", "I would like to learn Spanish").
    func claimed(in source: DescriptionText) -> DescriptionText {
        DescriptionText(sentences: grounding.claimedSentences, of: source)
    }

    /// The description as it gives the person's contacts: `source` without the clauses that speak for someone else or name another
    /// person.
    func contacts(in source: DescriptionText) -> DescriptionText {
        DescriptionText(sentences: grounding.contactSentences, of: source)
    }

    /// The duties the person said for the job, copied from its attributed clauses.
    func pinnedDuties(of subject: Int) -> [Grounding.PinnedDuty] {
        grounding.pinnedDuties(of: subject)
    }

    /// The duties the person said with no job, for the current job (`Grounding.generalDuties`, ADR 0031, D7).
    func generalDuties() -> [Grounding.PinnedDuty] {
        grounding.generalDuties()
    }

    /// The clauses of those duties, as the current job's own quotes (`Grounding.generalDutyQuotes`).
    var generalDutyQuotes: ProseQuotes {
        grounding.generalDutyQuotes
    }

    /// The job's title the description supports, or, for a job named only in an employer clause coordinated after
    /// another job's ("a technician at Alpha from 2016 to 2019, then at Beta from 2019 to 2021"), the head job's supported title,
    /// when the job's own title is empty or a part of it.
    func jobTitle(of job: Job) -> String? {
        if let title = supportedTitle(of: job.subject, job.title) { return title }
        guard let head = grounding.attribution.head[job.subject], let headJob = jobs.first(where: { $0.subject == head }),
              let headTitle = supportedTitle(of: head, headJob.title) else { return nil }
        let own = Set(Self.words(of: job.title ?? ""))
        return own.isSubset(of: Set(Self.words(of: headTitle))) ? headTitle : nil
    }

    /// The clause that says the person's field (`Grounding.fieldClause`).
    func fieldClause() -> String? { grounding.fieldClause() }

    /// The sentences in which the person says what they do and what they are like, with no job (`Grounding.ownSentences`).
    func ownSentences() -> [String] { grounding.ownSentences() }

    func evidence(of subject: Int) -> EntryEvidence {
        grounding.evidence(of: subject)
    }

    /// Whether the description mentions the entry as a fact: some clause names it and holds no word of negation, doubt, wish,
    /// intention, future or condition. Without one the entry is not kept.
    func hasFactualMention(of subject: Int) -> Bool {
        grounding.hasFactualMention(subject)
    }

    /// Whether the person mentions `name` only as leisure, among the draft's `interests` that the description gives (see
    /// `LeisureMentions`): "In my free time I like chess" does, "I am proficient in Python" does not, and a clause that claims
    /// nothing for the person (another person's, or one that denies, wishes or supposes) counts for neither.
    func mentionsOnlyAsLeisure(_ name: String, interests: [String]) -> Bool {
        let leisure = LeisureMentions(
            clauses: clauses, language: language, interests: interests.map(Self.words(of:)), claimed: grounding.claimedWords(at:)
        )
        return leisure.mentionsOnlyAsLeisure(Self.words(of: name))
    }

    /// The title of a job, or the degree of a study, when the description gives it for that entry: in a clause that names the
    /// entry, or in one of nothing but explained words. A title the description gives only for another job ("head nurse at Beta")
    /// is not this job's.
    func supportedTitle(of subject: Int, _ title: String?) -> String? {
        guard let title else { return nil }
        return grounding.supportsTitle(Self.words(of: title), of: subject, person: person) ? title : nil
    }

    // MARK: - Subjects

    /// An entry is found by its employer or school; when another entry has the same one, by that and its title together; when
    /// it has none, by its title alone.
    private static func subject(
        primary: String?, secondary: String?, isShared: Bool, quotes: [String?], achievements: [String] = [], isEducation: Bool = false
    ) -> Subject {
        let quotes = quotes.compactMap { $0 }.map(words(of:))
        let achievements = achievements.map(words(of:))

        if let primary {
            let names = isShared ? secondary.map { [words(of: primary), words(of: $0)] } ?? [] : [words(of: primary)]
            return Subject(
                names: names, mentions: [words(of: primary)], quotes: quotes, achievements: achievements, holder: words(of: primary),
                isEducation: isEducation
            )
        }
        return Subject(
            names: secondary.map { [words(of: $0)] } ?? [], quotes: quotes, achievements: achievements, isFoundByItsTitle: true,
            isEducation: isEducation
        )
    }

    private static func words(of text: String) -> [String] {
        EntryEvidence.foldedWords(of: text)
    }

    private static func isSame(_ first: String?, _ second: String?) -> Bool {
        first.map { DescriptionText.normalized($0) } == second.map { DescriptionText.normalized($0) }
    }
}
