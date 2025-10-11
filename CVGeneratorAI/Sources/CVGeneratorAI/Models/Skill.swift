import Foundation

/// Skill entry
public struct Skill: Codable, Equatable, Sendable {
    public let name: String
    public let level: SkillLevel
    public let category: String?
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

/// Skill proficiency level
public enum SkillLevel: String, Codable, CaseIterable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}
