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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.role = try container.decodeIfPresent(String.self, forKey: .role)
        self.startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        self.technologies = try container.decodeIfPresent([String].self, forKey: .technologies) ?? []
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.achievements = try container.decodeIfPresent([String].self, forKey: .achievements) ?? []
    }
}
