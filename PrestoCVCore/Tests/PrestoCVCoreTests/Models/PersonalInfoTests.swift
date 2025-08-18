import Testing
import Foundation
@testable import PrestoCVCore

@Suite("PersonalInfo Tests")
struct PersonalInfoTests {
    
    @Test("PersonalInfo initializes with default values")
    func personalInfoDefaultInitialization() {
        let personalInfo = PersonalInfo()
        
        #expect(personalInfo.name == "")
        #expect(personalInfo.title == "")
        #expect(personalInfo.location == "")
        #expect(personalInfo.email == "")
        #expect(personalInfo.phone == "")
        #expect(personalInfo.portfolio == "")
        #expect(personalInfo.profile == "")
    }
    
    @Test("PersonalInfo initializes with custom values")
    func personalInfoCustomInitialization() {
        let personalInfo = PersonalInfo(
            name: "John Doe",
            title: "Software Engineer",
            location: "San Francisco, CA",
            email: "john@example.com",
            phone: "+1234567890",
            portfolio: "https://johndoe.dev",
            profile: "Experienced software engineer"
        )
        
        #expect(personalInfo.name == "John Doe")
        #expect(personalInfo.title == "Software Engineer")
        #expect(personalInfo.location == "San Francisco, CA")
        #expect(personalInfo.email == "john@example.com")
        #expect(personalInfo.phone == "+1234567890")
        #expect(personalInfo.portfolio == "https://johndoe.dev")
        #expect(personalInfo.profile == "Experienced software engineer")
    }
    
    @Test("PersonalInfo JSON encoding and decoding")
    func personalInfoJSONSerialization() throws {
        let original = PersonalInfo(
            name: "Jane Smith",
            title: "Product Designer",
            location: "New York, NY",
            email: "jane@example.com",
            phone: "+0987654321",
            portfolio: "https://janesmith.design",
            profile: "Creative product designer with 5 years experience"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersonalInfo.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.title == original.title)
        #expect(decoded.location == original.location)
        #expect(decoded.email == original.email)
        #expect(decoded.phone == original.phone)
        #expect(decoded.portfolio == original.portfolio)
        #expect(decoded.profile == original.profile)
    }
    
    @Test("PersonalInfo handles missing JSON fields gracefully")
    func personalInfoHandlesMissingFields() throws {
        let json = """
        {
            "name": "Partial Info",
            "email": "partial@example.com"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(PersonalInfo.self, from: json)
        
        #expect(decoded.name == "Partial Info")
        #expect(decoded.email == "partial@example.com")
        #expect(decoded.title == "")  // Missing field should default to empty
        #expect(decoded.location == "")  // Missing field should default to empty
        #expect(decoded.phone == "")  // Missing field should default to empty
        #expect(decoded.portfolio == "")  // Missing field should default to empty
        #expect(decoded.profile == "")  // Missing field should default to empty
    }
    
    @Test("CVModel with PersonalInfo JSON serialization")
    func cvModelWithPersonalInfoSerialization() throws {
        let personalInfo = PersonalInfo(
            name: "Alex Johnson",
            title: "Senior Developer",
            location: "Seattle, WA",
            email: "alex@example.com",
            phone: "+1122334455",
            portfolio: "https://alexjohnson.dev",
            profile: "Senior developer with expertise in iOS and backend systems"
        )
        
        let cv = CVModel(
            name: "Application for Senior Role",
            personalInfo: personalInfo,
            skills: [Skill(name: "Swift", level: 5)]
        )
        
        let data = try JSONEncoder().encode(cv)
        let decoded = try JSONDecoder().decode(CVModel.self, from: data)
        
        #expect(decoded.name == "Application for Senior Role")
        #expect(decoded.personalInfo.name == "Alex Johnson")
        #expect(decoded.personalInfo.title == "Senior Developer")
        #expect(decoded.personalInfo.email == "alex@example.com")
        #expect(decoded.skills.count == 1)
        #expect(decoded.skills.first?.name == "Swift")
    }
}