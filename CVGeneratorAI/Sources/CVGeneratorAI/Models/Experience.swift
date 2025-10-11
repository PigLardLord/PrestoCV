import Foundation

/// Work experience entry
public struct Experience: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let company: String
    public let location: String?
    public let startDate: String
    public let endDate: String?
    public let current: Bool
    public let description: String
    public let achievements: [String]
    public let technologies: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        company: String,
        location: String? = nil,
        startDate: String,
        endDate: String? = nil,
        current: Bool = false,
        description: String,
        achievements: [String] = [],
        technologies: [String] = []
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.current = current
        self.description = description
        self.achievements = achievements
        self.technologies = technologies
    }
}
