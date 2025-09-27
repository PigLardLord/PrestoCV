import Foundation

// MARK: - Template Model

/// Represents a PDF template with HTML content and Mustache variables
public struct Template: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let htmlContent: String
    public let supportedVariables: [String]

    public init(
        id: String,
        name: String,
        description: String,
        htmlContent: String,
        supportedVariables: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.htmlContent = htmlContent
        self.supportedVariables = supportedVariables
    }
}

// MARK: - Template Error

public enum TemplateError: Error, Equatable, Sendable {
    case templateNotFound(String)
    case renderingFailed(String)
    case invalidTemplate(String)
}