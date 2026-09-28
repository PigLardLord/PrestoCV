import Foundation   // value types only (R2): UUID and Date as types, never UUID() / Date()

public struct CVID: Hashable, Sendable, Codable { public let raw: UUID; public init(_ raw: UUID) { self.raw = raw } }

/// Bounded value object: invalid levels cannot exist (R6).
public struct SkillLevel: Hashable, Sendable {
    public let value: Int
    public init?(_ value: Int) { guard (1...5).contains(value) else { return nil }; self.value = value }
}

/// Year, or year and month. Only a partial order exists between dates of different precision.
public struct PartialDate: Hashable, Sendable {
    public let year: Int, month: Int?
    public init?(year: Int, month: Int? = nil) {
        guard (1900...2200).contains(year), month.map({ (1...12).contains($0) }) ?? true else { return nil }
        self.year = year; self.month = month
    }
    /// "May 2020 – 2020" is ordered: months are compared only when both are known.
    public func isNotAfter(_ other: PartialDate) -> Bool {
        if year != other.year { return year < other.year }
        guard let a = month, let b = other.month else { return true }
        return a <= b
    }
}

/// `.unknown` means the period has ended but its end date was not given; it is never invented.
public enum PeriodEnd: Hashable, Sendable { case current, date(PartialDate), unknown }

public enum PeriodError: Error, Equatable, Sendable {
    case invalidDate, endWithoutStart, currentWithoutStart, currentWithEndDate, endBeforeStart
}

public struct Period: Hashable, Sendable {
    public let start: PartialDate, end: PeriodEnd
    public init?(start: PartialDate, end: PeriodEnd) {
        if case .date(let e) = end, !start.isNotAfter(e) { return nil }
        self.start = start; self.end = end
    }

    /// The single rule for building a period from loose data (persistence, AI drafts): every
    /// combination is either a valid period, no period, or a typed error. Nothing is defaulted (R6).
    public static func make(start: (year: Int, month: Int?)?, end: (year: Int, month: Int?)?, current: Bool) throws(PeriodError) -> Period? {
        func date(_ d: (year: Int, month: Int?)) throws(PeriodError) -> PartialDate {
            guard let p = PartialDate(year: d.year, month: d.month) else { throw .invalidDate }
            return p
        }
        switch (start, end, current) {
        case (nil, nil, false): return nil
        case (nil, nil, true): throw .currentWithoutStart
        case (nil, .some(let e), _): _ = try date(e); throw .endWithoutStart
        case (.some, .some, true): throw .currentWithEndDate
        case (.some(let s), nil, true): return Period(start: try date(s), end: .current)
        case (.some(let s), nil, false): return Period(start: try date(s), end: .unknown)
        case (.some(let s), .some(let e), false):
            guard let p = Period(start: try date(s), end: .date(try date(e))) else { throw .endBeforeStart }
            return p
        }
    }
}

public struct EmailAddress: Hashable, Sendable {
    public let value: String
    public init?(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+\z"#, options: .regularExpression) != nil else { return nil }
        value = v
    }
}

public struct Experience: Hashable, Sendable {
    public var role: String, company: String, period: Period?, description: String
    public init(role: String, company: String, period: Period? = nil, description: String = "") {
        self.role = role; self.company = company; self.period = period; self.description = description
    }
}

public struct Skill: Hashable, Sendable {
    public var name: String, level: SkillLevel?
    public init(name: String, level: SkillLevel? = nil) { self.name = name; self.level = level }
}

/// Aggregate root: state changes go through methods (R6). Revision and timestamps belong to the
/// repository: they can only be set from inside the package (`package` access).
public struct CV: Hashable, Sendable {
    public let id: CVID
    public let revision: Int                 // 0 = never saved
    public let createdAt: Date?, updatedAt: Date?
    public private(set) var title: String
    public private(set) var fullName: String
    public private(set) var email: EmailAddress?
    public private(set) var experiences: [Experience]
    public private(set) var skills: [Skill]

    public init(id: CVID, title: String = "", fullName: String = "", email: EmailAddress? = nil,
                experiences: [Experience] = [], skills: [Skill] = []) {
        self.init(id: id, revision: 0, createdAt: nil, updatedAt: nil, title: title, fullName: fullName,
                  email: email, experiences: experiences, skills: skills)
    }

    package init(id: CVID, revision: Int, createdAt: Date?, updatedAt: Date?, title: String, fullName: String,
                 email: EmailAddress?, experiences: [Experience], skills: [Skill]) {
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.title = title; self.fullName = fullName; self.email = email; self.experiences = experiences; self.skills = skills
    }

    /// The same content as stored by a repository at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt ?? now, updatedAt: now, title: title, fullName: fullName,
           email: email, experiences: experiences, skills: skills)
    }

    /// The one definition of "has enough content to be saved".
    public var canBeSaved: Bool { !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public mutating func rename(_ newTitle: String) { title = newTitle }
    public mutating func setPerson(fullName: String, email: EmailAddress?) { self.fullName = fullName; self.email = email }
    public mutating func addExperience(_ e: Experience) { experiences.insert(e, at: 0) }   // newest first
    public mutating func addSkill(_ s: Skill) { skills.append(s) }

    /// Duplication rule. The new title is composed by presentation, which knows the language (R13).
    public func duplicated(as newID: CVID, title: String) -> CV {
        CV(id: newID, title: title, fullName: fullName, email: email, experiences: experiences, skills: skills)
    }
}
