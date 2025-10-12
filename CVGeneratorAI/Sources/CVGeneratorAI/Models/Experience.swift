import Foundation

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.company = try container.decode(String.self, forKey: .company)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.startDate = try container.decode(String.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        self.current = try container.decode(Bool.self, forKey: .current)
        self.description = try container.decode(String.self, forKey: .description)
        self.achievements = try container.decodeIfPresent([String].self, forKey: .achievements) ?? []
        self.technologies = try container.decodeIfPresent([String].self, forKey: .technologies) ?? []
    }
}
