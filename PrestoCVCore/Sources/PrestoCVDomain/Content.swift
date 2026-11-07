import Foundation

// MARK: - Personal details

public struct PersonalDetails: Hashable, Sendable {
    public var fullName: String { didSet { fullName = TextRules.singleLine(fullName) } }
    public var professionalTitle: String { didSet { professionalTitle = TextRules.singleLine(professionalTitle) } }
    public var email: EmailAddress?
    public var phone: PhoneNumber?
    public var location: String { didSet { location = TextRules.singleLine(location) } }
    public var website: WebLink?
    public var summary: String { didSet { summary = TextRules.multiLine(summary) } }

    public init(fullName: String = "", professionalTitle: String = "", email: EmailAddress? = nil, phone: PhoneNumber? = nil,
                location: String = "", website: WebLink? = nil, summary: String = "") {
        self.fullName = TextRules.singleLine(fullName); self.professionalTitle = TextRules.singleLine(professionalTitle)
        self.email = email; self.phone = phone
        self.location = TextRules.singleLine(location); self.website = website; self.summary = TextRules.multiLine(summary)
    }
}

// MARK: - Entries

public struct Experience: Hashable, Sendable {
    public var role: String { didSet { role = TextRules.singleLine(role) } }
    public var company: String { didSet { company = TextRules.singleLine(company) } }
    public var location: String { didSet { location = TextRules.singleLine(location) } }
    public var period: Period?
    public var description: String { didSet { description = TextRules.multiLine(description) } }
    public init(role: String, company: String, location: String = "", period: Period? = nil, description: String = "") {
        self.role = TextRules.singleLine(role); self.company = TextRules.singleLine(company)
        self.location = TextRules.singleLine(location); self.period = period; self.description = TextRules.multiLine(description)
    }
}

public struct Education: Hashable, Sendable {
    public var degree: String { didSet { degree = TextRules.singleLine(degree) } }
    public var school: String { didSet { school = TextRules.singleLine(school) } }
    public var period: Period?
    public var description: String { didSet { description = TextRules.multiLine(description) } }
    public init(degree: String, school: String, period: Period? = nil, description: String = "") {
        self.degree = TextRules.singleLine(degree); self.school = TextRules.singleLine(school)
        self.period = period; self.description = TextRules.multiLine(description)
    }
}

public struct Skill: Hashable, Sendable {
    public var name: String { didSet { name = TextRules.singleLine(name) } }
    public var level: SkillLevel?
    public init(name: String, level: SkillLevel? = nil) { self.name = TextRules.singleLine(name); self.level = level }
}

public struct LanguageSkill: Hashable, Sendable {
    public var language: String { didSet { language = TextRules.singleLine(language) } }
    public var proficiency: LanguageProficiency
    public init(language: String, proficiency: LanguageProficiency) {
        self.language = TextRules.singleLine(language); self.proficiency = proficiency
    }
}

public struct Certification: Hashable, Sendable {
    public var name: String { didSet { name = TextRules.singleLine(name) } }
    public var issuer: String { didSet { issuer = TextRules.singleLine(issuer) } }
    public var issued: PartialDate?
    public var link: WebLink?
    public var description: String { didSet { description = TextRules.multiLine(description) } }
    public init(name: String, issuer: String, issued: PartialDate? = nil, link: WebLink? = nil, description: String = "") {
        self.name = TextRules.singleLine(name); self.issuer = TextRules.singleLine(issuer)
        self.issued = issued; self.link = link; self.description = TextRules.multiLine(description)
    }
}

/// A public profile, such as GitHub or LinkedIn. It exists only with a valid link.
public struct ProfileLink: Hashable, Sendable {
    public var platform: String { didSet { platform = TextRules.singleLine(platform) } }
    public var link: WebLink
    public init(platform: String, link: WebLink) { self.platform = TextRules.singleLine(platform); self.link = link }
}

// MARK: - Sections

/// The sections of a CV, each an ordered list of entries. Order within a section is the order the user chose.
public struct CVSections: Hashable, Sendable {
    public var experiences: [Experience]
    public var education: [Education]
    public var skills: [Skill]
    public var languages: [LanguageSkill]
    public var certifications: [Certification]
    public var profiles: [ProfileLink]
    /// Single-line text, trimmed, never empty, no duplicates ignoring case.
    public private(set) var interests: [String]

    public init(experiences: [Experience] = [], education: [Education] = [], skills: [Skill] = [], languages: [LanguageSkill] = [],
                certifications: [Certification] = [], profiles: [ProfileLink] = [], interests: [String] = []) {
        self.experiences = experiences; self.education = education; self.skills = skills; self.languages = languages
        self.certifications = certifications; self.profiles = profiles; self.interests = []
        setInterests(interests)
    }

    public mutating func setInterests(_ values: [String]) {
        interests = Self.canonicalInterests(values, cleaningText: true)
    }

    /// The one rule for a list of interests: each trimmed, none empty, no two equal ignoring case, first kept. With
    /// `cleaningText` the text rule is applied first, so entries it empties or makes equal are dropped or merged;
    /// without it, only the list rule is applied: a reader asks whether a stored list is already canonical.
    public static func canonicalInterests(_ values: [String], cleaningText: Bool) -> [String] {
        var seen = Set<String>()
        return values.map { (cleaningText ? TextRules.singleLine($0) : $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
