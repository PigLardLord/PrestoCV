/// A job. Its statements are one per line of its description as written, made by `Statement.split`: the unit that a
/// tailored line names as its source (ADR 0013).
///
/// A snapshot travels as its statements and is never split again. A reference is an index into them, and the split is
/// not idempotent: "- - x" gives "- x", which gives "x". So the initialiser that takes statements keeps them as they
/// are, and the one that takes a description splits it once and calls that one.
public struct SourceExperience: Hashable, Sendable {
    public let role: String
    public let company: String
    public let location: String
    public let period: TailoringPeriod?
    public let statements: [Statement]

    /// An experience with the statements it already has, kept as they are and never split again. There are at most
    /// `TailoringLimits.maxStatementsPerExperience`, and each is at most `TailoringLimits.maxTextBytes` (R8).
    public init(role: String, company: String, location: String = "", period: TailoringPeriod? = nil,
                statements: [Statement]) throws(TailoringModelError) {
        try Bounds.text(role, .role)
        try Bounds.text(company, .company)
        try Bounds.text(location, .location)
        try Bounds.count(statements.count, atMost: TailoringLimits.maxStatementsPerExperience, .statements)
        for statement in statements { try Bounds.text(statement.text, .statement) }
        self.role = role
        self.company = company
        self.location = location
        self.period = period
        self.statements = statements
    }

    /// An experience from the description a person wrote: it is split once, by `Statement.split`, into the statements
    /// the experience then holds. A description over `TailoringLimits.maxTextBytes` is refused before it is split, so
    /// the cost of the split is bounded (R8).
    public init(role: String, company: String, location: String = "", period: TailoringPeriod? = nil,
                description: String = "") throws(TailoringModelError) {
        try Bounds.text(description, .description)
        try self.init(role: role, company: company, location: location, period: period, statements: Statement.split(description))
    }
}
