import Foundation

// MARK: - CV Models

public struct CVModel: Codable, Identifiable {
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

public struct Experience: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var company: String
    public var location: String
    public var period: String
    public var description: String
    
    public init(id: UUID = UUID(), title: String = "", company: String = "", location: String = "", period: String = "", description: String = "") {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.period = period
        self.description = description
    }
}

public struct Education: Codable, Identifiable {
    public var id: UUID
    public var degree: String
    public var school: String
    public var period: String
    public var description: String
    
    public init(id: UUID = UUID(), degree: String = "", school: String = "", period: String = "", description: String = "") {
        self.id = id
        self.degree = degree
        self.school = school
        self.period = period
        self.description = description
    }
}

public struct Skill: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var level: Int
    
    public init(id: UUID = UUID(), name: String = "", level: Int = 1) {
        self.id = id
        self.name = name
        self.level = level
    }
}

public struct Language: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var level: String
    
    public init(id: UUID = UUID(), name: String = "", level: String = "") {
        self.id = id
        self.name = name
        self.level = level
    }
}

public struct Certification: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var issuer: String
    public var year: Int?
    public var url: String
    public var description: String
    
    public init(id: UUID = UUID(), name: String = "", issuer: String = "", year: Int? = nil, url: String = "", description: String = "") {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.year = year
        self.url = url
        self.description = description
    }
}

public struct Social: Codable, Identifiable {
    public var id: UUID
    public var platform: String
    public var url: String
    
    public init(id: UUID = UUID(), platform: String = "", url: String = "") {
        self.id = id
        self.platform = platform
        self.url = url
    }
}

// MARK: - Supporting Types

public enum OnboardingState {
    case loading
    case firstTime
    case returning
    case error(AppError)
}

public enum AppError: LocalizedError {
    case fileSystemError(Error)
    case templateNotFound
    case invalidCVData
    case storageError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .templateNotFound:
            return "CV template not found"
        case .invalidCVData:
            return "Invalid CV data format"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

