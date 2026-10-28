#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Work experience entry
///
/// Title and employer are always written, because the model leaves out jobs it is not made to name. Whatever the
/// description does not support is removed afterwards; the other details are null (or an empty list) when not said.
@Generable
public struct Experience: Codable, Equatable, Sendable {
    @Guide(description: "Job title, written as the person wrote it")
    public let title: String

    @Guide(description: "Employer, written as the person wrote it")
    public let company: String

    @Guide(description: "City or country of the job, only if the person said it; otherwise null")
    public let location: String?

    @Guide(description: "Start date exactly as written, only if the person said it; otherwise null")
    public let startDate: String?

    @Guide(description: "End date exactly as written; null if the person did not say it or still works there")
    public let endDate: String?

    @Guide(description: "True only if the person says they still work there")
    public let current: Bool

    @Guide(description: "One or two sentences about the role, using only what the person said; otherwise null")
    public let description: String?

    @Guide(description: "Things the person said they achieved, in their own words; empty if none were mentioned")
    public let achievements: [String]

    public init(
        title: String = "",
        company: String = "",
        location: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        current: Bool = false,
        description: String? = nil,
        achievements: [String] = []
    ) {
        self.title = title
        self.company = company
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.current = current
        self.description = description
        self.achievements = achievements
    }
}
#endif
