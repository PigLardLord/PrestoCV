import Foundation

// MARK: - Personal Information Model

public struct PersonalInfo: Codable, Sendable, Equatable {
    public var name: String      // User's full name
    public var title: String     // Professional title
    public var location: String
    public var email: String
    public var phone: String
    public var portfolio: String
    public var profile: String   // Professional summary/bio
    
    public init(
        name: String = "",
        title: String = "",
        location: String = "",
        email: String = "",
        phone: String = "",
        portfolio: String = "",
        profile: String = ""
    ) {
        self.name = name
        self.title = title
        self.location = location
        self.email = email
        self.phone = phone
        self.portfolio = portfolio
        self.profile = profile
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        self.portfolio = try container.decodeIfPresent(String.self, forKey: .portfolio) ?? ""
        self.profile = try container.decodeIfPresent(String.self, forKey: .profile) ?? ""
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case title
        case location
        case email
        case phone
        case portfolio
        case profile
    }
}