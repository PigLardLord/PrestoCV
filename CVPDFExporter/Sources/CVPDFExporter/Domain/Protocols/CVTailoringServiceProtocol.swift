import Foundation

/// Result of CV tailoring analysis
public struct CVTailoringResult: Sendable {
    public let suggestedSummary: String?
    public let relevantSkills: [String]
    public let missingSkills: [String]
    public let experienceOrder: [String] // IDs of experiences in suggested order
    public let highlightedAchievements: [String]

    public init(
        suggestedSummary: String? = nil,
        relevantSkills: [String] = [],
        missingSkills: [String] = [],
        experienceOrder: [String] = [],
        highlightedAchievements: [String] = []
    ) {
        self.suggestedSummary = suggestedSummary
        self.relevantSkills = relevantSkills
        self.missingSkills = missingSkills
        self.experienceOrder = experienceOrder
        self.highlightedAchievements = highlightedAchievements
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