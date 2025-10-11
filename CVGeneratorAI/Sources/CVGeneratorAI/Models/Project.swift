import Foundation

/// Project entry
public struct Project: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let role: String?
    public let startDate: String?
    public let endDate: String?
    public let technologies: [String]
    public let url: String?
    public let achievements: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        role: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        technologies: [String] = [],
        url: String? = nil,
        achievements: [String] = []
    ) {
        self.id = id
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
