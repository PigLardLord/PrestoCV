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
    
    /// Creates a new CV from an existing template with a new ID
    /// - Parameters:
    ///   - template: The CV to copy from
    ///   - newId: The UUID for the new CV (defaults to a new UUID)
    public init(from template: CVModel, newId: UUID = UUID()) {
        self = template
        self.id = newId
    }
    
    /// Creates a copy of this CV with a new ID and optional name modification
    /// - Parameters:
    ///   - newId: The UUID for the new CV (defaults to a new UUID)
    ///   - nameModifier: Optional closure to modify the name (e.g., add " (Copy)")
    public func copy(newId: UUID = UUID(), nameModifier: ((String) -> String)? = nil) -> CVModel {
        var copy = CVModel(from: self, newId: newId)
        if let nameModifier = nameModifier {
            copy.name = nameModifier(copy.name)
        }
        return copy
    }
}