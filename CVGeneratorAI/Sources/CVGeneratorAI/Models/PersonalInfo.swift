#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Personal information section
///
/// Every field is optional: a missing detail stays null instead of being made up.
@Generable
public struct PersonalInfo: Codable, Equatable, Sendable {
    @Guide(description: "Full name, only if the person gave it; otherwise null")
    public let name: String?

    @Guide(description: "Email address, only if the person gave it; otherwise null")
    public let email: String?

    @Guide(description: "Phone number, only if the person gave it; otherwise null")
    public let phone: String?

    @Guide(description: "City or country where the person lives, only if the person said it; otherwise null")
    public let location: String?

    @Guide(description: "Personal website address, only if the person gave it; otherwise null")
    public let website: String?

    @Guide(description: "LinkedIn profile address, only if the person gave it; otherwise null")
    public let linkedin: String?

    @Guide(description: "GitHub profile address, only if the person gave it; otherwise null")
    public let github: String?

    @Guide(description: "Professional title, only if the person said it; otherwise null")
    public let title: String?

    public init(
        name: String? = nil,
        email: String? = nil,
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
