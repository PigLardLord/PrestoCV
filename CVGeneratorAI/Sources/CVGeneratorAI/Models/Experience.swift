#if canImport(FoundationModels)
import Foundation
import FoundationModels

@Generable
public struct Experience: Codable, Equatable, Sendable {
    @Guide(description: "Job title (e.g., 'Senior iOS Developer', 'Lead Engineer')")
    public let title: String

    @Guide(description: "EXACT company name - extract exactly as mentioned by user")
    public let company: String

    @Guide(description: "Location (city, country) if mentioned")
    public let location: String?

    @Guide(description: "Start date in format like 'August 2018', '2018', or 'Jan 2020'")
    public let startDate: String

    @Guide(description: "End date or null if current position")
    public let endDate: String?

    @Guide(description: "Is this a current position?")
    public let current: Bool

    @Guide(description: "Brief role description (1-2 sentences)")
    public let description: String

    @Guide(description: "Concise achievements with metrics. Start with strong action verbs.")
    @Guide(.count(2...5))
    public let achievements: [String]

    @Guide(description: "Specific technologies used (e.g., 'Swift', 'SwiftUI', 'Combine')")
    public let technologies: [String]

    public init(
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
#endif
