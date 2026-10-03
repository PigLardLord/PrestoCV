/// A job. Its description is held as statements, one per line as written, split by `Statement.split`: the unit that a
/// tailored line names as its source (ADR 0013).
public struct SourceExperience: Hashable, Sendable {
    public let role: String
    public let company: String
    public let location: String
    public let period: TailoringPeriod?
    public let statements: [Statement]

    public init(role: String, company: String, location: String = "", period: TailoringPeriod? = nil,
                description: String = "") throws(TailoringModelError) {
        try Bounds.text(role, .role)
        try Bounds.text(company, .company)
        try Bounds.text(location, .location)
        let statements = Statement.split(description)
        try Bounds.count(statements.count, atMost: TailoringLimits.maxStatementsPerExperience, .statements)
        for statement in statements { try Bounds.text(statement.text, .statement) }
        self.role = role
        self.company = company
        self.location = location
        self.period = period
        self.statements = statements
    }
}
