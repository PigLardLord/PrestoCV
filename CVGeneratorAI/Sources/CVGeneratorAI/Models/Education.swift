#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Education entry
@Generable
public struct Education: Codable, Equatable, Sendable {

    @Guide(description: "Degree type and field (e.g., 'Bachelor of Science in Computer Science', 'Master of Business Administration')")
    public let degree: String

    @Guide(description: "EXACT institution name - extract exactly as mentioned by user")
    public let institution: String

    @Guide(description: "Location (city, country) if mentioned")
    public let location: String?

    @Guide(description: "Start year (e.g., '2015')")
    public let startDate: String

    @Guide(description: "End year (e.g., '2019') or null if still studying")
    public let endDate: String?

    @Guide(description: "GPA if mentioned (e.g., '3.8/4.0', 'Summa Cum Laude')")
    public let gpa: String?

    @Guide(description: "Additional details about the program")
    public let description: String?

    @Guide(description: "Academic achievements, honors, awards")
    public let achievements: [String]

    public init(
        degree: String,
        institution: String,
        location: String? = nil,
        startDate: String,
        endDate: String? = nil,
        gpa: String? = nil,
        description: String? = nil,
        achievements: [String] = []
    ) {
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
#endif
