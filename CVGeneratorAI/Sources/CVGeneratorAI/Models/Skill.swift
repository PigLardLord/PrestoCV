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
    @Guide(description: "Name of the skill or technology (e.g., 'Swift', 'SwiftUI', 'Git')")
    public let name: String

    @Guide(description: "Proficiency level for this skill")
    public let level: SkillLevel

    @Guide(description: "Category like 'Programming Languages', 'Frameworks', 'Tools', 'Architecture'")
    public let category: String?

    @Guide(description: "Years of experience with this skill (optional)")
    public let yearsOfExperience: Int?

    public init(
        name: String,
        level: SkillLevel,
        category: String? = nil,
        yearsOfExperience: Int? = nil
    ) {
        self.name = name
        self.level = level
        self.category = category
        self.yearsOfExperience = yearsOfExperience
    }
}
#endif
