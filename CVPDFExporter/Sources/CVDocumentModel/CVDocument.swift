import Foundation   // value types only

/// Published language of the exporter: the only input rendering accepts, and the JSON a backend accepts.
/// Its JSON shape is hand-written (a `kind` discriminator per section) and versioned.
public struct CVDocument: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public var language: String            // BCP 47, e.g. "it", "en-GB"
    public var person: Person
    public var sections: [Section]

    public init(language: String, person: Person, sections: [Section]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.language = language; self.person = person; self.sections = sections
    }

    enum CodingKeys: String, CodingKey { case schemaVersion, language, person, sections }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: c, debugDescription: "unsupported schemaVersion \(version)")
        }
        schemaVersion = version
        language = try c.decode(String.self, forKey: .language)
        person = try c.decode(Person.self, forKey: .person)
        sections = try c.decode([Section].self, forKey: .sections)
    }
}

public struct Person: Codable, Sendable, Equatable {
    public var name: String
    public var professionalTitle: String?
    public var email: String?
    public var phone: String?
    public var location: String?
    public var website: String?
    public init(name: String, professionalTitle: String? = nil, email: String? = nil, phone: String? = nil,
                location: String? = nil, website: String? = nil) {
        self.name = name; self.professionalTitle = professionalTitle; self.email = email
        self.phone = phone; self.location = location; self.website = website
    }
}

public struct CertificationItem: Codable, Sendable, Equatable {
    public var name: String, issuer: String, year: Int?, url: String?, description: String?
    public init(name: String, issuer: String, year: Int? = nil, url: String? = nil, description: String? = nil) {
        self.name = name; self.issuer = issuer; self.year = year; self.url = url; self.description = description
    }
}

/// A date with year or month precision. Formatting is the renderer's job, in the document language.
public struct DocumentDate: Codable, Sendable, Equatable {
    public var year: Int, month: Int?
    public init(year: Int, month: Int? = nil) { self.year = year; self.month = month }
}

/// The end of a period is explicit: "present", a date, or ended-but-unspecified. Never a display string.
public enum PeriodEnd: Sendable, Equatable { case present, date(DocumentDate), unspecified }

public struct DocumentPeriod: Codable, Sendable, Equatable {
    public var start: DocumentDate, end: PeriodEnd
    public init(start: DocumentDate, end: PeriodEnd) { self.start = start; self.end = end }

    enum CodingKeys: String, CodingKey { case start, end, endDate }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decode(DocumentDate.self, forKey: .start)
        switch try c.decode(String.self, forKey: .end) {
        case "present": end = .present
        case "unspecified": end = .unspecified
        case "date": end = .date(try c.decode(DocumentDate.self, forKey: .endDate))
        case let other: throw DecodingError.dataCorruptedError(forKey: .end, in: c, debugDescription: "unknown end \(other)")
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(start, forKey: .start)
        switch end {
        case .present: try c.encode("present", forKey: .end)
        case .unspecified: try c.encode("unspecified", forKey: .end)
        case .date(let d): try c.encode("date", forKey: .end); try c.encode(d, forKey: .endDate)
        }
    }
}

public struct ExperienceItem: Codable, Sendable, Equatable {
    public var role: String, company: String, location: String?, period: DocumentPeriod?, description: String?
    public init(role: String, company: String, location: String? = nil, period: DocumentPeriod? = nil, description: String? = nil) {
        self.role = role; self.company = company; self.location = location; self.period = period; self.description = description
    }
}

public struct EducationItem: Codable, Sendable, Equatable {
    public var degree: String, school: String, period: DocumentPeriod?, description: String?
    public init(degree: String, school: String, period: DocumentPeriod? = nil, description: String? = nil) {
        self.degree = degree; self.school = school; self.period = period; self.description = description
    }
}

public struct SkillItem: Codable, Sendable, Equatable {
    public var name: String, rating: Int?   // 1...5, nil = not rated
    public init(name: String, rating: Int? = nil) { self.name = name; self.rating = rating }
}

public struct LanguageItem: Codable, Sendable, Equatable {
    public enum Level: String, Codable, Sendable, CaseIterable { case a1, a2, b1, b2, c1, c2, native }
    public var language: String, level: Level
    public init(language: String, level: Level) { self.language = language; self.level = level }
}

public struct ProfileLink: Codable, Sendable, Equatable {
    public var platform: String, url: String
    public init(platform: String, url: String) { self.platform = platform; self.url = url }
}

/// Sections are identified by type, never by title. JSON: {"kind": "...", "items": [...]} or {"kind":"summary","text":"..."}.
public enum Section: Codable, Sendable, Equatable {
    case summary(String)
    case experience([ExperienceItem])
    case education([EducationItem])
    case skills([SkillItem])
    case languages([LanguageItem])
    case certifications([CertificationItem])
    case profiles([ProfileLink])
    case interests([String])

