#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Project entry
@Generable
public struct Project: Codable, Equatable, Sendable {
    @Guide(description: "Project name")
    public let name: String

    @Guide(description: "Brief project description")
    public let description: String

    @Guide(description: "Your role in the project")
    public let role: String?

    @Guide(description: "Start date (e.g., '2022')")
    public let startDate: String?

    @Guide(description: "End date or null if ongoing")
    public let endDate: String?

    @Guide(description: "Technologies used in the project")
    public let technologies: [String]

    @Guide(description: "Project URL or repository link")
    public let url: String?

    @Guide(description: "Key achievements or outcomes")
    public let achievements: [String]

    public init(
        name: String,
        description: String,
        role: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        technologies: [String] = [],
        url: String? = nil,
        achievements: [String] = []
    ) {
        self.name = name
        self.description = description
        self.role = role
        self.startDate = startDate
        self.endDate = endDate
        self.technologies = technologies
        self.url = url
        self.achievements = achievements
    }
}
#endif
