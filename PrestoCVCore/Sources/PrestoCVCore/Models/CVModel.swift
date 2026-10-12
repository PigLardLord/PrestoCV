import Foundation

// MARK: - CV Model

public struct CVModel: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String           // Job-specific CV name (e.g., "iOS Developer - Apple")
    public var personalInfo: PersonalInfo
    public var relevant_experience: [Experience]
    public var education: [Education]
    public var skills: [Skill]
    public var languages: [Language]
    public var certifications: [Certification]
    public var interests: [String]
    public var social: [Social]
    /// BCP 47 language of the exported document. Nil follows the language of the app.
    public var documentLanguage: String?
    
    // Custom CodingKeys to handle JSON field naming
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case personalInfo
        case relevant_experience
        case education
        case skills
        case languages
        case certifications
        case interests
        case social
        case documentLanguage
    }
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        personalInfo: PersonalInfo = PersonalInfo(),
        relevant_experience: [Experience] = [],
        education: [Education] = [],
        skills: [Skill] = [],
        languages: [Language] = [],
        certifications: [Certification] = [],
        interests: [String] = [],
        social: [Social] = [],
        documentLanguage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.personalInfo = personalInfo
        self.relevant_experience = relevant_experience
        self.education = education
        self.skills = skills
        self.languages = languages
        self.certifications = certifications
        self.interests = interests
        self.social = social
        self.documentLanguage = documentLanguage
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
        self.personalInfo = try container.decodeIfPresent(PersonalInfo.self, forKey: .personalInfo) ?? PersonalInfo()
        self.relevant_experience = try container.decodeIfPresent([Experience].self, forKey: .relevant_experience) ?? []
        self.education = try container.decodeIfPresent([Education].self, forKey: .education) ?? []
        self.skills = try container.decodeIfPresent([Skill].self, forKey: .skills) ?? []
        self.languages = try container.decodeIfPresent([Language].self, forKey: .languages) ?? []
        self.certifications = try container.decodeIfPresent([Certification].self, forKey: .certifications) ?? []
        self.interests = try container.decodeIfPresent([String].self, forKey: .interests) ?? []
        self.social = try container.decodeIfPresent([Social].self, forKey: .social) ?? []
        self.documentLanguage = try container.decodeIfPresent(String.self, forKey: .documentLanguage)
    }
}