    enum CodingKeys: String, CodingKey { case kind, text, items }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "summary": self = .summary(try c.decode(String.self, forKey: .text))
        case "experience": self = .experience(try c.decode([ExperienceItem].self, forKey: .items))
        case "education": self = .education(try c.decode([EducationItem].self, forKey: .items))
        case "skills": self = .skills(try c.decode([SkillItem].self, forKey: .items))
        case "languages": self = .languages(try c.decode([LanguageItem].self, forKey: .items))
        case "certifications": self = .certifications(try c.decode([CertificationItem].self, forKey: .items))
        case "profiles": self = .profiles(try c.decode([ProfileLink].self, forKey: .items))
        case "interests": self = .interests(try c.decode([String].self, forKey: .items))
        case let other: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown section \(other)")
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .summary(let t): try c.encode("summary", forKey: .kind); try c.encode(t, forKey: .text)
        case .experience(let i): try c.encode("experience", forKey: .kind); try c.encode(i, forKey: .items)
        case .education(let i): try c.encode("education", forKey: .kind); try c.encode(i, forKey: .items)
        case .skills(let i): try c.encode("skills", forKey: .kind); try c.encode(i, forKey: .items)
        case .languages(let i): try c.encode("languages", forKey: .kind); try c.encode(i, forKey: .items)
        case .certifications(let i): try c.encode("certifications", forKey: .kind); try c.encode(i, forKey: .items)
        case .profiles(let i): try c.encode("profiles", forKey: .kind); try c.encode(i, forKey: .items)
        case .interests(let i): try c.encode("interests", forKey: .kind); try c.encode(i, forKey: .items)
        }
    }
}

/// Anti-corruption layer for documents arriving from outside (a backend request, a file). R8.
public enum CVDocumentValidator {
    public struct Invalid: Error, Equatable, Sendable { public let reason: String }
    /// Bounds in UTF-8 bytes, not characters: a letter followed by any number of combining marks is one character.
    static let maxTextBytes = 16_384, maxDocumentTextBytes = 262_144, maxItems = 200
    /// The largest JSON document `decode` accepts, checked before decoding.
    public static let maxJSONBytes = 1_048_576

    /// The entry point for a document that arrives as JSON (a backend request, a file): the size is checked before
    /// decoding, and the decoded document is validated.
    public static func decode(json: Data) throws(Invalid) -> CVDocument {
        guard json.count <= maxJSONBytes else { throw Invalid(reason: "document is too large") }
        let document: CVDocument
        do { document = try JSONDecoder().decode(CVDocument.self, from: json) } catch { throw Invalid(reason: "not a CV document") }
        try validate(document)
        return document
    }

    /// Explicit bidirectional embeddings, overrides and isolates reorder what is printed, so they are refused.
    static func reordersText(_ s: Unicode.Scalar) -> Bool { (0x202A...0x202E).contains(s.value) || (0x2066...0x2069).contains(s.value) }

    public static func validate(_ d: CVDocument) throws(Invalid) {
        var total = 0
        func text(_ s: String?, _ what: String) throws(Invalid) {
            guard let s else { return }
            total += s.utf8.count
            guard s.utf8.count <= maxTextBytes, total <= maxDocumentTextBytes,
                  !s.unicodeScalars.contains(where: { ($0.properties.generalCategory == .control && $0 != "\n") || reordersText($0) }) else {
                throw Invalid(reason: "\(what) is too long, the document is too large, or it has control characters")
            }
        }
        func count(_ n: Int, _ what: String) throws(Invalid) { if n > maxItems { throw Invalid(reason: "too many \(what)") } }
        func date(_ x: DocumentDate) throws(Invalid) {
            guard (1900...2200).contains(x.year), x.month.map({ (1...12).contains($0) }) ?? true else { throw Invalid(reason: "date") }
        }
        func period(_ p: DocumentPeriod?) throws(Invalid) {
            guard let p else { return }
            try date(p.start)
            if case .date(let e) = p.end {
                try date(e)
                if e.year < p.start.year || (e.year == p.start.year && (e.month ?? 12) < (p.start.month ?? 1)) { throw Invalid(reason: "end before start") }
            }
        }
        guard !d.person.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Invalid(reason: "name is required") }
        try text(d.language, "language"); try text(d.person.name, "name"); try text(d.person.professionalTitle, "title"); try text(d.person.email, "email")
        try text(d.person.phone, "phone"); try text(d.person.location, "location"); try text(d.person.website, "website")
        try count(d.sections.count, "sections")
        for s in d.sections {
            switch s {
            case .summary(let t): try text(t, "summary")
            case .experience(let items):
                try count(items.count, "entries")
                for i in items { try text(i.role, "role"); try text(i.company, "company"); try text(i.location, "location"); try text(i.description, "description"); try period(i.period) }
            case .education(let items):
                try count(items.count, "entries")
                for i in items { try text(i.degree, "degree"); try text(i.school, "school"); try text(i.description, "description"); try period(i.period) }
            case .skills(let items): try count(items.count, "skills"); for i in items { try text(i.name, "skill"); if let r = i.rating, !(1...5).contains(r) { throw Invalid(reason: "rating") } }
            case .languages(let items): try count(items.count, "languages"); for i in items { try text(i.language, "language") }
            case .certifications(let items):
                try count(items.count, "certifications")
                for i in items {
                    try text(i.name, "certification"); try text(i.issuer, "issuer"); try text(i.url, "url"); try text(i.description, "description")
                    if let y = i.year { try date(DocumentDate(year: y)) }
                }
            case .profiles(let items): try count(items.count, "profiles"); for i in items { try text(i.platform, "platform"); try text(i.url, "url") }
            case .interests(let items): try count(items.count, "interests"); for i in items { try text(i, "interest") }
            }
        }
    }
}
