#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Skill proficiency level
@Generable
public enum SkillLevel: String, Codable, CaseIterable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}

/// What a skill is: a technology (a tool, a method, a body of knowledge of the trade) or a soft skill (a way of working with people
/// and tasks). The draft lists the technologies first (ADR 0031).
@Generable
public enum SkillKind: String, Codable, CaseIterable, Sendable {
    case technology
    case softSkill
}

/// Skill entry
@Generable
public struct Skill: Codable, Equatable, Sendable {
    @Guide(description: "Name of the skill, as the person wrote it")
    public let name: String

    @Guide(description: "Level, only if the person described one; otherwise null")
    public let level: SkillLevel?

    @Guide(description: "technology for a tool, method or knowledge of the trade; softSkill for a way of working with people and tasks")
    public let kind: SkillKind

    public init(
        name: String,
        level: SkillLevel? = nil,
        kind: SkillKind = .technology
    ) {
        self.name = name
        self.level = level
        self.kind = kind
    }
}
#endif
