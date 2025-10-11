import Foundation

/// Request for CV generation from user input
public struct CVGenerationRequest: Codable, Equatable, Sendable {
    /// Free-form text description from user about their background
    public let userPrompt: String

    /// Optional personal information to pre-fill
    public let personalInfo: PersonalInfo?

    /// Optional generation preferences
    public let preferences: GenerationPreferences

    public init(
        userPrompt: String,
        personalInfo: PersonalInfo? = nil,
        preferences: GenerationPreferences = GenerationPreferences()
    ) {
        self.userPrompt = userPrompt
        self.personalInfo = personalInfo
        self.preferences = preferences
    }
}

/// Preferences for CV generation
public struct GenerationPreferences: Codable, Equatable, Sendable {
    /// Target job role/industry
    public let targetRole: String?

    /// Experience level
    public let experienceLevel: ExperienceLevel

    /// Focus areas (e.g., technical skills, leadership, etc.)
    public let focusAreas: [String]

    /// Tone preference
    public let tone: Tone

    public init(
        targetRole: String? = nil,
        experienceLevel: ExperienceLevel = .intermediate,
        focusAreas: [String] = [],
        tone: Tone = .professional
    ) {
        self.targetRole = targetRole
        self.experienceLevel = experienceLevel
        self.focusAreas = focusAreas
        self.tone = tone
    }
}

/// Experience level for CV generation
public enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    case entry = "Entry Level"
    case intermediate = "Intermediate"
    case senior = "Senior"
    case executive = "Executive"
}

/// Tone for CV generation
public enum Tone: String, Codable, CaseIterable, Sendable {
    case professional = "Professional"
    case creative = "Creative"
    case technical = "Technical"
    case academic = "Academic"
}
