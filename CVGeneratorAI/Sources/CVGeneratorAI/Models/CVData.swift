import Foundation

/// Core CV data model for AI generation
/// This model is designed to be flexible and AI-friendly
public struct CVData: Codable, Equatable, Sendable {
    public let id: UUID
    public let personalInfo: PersonalInfo
    public let summary: String?
    public let experience: [Experience]
    public let education: [Education]
    public let skills: [Skill]
    public let languages: [Language]
    public let certifications: [Certification]
    public let projects: [Project]
    public let interests: [String]
    public let metadata: CVMetadata

    public init(
        id: UUID = UUID(),
        personalInfo: PersonalInfo,
        summary: String? = nil,
        experience: [Experience] = [],
        education: [Education] = [],
        skills: [Skill] = [],
        languages: [Language] = [],
        certifications: [Certification] = [],
        projects: [Project] = [],
        interests: [String] = [],
        metadata: CVMetadata = CVMetadata()
    ) {
        self.id = id
        self.personalInfo = personalInfo
        self.summary = summary
        self.experience = experience
        self.education = education
        self.skills = skills
        self.languages = languages
        self.certifications = certifications
        self.projects = projects
        self.interests = interests
        self.metadata = metadata
    }
}

// MARK: - CV Metadata

public struct CVMetadata: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let generatedBy: String
    public let version: String

    public init(
        generatedAt: Date = Date(),
        generatedBy: String = "CVGeneratorAI",
        version: String = "1.0"
    ) {
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.version = version
    }
}
