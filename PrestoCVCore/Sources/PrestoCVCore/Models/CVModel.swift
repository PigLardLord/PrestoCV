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
    
    // Custom CodingKeys to handle JSON field naming
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case location
        case email
        case phone
        case portfolio
        case profile
        case relevant_experience
        case education
        case skills
        case languages
        case certifications
        case interests
        case social
    }
    
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
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        self.portfolio = try container.decodeIfPresent(String.self, forKey: .portfolio) ?? ""
        self.profile = try container.decodeIfPresent(String.self, forKey: .profile) ?? ""
        self.relevant_experience = try container.decodeIfPresent([Experience].self, forKey: .relevant_experience) ?? []
        self.education = try container.decodeIfPresent([Education].self, forKey: .education) ?? []
        self.skills = try container.decodeIfPresent([Skill].self, forKey: .skills) ?? []
        self.languages = try container.decodeIfPresent([Language].self, forKey: .languages) ?? []
        self.certifications = try container.decodeIfPresent([Certification].self, forKey: .certifications) ?? []
        self.interests = try container.decodeIfPresent([String].self, forKey: .interests) ?? []
        self.social = try container.decodeIfPresent([Social].self, forKey: .social) ?? []
    }
}