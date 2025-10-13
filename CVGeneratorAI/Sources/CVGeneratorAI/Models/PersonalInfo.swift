#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Personal information section
@Generable
public struct PersonalInfo: Codable, Equatable, Sendable {
    @Guide(description: "Full name")
    public let name: String

    @Guide(description: "Email address")
    public let email: String

    @Guide(description: "Phone number if mentioned")
    public let phone: String?

    @Guide(description: "Location (city, country)")
    public let location: String?

    @Guide(description: "Personal website or portfolio URL")
    public let website: String?

    @Guide(description: "LinkedIn profile URL")
    public let linkedin: String?

    @Guide(description: "GitHub profile URL")
    public let github: String?

    @Guide(description: "Professional title or desired role")
    public let title: String?

    public init(
        name: String,
        email: String,
        phone: String? = nil,
        location: String? = nil,
        website: String? = nil,
        linkedin: String? = nil,
        github: String? = nil,
        title: String? = nil
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.website = website
        self.linkedin = linkedin
        self.github = github
        self.title = title
    }
}
#endif
