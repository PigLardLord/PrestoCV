/// Drafting's own model: plain Sendable structs, optional where the user may not have said it.
public struct CVDraft: Sendable, Equatable {
    /// Dates the model could not find stay nil; nothing is invented.
    public struct Job: Sendable, Equatable {
        public var role: String, company: String, startYear: Int?, endYear: Int?, isCurrent: Bool
        public init(role: String, company: String, startYear: Int?, endYear: Int?, isCurrent: Bool) {
            self.role = role; self.company = company; self.startYear = startYear; self.endYear = endYear; self.isCurrent = isCurrent
        }
    }
    public enum Proficiency: Sendable, Equatable { case beginner, intermediate, advanced, expert }
    public var fullName: String?, email: String?, jobs: [Job], skills: [(name: String, proficiency: Proficiency?)]
    public init(fullName: String?, email: String?, jobs: [Job], skills: [(name: String, proficiency: Proficiency?)]) {
        self.fullName = fullName; self.email = email; self.jobs = jobs; self.skills = skills
    }
    public static func == (a: Self, b: Self) -> Bool {
        a.fullName == b.fullName && a.email == b.email && a.jobs == b.jobs
            && a.skills.map(\.name) == b.skills.map(\.name) && a.skills.map(\.proficiency) == b.skills.map(\.proficiency)
    }
}

public enum DraftAvailability: Sendable, Equatable { case available, appleIntelligenceDisabled, deviceNotEligible, modelNotReady }

public protocol DraftGenerating: Sendable {
    func availability() async -> DraftAvailability
    func draft(from description: String, language: String) async throws -> CVDraft
}
