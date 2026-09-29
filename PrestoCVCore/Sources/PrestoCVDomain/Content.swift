import Foundation

// MARK: - Personal details

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

public struct Experience: Hashable, Sendable {
    public var role: String, company: String, location: String, period: Period?, description: String
    public init(role: String, company: String, location: String = "", period: Period? = nil, description: String = "") {
        self.role = role; self.company = company; self.location = location; self.period = period; self.description = description
    }
}

public struct Education: Hashable, Sendable {
    public var degree: String, school: String, period: Period?, description: String
    public init(degree: String, school: String, period: Period? = nil, description: String = "") {
        self.degree = degree; self.school = school; self.period = period; self.description = description
    }
}

public struct Skill: Hashable, Sendable {
    public var name: String, level: SkillLevel?
    public init(name: String, level: SkillLevel? = nil) { self.name = name; self.level = level }
}

public struct LanguageSkill: Hashable, Sendable {
    public var language: String, proficiency: LanguageProficiency
    public init(language: String, proficiency: LanguageProficiency) { self.language = language; self.proficiency = proficiency }
}

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
    /// Trimmed, never empty, no duplicates ignoring case.
    public private(set) var interests: [String]

    public init(experiences: [Experience] = [], education: [Education] = [], skills: [Skill] = [], languages: [LanguageSkill] = [],
                certifications: [Certification] = [], profiles: [ProfileLink] = [], interests: [String] = []) {
        self.experiences = experiences; self.education = education; self.skills = skills; self.languages = languages
        self.certifications = certifications; self.profiles = profiles; self.interests = []
        setInterests(interests)
    }

    public mutating func setInterests(_ values: [String]) {
        var seen = Set<String>()
        interests = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
