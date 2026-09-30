// MARK: - The draft

/// A CV as a model drafted it from the user's description: plain values, optional wherever the user may not have
/// said it. Nothing is invented to fill a gap; the app maps the draft to a CV and reports every gap (ADR 0007).
public struct CVDraft: Hashable, Sendable {
    public var person: Person
    public var jobs: [Job]
    public var education: [Study]
    public var skills: [Skill]
    public var languages: [Language]
    public var certifications: [Certification]
    public var interests: [String]

    public init(person: Person = .init(), jobs: [Job] = [], education: [Study] = [], skills: [Skill] = [],
                languages: [Language] = [], certifications: [Certification] = [], interests: [String] = []) {
        self.person = person; self.jobs = jobs; self.education = education; self.skills = skills
        self.languages = languages; self.certifications = certifications; self.interests = interests
    }
}

// MARK: - Entries

extension CVDraft {
    /// Contact details and summary, as the user gave them: nothing here is checked yet.
    public struct Person: Hashable, Sendable {
        public var fullName: String?, professionalTitle: String?, email: String?, phone: String?
        public var location: String?, website: String?, summary: String?

        var texts: [String?] { [fullName, professionalTitle, email, phone, location, website, summary] }

        public init(fullName: String? = nil, professionalTitle: String? = nil, email: String? = nil, phone: String? = nil,
                    location: String? = nil, website: String? = nil, summary: String? = nil) {
            self.fullName = fullName; self.professionalTitle = professionalTitle; self.email = email; self.phone = phone
            self.location = location; self.website = website; self.summary = summary
        }
    }

    /// A year, and the month when the user said it. Its range is checked when the draft becomes a CV.
    public struct PartialDate: Hashable, Sendable {
        public var year: Int, month: Int?
        public init(year: Int, month: Int? = nil) { self.year = year; self.month = month }
    }

    /// A job. Dates the model could not find stay nil.
    public struct Job: Hashable, Sendable {
        public var role: String?, company: String?, location: String?, description: String?
        public var start: PartialDate?, end: PartialDate?, isCurrent: Bool

        var texts: [String?] { [role, company, location, description] }

        public init(role: String? = nil, company: String? = nil, location: String? = nil, description: String? = nil,
                    start: PartialDate? = nil, end: PartialDate? = nil, isCurrent: Bool = false) {
            self.role = role; self.company = company; self.location = location; self.description = description
            self.start = start; self.end = end; self.isCurrent = isCurrent
        }
    }

    /// A course of study. Dates the model could not find stay nil.
    public struct Study: Hashable, Sendable {
        public var degree: String?, school: String?, description: String?
        public var start: PartialDate?, end: PartialDate?, isCurrent: Bool

        var texts: [String?] { [degree, school, description] }

        public init(degree: String? = nil, school: String? = nil, description: String? = nil,
                    start: PartialDate? = nil, end: PartialDate? = nil, isCurrent: Bool = false) {
            self.degree = degree; self.school = school; self.description = description
            self.start = start; self.end = end; self.isCurrent = isCurrent
        }
    }

    /// A skill, and how well the user said they know it.
    public struct Skill: Hashable, Sendable {
        public enum Proficiency: Hashable, Sendable, CaseIterable { case beginner, intermediate, advanced, expert }
        public var name: String, proficiency: Proficiency?

        var texts: [String?] { [name] }

        public init(name: String, proficiency: Proficiency? = nil) { self.name = name; self.proficiency = proficiency }
    }

    /// A language the user speaks, and their level in it.
    public struct Language: Hashable, Sendable {
        /// The CEFR levels, plus native.
        public enum Level: Hashable, Sendable, CaseIterable { case a1, a2, b1, b2, c1, c2, native }
        public var name: String, level: Level?

        var texts: [String?] { [name] }

        public init(name: String, level: Level? = nil) { self.name = name; self.level = level }
    }

    /// A certification, who issued it and the year the user said.
    public struct Certification: Hashable, Sendable {
        public var name: String, issuer: String?, year: Int?

        var texts: [String?] { [name, issuer] }

        public init(name: String, issuer: String? = nil, year: Int? = nil) { self.name = name; self.issuer = issuer; self.year = year }
    }
}

// MARK: - What the limits look at

extension CVDraft {
    /// Every text the draft holds. A field added to the draft is added here, or the limits miss it: the tests hold an
    /// oversize case for every field, and the case of a field missing here fails.
    var texts: [String?] {
        var all = person.texts
        all += jobs.flatMap(\.texts)
        all += education.flatMap(\.texts)
        all += skills.flatMap(\.texts)
        all += languages.flatMap(\.texts)
        all += certifications.flatMap(\.texts)
        all += interests
        return all
    }

    /// The length of every list in the draft.
    var listLengths: [Int] {
        [jobs.count, education.count, skills.count, languages.count, certifications.count, interests.count]
    }

    /// True when no text in the draft has anything but white space: there is nothing to show or to map.
    var isBlank: Bool {
        texts.allSatisfy { ($0 ?? "").allSatisfy(\.isWhitespace) }
    }
}
