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

/// Skill entry
@Generable
public struct Skill: Codable, Equatable, Sendable {
    @Guide(description: "Name of the skill, as the person wrote it")
    public let name: String

    @Guide(description: "Level, only if the person described one; otherwise null")
    public let level: SkillLevel?

    public init(
        name: String,
        level: SkillLevel? = nil
    ) {
        self.name = name
        self.level = level
    }
}
#endif
