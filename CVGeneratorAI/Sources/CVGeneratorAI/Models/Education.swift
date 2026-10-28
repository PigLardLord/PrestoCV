#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Education entry
@Generable
public struct Education: Codable, Equatable, Sendable {
    @Guide(description: "Degree, course or subject studied exactly as written, never a word for a diploma alone; otherwise null")
    public let degree: String?

    @Guide(description: "School or university exactly as written, only if the person said it; otherwise null")
    public let institution: String?

    @Guide(description: "Start date exactly as written, only if the person said it; otherwise null")
    public let startDate: String?

    @Guide(description: "End date exactly as written; null if the person did not say it or is still studying")
    public let endDate: String?

    @Guide(description: "Extra details the person gave about the studies; otherwise null")
    public let description: String?

    public init(
        degree: String? = nil,
        institution: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        description: String? = nil
    ) {
        self.degree = degree
        self.institution = institution
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
    }
}
#endif
