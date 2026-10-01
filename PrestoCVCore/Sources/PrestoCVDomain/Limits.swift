/// The size bounds of a CV, in UTF-8 bytes and in entries (R6). They sit at or below the bounds of both places a CV
/// goes:
/// - **The document validator** of the exporter (16,384 bytes in a text, 262,144 in the whole document, 200 entries in a
///   section), so a CV within them maps to a document the validator accepts. The domain is never looser: the document
///   adds its language tag, and the domain counts every text a CV holds, the title included.
/// - **The stored file** (schema 1), which caps a text at 10,000 characters, a list at 500 items and a file at 5 MiB.
///   10,000 bytes are never more than 10,000 characters, 200 entries are under 500, and 250,000 bytes of text are far
///   under the file cap, so a CV that can be saved can be stored.
///
/// A CV over a bound is refused at save with the reason (`CV.limitViolation`). No text is ever cut.
public enum CVLimits {
    public static let maxTextBytes = 10_000
    public static let maxTotalTextBytes = 250_000
    public static let maxEntriesPerSection = 200
}

/// A section that holds a list of entries.
public enum CVSection: Hashable, Sendable { case experiences, education, skills, languages, certifications, profiles, interests }

public enum ExperienceField: Hashable, Sendable { case role, company, location, description }
public enum EducationField: Hashable, Sendable { case degree, school, description }
public enum CertificationField: Hashable, Sendable { case name, issuer, description }

/// A text of a CV that can be too long, named so that presentation can point at it (R13: no display strings here). The
/// text of an entry carries the entry's index in its section. A skill, a language, a profile and an interest have one
/// text each. Contact details are not listed: a value object is bounded when it is made.
public enum CVTextField: Hashable, Sendable {
    case title
    case fullName, professionalTitle, location, summary
    case experience(index: Int, ExperienceField)
    case education(index: Int, EducationField)
    case skill(index: Int)
    case language(index: Int)
    case certification(index: Int, CertificationField)
    case profile(index: Int)
    case interest(index: Int)
}

/// Why a CV is over a bound of `CVLimits`.
public enum CVLimitViolation: Hashable, Sendable {
    case textTooLong(CVTextField)
    case tooManyEntries(CVSection)
    case tooMuchText
}

extension CV {
    /// The first bound this CV is over, or nil. The order is fixed: a text that is too long (the title, the personal
    /// details, then the entries of each section in order), then a section with too many entries, then the total text.
    /// Sizes are those of the text as the CV holds it, after normalisation. The total counts every text, the title and
    /// the contact details and links included.
    public var limitViolation: CVLimitViolation? {
        let texts = limitedTexts
        if let tooLong = texts.first(where: { $0.text.utf8.count > CVLimits.maxTextBytes }) { return .textTooLong(tooLong.field) }
        if let crowded = entryCounts.first(where: { $0.count > CVLimits.maxEntriesPerSection }) { return .tooManyEntries(crowded.section) }
        let total = texts.reduce(0) { $0 + $1.text.utf8.count } + boundedTexts.reduce(0) { $0 + $1.utf8.count }
        return total > CVLimits.maxTotalTextBytes ? .tooMuchText : nil
    }

    /// The texts a user writes, in the order they are checked.
    private var limitedTexts: [(field: CVTextField, text: String)] {
        var texts: [(field: CVTextField, text: String)] = []
        func add(_ field: CVTextField, _ text: String) { texts.append((field, text)) }
        add(.title, title); add(.fullName, personal.fullName); add(.professionalTitle, personal.professionalTitle)
        add(.location, personal.location); add(.summary, personal.summary)
        for (index, entry) in sections.experiences.enumerated() {
            add(.experience(index: index, .role), entry.role); add(.experience(index: index, .company), entry.company)
            add(.experience(index: index, .location), entry.location); add(.experience(index: index, .description), entry.description)
        }
        for (index, entry) in sections.education.enumerated() {
            add(.education(index: index, .degree), entry.degree); add(.education(index: index, .school), entry.school)
            add(.education(index: index, .description), entry.description)
        }
        for (index, entry) in sections.skills.enumerated() { add(.skill(index: index), entry.name) }
        for (index, entry) in sections.languages.enumerated() { add(.language(index: index), entry.language) }
        for (index, entry) in sections.certifications.enumerated() {
            add(.certification(index: index, .name), entry.name); add(.certification(index: index, .issuer), entry.issuer)
            add(.certification(index: index, .description), entry.description)
        }
        for (index, entry) in sections.profiles.enumerated() { add(.profile(index: index), entry.platform) }
        for (index, interest) in sections.interests.enumerated() { add(.interest(index: index), interest) }
        return texts
    }

    /// The texts of value objects: they count toward the total, and cannot be too long on their own.
    private var boundedTexts: [String] {
        var texts: [String] = [personal.email?.value, personal.phone?.value, personal.website?.value].compactMap { $0 }
        texts += sections.certifications.compactMap { $0.link?.value }
        texts += sections.profiles.map { $0.link.value }
        return texts
    }

    private var entryCounts: [(section: CVSection, count: Int)] {
        var counts: [(section: CVSection, count: Int)] = []
        counts.append((.experiences, sections.experiences.count)); counts.append((.education, sections.education.count))
        counts.append((.skills, sections.skills.count)); counts.append((.languages, sections.languages.count))
        counts.append((.certifications, sections.certifications.count)); counts.append((.profiles, sections.profiles.count))
        counts.append((.interests, sections.interests.count))
        return counts
    }
}
