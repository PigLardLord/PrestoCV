import Foundation

/// Personal information section
public struct PersonalInfo: Codable, Equatable, Sendable {
    public let name: String
    public let email: String
    public let phone: String?
    public let location: String?
    public let website: String?
    public let linkedin: String?
    public let github: String?
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
