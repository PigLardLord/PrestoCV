/// A skill, with a level from 1 to 5 when the CV gives one.
public struct SourceSkill: Hashable, Sendable {
    public let name: String
    public let level: Int?

    public init(name: String, level: Int? = nil) throws(TailoringModelError) {
        try Bounds.text(name, .skillName)
        guard level.map({ (1...5).contains($0) }) ?? true else { throw .invalidSkillLevel }
        self.name = name
        self.level = level
    }
}

/// The CEFR levels, plus native. Its wording belongs to the edges (R13).
public enum LanguageLevel: String, CaseIterable, Hashable, Sendable {
    case a1, a2, b1, b2, c1, c2, native
}

/// A language the person speaks, and how well.
public struct SourceLanguage: Hashable, Sendable {
    public let name: String
    public let proficiency: LanguageLevel

    public init(name: String, proficiency: LanguageLevel) throws(TailoringModelError) {
        try Bounds.text(name, .languageName)
        self.name = name
        self.proficiency = proficiency
    }
}

/// A public profile, such as GitHub or LinkedIn.
public struct SourceProfile: Hashable, Sendable {
    public let platform: String
    public let link: String

    public init(platform: String, link: String) throws(TailoringModelError) {
        try Bounds.text(platform, .platform)
        try Bounds.text(link, .link)
        self.platform = platform
        self.link = link
    }
}

/// A degree. Its description is kept whole, as written.
public struct SourceEducation: Hashable, Sendable {
    public let degree: String
    public let school: String
    public let period: TailoringPeriod?
    public let description: String

    public init(degree: String, school: String, period: TailoringPeriod? = nil, description: String = "") throws(TailoringModelError) {
        try Bounds.text(degree, .degree)
        try Bounds.text(school, .school)
        try Bounds.text(description, .description)
        self.degree = degree
        self.school = school
        self.period = period
        self.description = description
    }
}

/// A certification. The link is a plain string, like the other contact details.
public struct SourceCertification: Hashable, Sendable {
    public let name: String
    public let issuer: String
    public let issued: TailoringDate?
    public let link: String?
    public let description: String

    public init(name: String, issuer: String, issued: TailoringDate? = nil, link: String? = nil,
                description: String = "") throws(TailoringModelError) {
        try Bounds.text(name, .certificationName)
        try Bounds.text(issuer, .issuer)
        try Bounds.optionalText(link, .link)
        try Bounds.text(description, .description)
        self.name = name
        self.issuer = issuer
        self.issued = issued
        self.link = link
        self.description = description
    }
}
