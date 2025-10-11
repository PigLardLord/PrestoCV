import Foundation

/// Result of CV generation
public struct CVGenerationResult: Codable, Equatable, Sendable {
    /// Generated CV data
    public let cvData: CVData

    /// Confidence score (0.0 - 1.0)
    public let confidence: Double

    /// Any suggestions or warnings
    public let suggestions: [String]

    /// Processing metadata
    public let metadata: ResultMetadata

    public init(
        cvData: CVData,
        confidence: Double,
        suggestions: [String] = [],
        metadata: ResultMetadata = ResultMetadata()
    ) {
        self.cvData = cvData
        self.confidence = confidence
        self.suggestions = suggestions
        self.metadata = metadata
    }
}

/// Metadata about the generation result
public struct ResultMetadata: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let processingTime: TimeInterval
    public let modelVersion: String

    public init(
        generatedAt: Date = Date(),
        processingTime: TimeInterval = 0,
        modelVersion: String = "1.0"
    ) {
        self.generatedAt = generatedAt
        self.processingTime = processingTime
        self.modelVersion = modelVersion
    }
}
