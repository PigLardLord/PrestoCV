import Foundation

// MARK: - Internal CV Document

/// Simplified internal CV document structure
/// Used for internal processing and conversion to/from JSON Resume
public struct CVDocument: Codable, Equatable, Sendable, Hashable {
    public let personalInfo: PersonalInfo
    public let sections: [CVSection]
    public let metadata: DocumentMetadata
    
    public init(
        personalInfo: PersonalInfo,
        sections: [CVSection] = [],
        metadata: DocumentMetadata = DocumentMetadata()
    ) {
        self.personalInfo = personalInfo
        self.sections = sections
        self.metadata = metadata
    }
}

// MARK: - Personal Information

/// Personal information section of CV
public struct PersonalInfo: Codable, Equatable, Sendable, Hashable {
    public let name: String
    public let email: String
    public let phone: String?
    public let location: String?
    public let website: String?
    public let summary: String?
    public let title: String? // Professional title/role
    public let image: String? // URL or base64 data

    public init(
        name: String,
        email: String,
        phone: String? = nil,
        location: String? = nil,
        website: String? = nil,
        summary: String? = nil,
        title: String? = nil,
        image: String? = nil
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.website = website
        self.summary = summary
        self.title = title
        self.image = image
    }
}

// MARK: - CV Sections

/// Generic CV section that can hold various types of content
public struct CVSection: Codable, Equatable, Identifiable, Sendable, Hashable {
    public let id: String
    public let type: SectionType
    public let title: String
    public let items: [CVItem]
    public let order: Int
    public let visible: Bool
    
    public init(
        id: String = UUID().uuidString,
        type: SectionType,
        title: String,
        items: [CVItem] = [],
        order: Int = 0,
        visible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.items = items
        self.order = order
        self.visible = visible
    }
}

/// Types of CV sections
public enum SectionType: String, CaseIterable, Codable, Sendable {
    case work = "work"
    case education = "education"
    case skills = "skills"
    case languages = "languages"
    case certifications = "certifications"
    case projects = "projects"
    case awards = "awards"
    case publications = "publications"
    case volunteer = "volunteer"
    case interests = "interests"
    case references = "references"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .work: return "Work Experience"
        case .education: return "Education"
        case .skills: return "Skills"
        case .languages: return "Languages"
        case .certifications: return "Certifications"
        case .projects: return "Projects"
        case .awards: return "Awards"
        case .publications: return "Publications"
        case .volunteer: return "Volunteer"
        case .interests: return "Interests"
        case .references: return "References"
        case .custom: return "Custom Section"
        }
    }
}

// MARK: - CV Items

/// Individual items within CV sections
public struct CVItem: Codable, Equatable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let startDate: String?
    public let endDate: String?
    public let location: String?
    public let url: String?
    public let tags: [String]
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        location: String? = nil,
        url: String? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.url = url
        self.tags = tags
        self.metadata = metadata
    }
}

// MARK: - Document Metadata

/// Metadata about the CV document itself
public struct DocumentMetadata: Codable, Equatable, Sendable, Hashable {
    public let version: String
    public let createdAt: Date
    public let updatedAt: Date
    public let language: String
    public let customFields: [String: String]
    
    public init(
        version: String = "1.0",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        language: String = "en",
        customFields: [String: String] = [:]
    ) {
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.language = language
        self.customFields = customFields
    }
}
