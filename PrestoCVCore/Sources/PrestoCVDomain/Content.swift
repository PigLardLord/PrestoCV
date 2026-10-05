import Foundation

// MARK: - Personal details

/// The details printed at the top of a CV. Text is kept as given; the email, phone and website are validated value objects.
public struct PersonalDetails: Hashable, Sendable {
    public var fullName: String
    public var professionalTitle: String
    public var email: EmailAddress?
    public var phone: PhoneNumber?
    public var location: String
    public var website: WebLink?
    public var summary: String

    public init(fullName: String = "", professionalTitle: String = "", email: EmailAddress? = nil, phone: PhoneNumber? = nil,
                location: String = "", website: WebLink? = nil, summary: String = "") {
        self.fullName = fullName; self.professionalTitle = professionalTitle; self.email = email; self.phone = phone
        self.location = location; self.website = website; self.summary = summary
    }
}

// MARK: - Entries

/// A job: a role at a company, over a period if one is known.
public struct Experience: Hashable, Sendable {
    public var role: String, company: String, location: String, period: Period?, description: String
    public init(role: String, company: String, location: String = "", period: Period? = nil, description: String = "") {
        self.role = role; self.company = company; self.location = location; self.period = period; self.description = description
    }
}

/// A course of study at a school, over a period if one is known.
public struct Education: Hashable, Sendable {
    public var degree: String, school: String, period: Period?, description: String
    public init(degree: String, school: String, period: Period? = nil, description: String = "") {
        self.degree = degree; self.school = school; self.period = period; self.description = description
    }
}

/// A skill, with a level from 1 to 5 if the user rated it.
public struct Skill: Hashable, Sendable {
    public var name: String, level: SkillLevel?
    public init(name: String, level: SkillLevel? = nil) { self.name = name; self.level = level }
}

/// How well the user speaks a language, by CEFR level or as a native.
public struct LanguageSkill: Hashable, Sendable {
    public var language: String, proficiency: LanguageProficiency
    public init(language: String, proficiency: LanguageProficiency) { self.language = language; self.proficiency = proficiency }
}

/// A certification, with the month or year it was issued and a link to it if there are any.
public struct Certification: Hashable, Sendable {
    public var name: String, issuer: String, issued: PartialDate?, link: WebLink?, description: String
    public init(name: String, issuer: String, issued: PartialDate? = nil, link: WebLink? = nil, description: String = "") {
        self.name = name; self.issuer = issuer; self.issued = issued; self.link = link; self.description = description
    }
}

/// A public profile, such as GitHub or LinkedIn. It exists only with a valid link.
public struct ProfileLink: Hashable, Sendable {
    public var platform: String, link: WebLink
    public init(platform: String, link: WebLink) { self.platform = platform; self.link = link }
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
    /// Trimmed, never empty, no duplicates ignoring case. The first of two equal interests stays.
    public private(set) var interests: [String] {
        get { distinctInterests }
        set { distinctInterests = Self.distinctTrimmed(newValue) }
    }
    private var distinctInterests: [String] = []

    /// The initialiser only stores what it is given; the interests rule is the setter of `interests`.
    public init(experiences: [Experience] = [], education: [Education] = [], skills: [Skill] = [], languages: [LanguageSkill] = [],
                certifications: [Certification] = [], profiles: [ProfileLink] = [], interests: [String] = []) {
        self.experiences = experiences; self.education = education; self.skills = skills; self.languages = languages
        self.certifications = certifications; self.profiles = profiles; self.interests = interests
    }

    public mutating func setInterests(_ values: [String]) { interests = values }

    private static func distinctTrimmed(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
