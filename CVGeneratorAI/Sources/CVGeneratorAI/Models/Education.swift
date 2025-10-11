import Foundation

/// Education entry
public struct Education: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let degree: String
    public let institution: String
    public let location: String?
    public let startDate: String
    public let endDate: String?
    public let gpa: String?
    public let description: String?
    public let achievements: [String]

    public init(
        id: UUID = UUID(),
        degree: String,
        institution: String,
        location: String? = nil,
        startDate: String,
        endDate: String? = nil,
        gpa: String? = nil,
        description: String? = nil,
        achievements: [String] = []
    ) {
        self.id = id
        self.degree = degree
        self.institution = institution
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.gpa = gpa
        self.description = description
        self.achievements = achievements
    }
}
