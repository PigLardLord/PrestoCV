import Foundation

/// Result of CV tailoring analysis
public struct CVTailoringResult: Sendable, Equatable {
    public let suggestedSummary: String?
    public let relevantSkills: [String]
    public let missingSkills: [String]
    public let experienceOrder: [String] // IDs of experiences in suggested order
    public let highlightedAchievements: [String]
    public let matchScore: Double // 0.0 to 1.0 indicating how well the CV matches the job

    public init(
        suggestedSummary: String? = nil,
        relevantSkills: [String] = [],
        missingSkills: [String] = [],
        experienceOrder: [String] = [],
        highlightedAchievements: [String] = [],
        matchScore: Double = 0.0
    ) {
        self.suggestedSummary = suggestedSummary
        self.relevantSkills = relevantSkills
        self.missingSkills = missingSkills
        self.experienceOrder = experienceOrder
        self.highlightedAchievements = highlightedAchievements
        self.matchScore = matchScore
    }
}

/// Extracted job requirements from a job posting
public struct JobRequirements: Sendable, Equatable {
    public let requiredSkills: [String]
    public let preferredSkills: [String]
    public let yearsOfExperience: Int?
    public let educationLevel: String?
    public let keywords: [String]
    public let responsibilities: [String]

    public init(
        requiredSkills: [String] = [],
        preferredSkills: [String] = [],
        yearsOfExperience: Int? = nil,
        educationLevel: String? = nil,
        keywords: [String] = [],
        responsibilities: [String] = []
    ) {
        self.requiredSkills = requiredSkills
        self.preferredSkills = preferredSkills
        self.yearsOfExperience = yearsOfExperience
        self.educationLevel = educationLevel
        self.keywords = keywords
        self.responsibilities = responsibilities
    }
}

/// Protocol for AI-powered CV tailoring service
/// Will use Apple's Foundation Models framework for on-device processing
public protocol CVTailoringServiceProtocol: Sendable {
    /// Analyzes job description and tailors CV content
    /// - Parameters:
    ///   - jobDescription: The job posting text
    ///   - cvDocument: Current CV document
    ///   - targetRole: Target job role/title
    /// - Returns: Tailoring suggestions
    func tailorCV(
        jobDescription: String,
        cvDocument: CVDocument,
        targetRole: String?
    ) async throws -> CVTailoringResult

    /// Checks if the service is available on current device
    var isAvailable: Bool { get }
}