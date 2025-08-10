import Foundation

// MARK: - CV Model

public struct CVModel: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var title: String
    public var location: String
    public var email: String
    public var phone: String
    public var portfolio: String
    public var profile: String
    public var relevant_experience: [Experience]
    public var education: [Education]
    public var skills: [Skill]
    public var languages: [Language]
    public var certifications: [Certification]
    public var interests: [String]
    public var social: [Social]
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        title: String = "",
        location: String = "",
        email: String = "",
        phone: String = "",
        portfolio: String = "",
        profile: String = "",
        relevant_experience: [Experience] = [],
        education: [Education] = [],
        skills: [Skill] = [],
        languages: [Language] = [],
        certifications: [Certification] = [],
        interests: [String] = [],
        social: [Social] = []
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.location = location
        self.email = email
        self.phone = phone
        self.portfolio = portfolio
        self.profile = profile
        self.relevant_experience = relevant_experience
        self.education = education
        self.skills = skills
        self.languages = languages
        self.certifications = certifications
        self.interests = interests
        self.social = social
    }
}