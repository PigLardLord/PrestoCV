// MARK: - Personal details

/// The details printed at the top of a CV. Text is kept as given; the email, phone and website are validated value objects.
public struct PersonalDetails: Hashable, Sendable {
    /// The person's name. A CV can be saved only when it is not empty.
    public var fullName: String
    /// The role printed under the name, such as "iOS Engineer". Not the CV's title in the list.
    public var professionalTitle: String
    /// The contact email, if given.
    public var email: EmailAddress?
    /// The contact phone number, if given.
    public var phone: PhoneNumber?
    /// Where the person is, such as a city.
    public var location: String
    /// The person's website, if given.
    public var website: WebLink?
    /// A short presentation of the person.
    public var summary: String

    /// No details: every text empty, nothing else given.
    public static let empty = PersonalDetails()

    /// Every parameter is the value of the property of the same name; none is required.
    public init(fullName: String = "", professionalTitle: String = "", email: EmailAddress? = nil, phone: PhoneNumber? = nil,
                location: String = "", website: WebLink? = nil, summary: String = "") {
        self.fullName = fullName; self.professionalTitle = professionalTitle; self.email = email; self.phone = phone
        self.location = location; self.website = website; self.summary = summary
    }
}

// MARK: - Entries

/// A job: a role at a company, over a period if one is known.
public struct Experience: Hashable, Sendable {
    /// What the person did there, such as "Engineer".
    public var role: String
    /// Where the person worked.
    public var company: String
    /// Where the job was, such as a city.
    public var location: String
    /// When the person held the job, if known.
    public var period: Period?
    /// What the job involved.
    public var description: String

    /// Every parameter is the value of the property of the same name; only the role and the company are required.
    public init(role: String, company: String, location: String = "", period: Period? = nil, description: String = "") {
        self.role = role; self.company = company; self.location = location; self.period = period; self.description = description
    }
}

/// A course of study at a school, over a period if one is known.
public struct Education: Hashable, Sendable {
    /// What was studied or awarded, such as "BSc Mathematics".
    public var degree: String
    /// Where it was studied.
    public var school: String
    /// When it was studied, if known.
    public var period: Period?
    /// What the course involved.
    public var description: String

    /// Every parameter is the value of the property of the same name; only the degree and the school are required.
    public init(degree: String, school: String, period: Period? = nil, description: String = "") {
        self.degree = degree; self.school = school; self.period = period; self.description = description
    }
}

/// A skill, with a level from 1 to 5 if the user rated it.
public struct Skill: Hashable, Sendable {
    /// The skill, such as "Swift".
    public var name: String
    /// How well the person has it, if rated.
    public var level: SkillLevel?

    /// - Parameters:
    ///   - name: The skill.
    ///   - level: How well the person has it, if rated.
    public init(name: String, level: SkillLevel? = nil) { self.name = name; self.level = level }
}

/// How well the user speaks a language, by CEFR level or as a native.
public struct LanguageSkill: Hashable, Sendable {
    /// The language, as the user names it, such as "Italian". Not the document language of a CV.
    public var language: String
    /// How well the person speaks it.
    public var proficiency: LanguageProficiency

    /// - Parameters:
    ///   - language: The language, as the user names it.
    ///   - proficiency: How well the person speaks it.
    public init(language: String, proficiency: LanguageProficiency) { self.language = language; self.proficiency = proficiency }
}

/// A certification, with the month or year it was issued and a link to it if there are any.
public struct Certification: Hashable, Sendable {
    /// What was certified.
    public var name: String
    /// Who issued it.
    public var issuer: String
    /// When it was issued, if known.
    public var issued: PartialDate?
    /// Where it can be checked, if given.
    public var link: WebLink?
    /// What the certification covers.
    public var description: String

    /// Every parameter is the value of the property of the same name; only the name and the issuer are required.
    public init(name: String, issuer: String, issued: PartialDate? = nil, link: WebLink? = nil, description: String = "") {
        self.name = name; self.issuer = issuer; self.issued = issued; self.link = link; self.description = description
    }
}

/// A public profile, such as GitHub or LinkedIn. It exists only with a valid link.
public struct ProfileLink: Hashable, Sendable {
    /// The service, such as "GitHub".
    public var platform: String
    /// The address of the profile.
    public var link: WebLink

    /// - Parameters:
    ///   - platform: The service.
    ///   - link: The address of the profile.
    public init(platform: String, link: WebLink) { self.platform = platform; self.link = link }
}

// MARK: - Sections

/// The sections of a CV, each an ordered list of entries. Order within a section is the order the user chose.
public struct CVSections: Hashable, Sendable {
    /// Jobs, in the order the user chose.
    public var experiences: [Experience]
    /// Courses of study, in the order the user chose.
    public var education: [Education]
    /// Skills, in the order the user chose.
    public var skills: [Skill]
    /// Languages the user speaks, in the order the user chose.
    public var languages: [LanguageSkill]
    /// Certifications, in the order the user chose.
    public var certifications: [Certification]
    /// Public profiles, in the order the user chose.
    public var profiles: [ProfileLink]
    /// The interests, normalised when they were made.
    public var interests: Interests

    /// No entry in any section.
    public static let empty = CVSections()

    /// Every parameter is the value of the property of the same name, and none is required.
    public init(experiences: [Experience] = [], education: [Education] = [], skills: [Skill] = [], languages: [LanguageSkill] = [],
                certifications: [Certification] = [], profiles: [ProfileLink] = [], interests: Interests = []) {
        self.experiences = experiences; self.education = education; self.skills = skills; self.languages = languages
        self.certifications = certifications; self.profiles = profiles; self.interests = interests
    }
}
