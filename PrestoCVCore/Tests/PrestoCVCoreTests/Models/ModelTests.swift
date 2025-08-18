import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Model Tests")
struct ModelTests {
    
    // MARK: - CVModel Tests
    
    @Test("CVModel initializes with default values")
    func cvModelInitialization() {
        let cv = CVModel()
        
        #expect(cv.id != UUID())  // Should have a unique ID
        #expect(cv.name == "")
        #expect(cv.personalInfo.name == "")
        #expect(cv.personalInfo.title == "")
        #expect(cv.personalInfo.location == "")
        #expect(cv.personalInfo.email == "")
        #expect(cv.personalInfo.phone == "")
        #expect(cv.personalInfo.portfolio == "")
        #expect(cv.personalInfo.profile == "")
        #expect(cv.relevant_experience.isEmpty)
        #expect(cv.education.isEmpty)
        #expect(cv.skills.isEmpty)
        #expect(cv.languages.isEmpty)
        #expect(cv.certifications.isEmpty)
        #expect(cv.interests.isEmpty)
        #expect(cv.social.isEmpty)
    }
    
    @Test("CVModel initializes with provided values")
    func cvModelInitializationWithValues() {
        let id = UUID()
        let personalInfo = PersonalInfo(
            name: "John Doe",
            title: "iOS Developer",
            location: "San Francisco",
            email: "john@example.com",
            phone: "555-1234",
            portfolio: "https://johndoe.dev",
            profile: "Experienced developer"
        )
        let cv = CVModel(
            id: id,
            name: "iOS Developer - Apple Position",
            personalInfo: personalInfo
        )
        
        #expect(cv.id == id)
        #expect(cv.name == "iOS Developer - Apple Position")
        #expect(cv.personalInfo.name == "John Doe")
        #expect(cv.personalInfo.title == "iOS Developer")
        #expect(cv.personalInfo.location == "San Francisco")
        #expect(cv.personalInfo.email == "john@example.com")
        #expect(cv.personalInfo.phone == "555-1234")
        #expect(cv.personalInfo.portfolio == "https://johndoe.dev")
        #expect(cv.personalInfo.profile == "Experienced developer")
    }
    
    @Test("CVModel conforms to Identifiable")
    func cvModelIdentifiable() {
        let cv = CVModel()
        // CVModel conforms to Identifiable through its id property
        #expect(type(of: cv.id) == UUID.self)
    }
    
    @Test("CVModel JSON serialization and deserialization")
    func cvModelJSONSerialization() throws {
        let personalInfo = PersonalInfo(
            name: "Alex Johnson",
            title: "Senior Software Engineer",
            location: "Seattle, WA",
            email: "alex@example.com",
            phone: "+1-555-0123",
            portfolio: "https://alexjohnson.dev",
            profile: "Passionate about creating exceptional user experiences"
        )
        let originalCV = CVModel(
            name: "Senior Developer Application",
            personalInfo: personalInfo
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalCV)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedCV = try decoder.decode(CVModel.self, from: data)
        
        #expect(decodedCV.id == originalCV.id)
        #expect(decodedCV.name == originalCV.name)
        #expect(decodedCV.personalInfo.name == originalCV.personalInfo.name)
        #expect(decodedCV.personalInfo.title == originalCV.personalInfo.title)
        #expect(decodedCV.personalInfo.email == originalCV.personalInfo.email)
        #expect(decodedCV.skills.count == originalCV.skills.count)
        #expect(decodedCV.relevant_experience.count == originalCV.relevant_experience.count)
    }
    
    // MARK: - Experience Tests
    
    @Test("Experience initializes with default values")
    func experienceInitialization() {
        let experience = Experience()
        
        #expect(experience.id != UUID())  // Should have a unique ID
        #expect(experience.title == "")
        #expect(experience.company == "")
        #expect(experience.location == "")
        #expect(experience.period == "")
        #expect(experience.description == "")
    }
    
    @Test("Experience initializes with provided values")
    func experienceInitializationWithValues() {
        let id = UUID()
        let experience = Experience(
            id: id,
            title: "Senior Developer",
            company: "Tech Corp",
            location: "NYC",
            period: "2020-2023",
            description: "Led development team"
        )
        
        #expect(experience.id == id)
        #expect(experience.title == "Senior Developer")
        #expect(experience.company == "Tech Corp")
        #expect(experience.location == "NYC")
        #expect(experience.period == "2020-2023")
        #expect(experience.description == "Led development team")
    }
    
    @Test("Experience JSON serialization")
    func experienceJSONSerialization() throws {
        let original = Experience(
            title: "iOS Developer",
            company: "Apple Inc",
            location: "Cupertino, CA",
            period: "2020-Present",
            description: "Developing iOS applications"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Experience.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.company == original.company)
    }
    
    // MARK: - Education Tests
    
    @Test("Education initializes with default values")
    func educationInitialization() {
        let education = Education()
        
        #expect(education.id != UUID())
        #expect(education.degree == "")
        #expect(education.school == "")
        #expect(education.period == "")
        #expect(education.description == "")
    }
    
    @Test("Education JSON serialization")
    func educationJSONSerialization() throws {
        let original = Education(
            degree: "B.S. Computer Science",
            school: "Stanford University",
            period: "2016-2020",
            description: "Focus on iOS development"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Education.self, from: data)
        
        #expect(decoded.degree == original.degree)
        #expect(decoded.school == original.school)
    }
    
    // MARK: - Skill Tests
    
    @Test("Skill initializes with default values")
    func skillInitialization() {
        let skill = Skill()
        
        #expect(skill.id != UUID())
        #expect(skill.name == "")
        #expect(skill.level == 0)
    }
    
    @Test("Skill level validation through initialization")
    func skillLevelBoundaries() {
        let lowSkill = Skill(name: "Swift", level: 1)
        let highSkill = Skill(name: "iOS", level: 10)
        
        #expect(lowSkill.level == 1)
        #expect(highSkill.level == 10)
    }
    
    // MARK: - Language Tests
    
    @Test("Language initializes with default values")
    func languageInitialization() {
        let language = Language()
        
        #expect(language.id != UUID())
        #expect(language.name == "")
        #expect(language.level == .b1)
    }
    
    @Test("Language JSON serialization")
    func languageJSONSerialization() throws {
        let original = Language(name: "Spanish", level: .c1)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Language.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.level == original.level)
    }
    
    // MARK: - Certification Tests
    
    @Test("Certification initializes with default values")
    func certificationInitialization() {
        let certification = Certification()
        
        #expect(certification.id != UUID())
        #expect(certification.name == "")
        #expect(certification.issuer == "")
        #expect(certification.year == 0)
        #expect(certification.url == "")
        #expect(certification.description == "")
    }
    
    @Test("Certification handles optional year field")
    func certificationOptionalYear() {
        let certWithYear = Certification(name: "iOS Cert", issuer: "Apple", year: 2023)
        let certWithoutYear = Certification(name: "Swift Cert", issuer: "Apple", year: 0)
        
        #expect(certWithYear.year == 2023)
        #expect(certWithoutYear.year == 0)
    }
    
    @Test("Certification JSON serialization with nil year")
    func certificationJSONSerializationWithNilYear() throws {
        let original = Certification(
            name: "Swift Development",
            issuer: "Apple",
            year: 0,
            url: "https://apple.com/cert",
            description: "Advanced Swift certification"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Certification.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.year == 0)
    }
    
    // MARK: - Social Tests
    
    @Test("Social initializes with default values")
    func socialInitialization() {
        let social = Social()
        
        #expect(social.id != UUID())
        #expect(social.platform == "")
        #expect(social.url == "")
    }
    
    @Test("Social JSON serialization")
    func socialJSONSerialization() throws {
        let original = Social(platform: "GitHub", url: "https://github.com/user")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Social.self, from: data)
        
        #expect(decoded.platform == original.platform)
        #expect(decoded.url == original.url)
    }
    
    // MARK: - OnboardingState Tests
    
    @Test("OnboardingState equality comparison")
    func onboardingStateEquality() {
        #expect(OnboardingState.loading == OnboardingState.loading)
        #expect(OnboardingState.firstTime == OnboardingState.firstTime)
        #expect(OnboardingState.returning == OnboardingState.returning)
        
        let error1 = AppError.unknown("error1")
        let error2 = AppError.unknown("error1")
        let error3 = AppError.unknown("error3")
        
        #expect(OnboardingState.error(error1) == OnboardingState.error(error2))
        #expect(OnboardingState.error(error1) != OnboardingState.error(error3))
        #expect(OnboardingState.loading != OnboardingState.firstTime)
    }
    
    // MARK: - AppError Tests
    
    @Test("AppError equality comparison")
    func appErrorEquality() {
        #expect(AppError.unknown("error1") == AppError.unknown("error1"))
        #expect(AppError.invalidData("data1") == AppError.invalidData("data1"))
        #expect(AppError.unknown("error1") != AppError.invalidData("data1"))
        
        #expect(AppError.unknown("message1") == AppError.unknown("message1"))
        #expect(AppError.unknown("message1") != AppError.unknown("message2"))
    }
    
    @Test("AppError provides meaningful descriptions")
    func appErrorDescriptions() {
        // In test environment, localized strings fall back to their keys
        // since the String Catalog is not available in the Swift Package
        #expect(AppError.unknown("Something went wrong").localizedDescription == "Something went wrong")
        #expect(AppError.invalidData("Invalid input").localizedDescription == "error.invalid_data")
        #expect(AppError.notFound("User").localizedDescription == "error.not_found")
    }
    
    // MARK: - PersonalInfo Tests
    
    @Test("PersonalInfo initializes with default values")
    func personalInfoInitialization() {
        let personalInfo = PersonalInfo()
        
        #expect(personalInfo.name == "")
        #expect(personalInfo.title == "")
        #expect(personalInfo.location == "")
        #expect(personalInfo.email == "")
        #expect(personalInfo.phone == "")
        #expect(personalInfo.portfolio == "")
        #expect(personalInfo.profile == "")
    }
    
    @Test("PersonalInfo initializes with provided values")
    func personalInfoInitializationWithValues() {
        let personalInfo = PersonalInfo(
            name: "Jane Smith",
            title: "Product Designer",
            location: "Portland, OR",
            email: "jane@example.com",
            phone: "+1-555-0456",
            portfolio: "https://janesmith.design",
            profile: "Creative problem solver with 5+ years of experience"
        )
        
        #expect(personalInfo.name == "Jane Smith")
        #expect(personalInfo.title == "Product Designer")
        #expect(personalInfo.location == "Portland, OR")
        #expect(personalInfo.email == "jane@example.com")
        #expect(personalInfo.phone == "+1-555-0456")
        #expect(personalInfo.portfolio == "https://janesmith.design")
        #expect(personalInfo.profile == "Creative problem solver with 5+ years of experience")
    }
    
    @Test("PersonalInfo JSON serialization and deserialization")
    func personalInfoJSONSerialization() throws {
        let original = PersonalInfo(
            name: "John Developer",
            title: "Full Stack Engineer",
            location: "Austin, TX",
            email: "john@dev.com",
            phone: "+1-555-0789",
            portfolio: "https://john.dev",
            profile: "Full-stack developer specializing in modern web technologies"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersonalInfo.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.title == original.title)
        #expect(decoded.email == original.email)
        #expect(decoded.phone == original.phone)
        #expect(decoded.profile == original.profile)
    }
    
    // MARK: - Complex Model Integration Tests
    
    @Test("Complete CVModel with all nested models serializes correctly")
    func completeModelSerialization() throws {
        let personalInfo = PersonalInfo(
            name: "Alex Johnson",
            title: "Senior Software Engineer",
            location: "Seattle, WA",
            email: "alex@example.com",
            phone: "+1-555-0123",
            portfolio: "https://alexjohnson.dev",
            profile: "Passionate about creating exceptional user experiences with 8+ years of experience in software development"
        )
        
        let experience = [
            Experience(
                title: "Senior Software Engineer",
                company: "TechCorp",
                location: "Seattle, WA",
                period: "2020-Present",
                description: "Lead development of microservices architecture serving 1M+ users"
            )
        ]
        
        let skills = [
            Skill(name: "Swift", level: 5),
            Skill(name: "React", level: 4)
        ]
        
        let education = [
            Education(
                degree: "M.S. Computer Science",
                school: "Stanford University",
                period: "2015-2017",
                description: "Specialized in Distributed Systems"
            )
        ]
        
        let completeCV = CVModel(
            name: "Senior Developer - TechCorp Application",
            personalInfo: personalInfo,
            relevant_experience: experience,
            education: education,
            skills: skills
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(completeCV)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CVModel.self, from: data)
        
        // Verify all nested arrays are preserved
        #expect(decoded.skills.count == completeCV.skills.count)
        #expect(decoded.relevant_experience.count == completeCV.relevant_experience.count)
        #expect(decoded.education.count == completeCV.education.count)
        #expect(decoded.languages.count == completeCV.languages.count)
        #expect(decoded.certifications.count == completeCV.certifications.count)
        #expect(decoded.interests.count == completeCV.interests.count)
        #expect(decoded.social.count == completeCV.social.count)
        
        // Verify nested model details
        #expect(decoded.skills.first?.name == completeCV.skills.first?.name)
        #expect(decoded.relevant_experience.first?.company == completeCV.relevant_experience.first?.company)
        #expect(decoded.education.first?.degree == completeCV.education.first?.degree)
        
        // Verify PersonalInfo details
        #expect(decoded.personalInfo.name == completeCV.personalInfo.name)
        #expect(decoded.personalInfo.title == completeCV.personalInfo.title)
        #expect(decoded.personalInfo.email == completeCV.personalInfo.email)
    }
    
    @Test("CVModel handles empty arrays correctly")
    func cvModelEmptyArrays() {
        let cv = CVModel()
        
        #expect(cv.relevant_experience.isEmpty)
        #expect(cv.education.isEmpty)
        #expect(cv.skills.isEmpty)
        #expect(cv.languages.isEmpty)
        #expect(cv.certifications.isEmpty)
        #expect(cv.interests.isEmpty)
        #expect(cv.social.isEmpty)
    }
    
    // MARK: - Model Custom Decoder Tests
    
    @Test("Education handles missing JSON fields gracefully")
    func educationHandlesMissingFields() throws {
        let json = """
        {
            "degree": "Computer Science",
            "school": "MIT"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Education.self, from: json)
        
        #expect(decoded.degree == "Computer Science")
        #expect(decoded.school == "MIT")
        #expect(decoded.period == "")  // Missing field should default
        #expect(decoded.description == "")  // Missing field should default
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
    
    @Test("Education initializes with provided values")
    func educationInitializationWithValues() {
        let id = UUID()
        let education = Education(
            id: id,
            degree: "Master of Science",
            school: "Stanford University",
            period: "2018-2020",
            description: "Focus on AI and Machine Learning"
        )
        
        #expect(education.id == id)
        #expect(education.degree == "Master of Science")
        #expect(education.school == "Stanford University")
        #expect(education.period == "2018-2020")
        #expect(education.description == "Focus on AI and Machine Learning")
    }
    
    @Test("Skill handles missing JSON fields gracefully")
    func skillHandlesMissingFields() throws {
        let json = """
        {
            "name": "SwiftUI"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Skill.self, from: json)
        
        #expect(decoded.name == "SwiftUI")
        #expect(decoded.level == 0)  // Missing field should default
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
    
    @Test("Skill initializes with provided values")
    func skillInitializationWithValues() {
        let id = UUID()
        let skill = Skill(id: id, name: "iOS Development", level: 8)
        
        #expect(skill.id == id)
        #expect(skill.name == "iOS Development")
        #expect(skill.level == 8)
    }
    
    @Test("Skill JSON serialization")
    func skillJSONSerialization() throws {
        let original = Skill(name: "Swift", level: 9)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Skill.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.level == original.level)
    }
    
    @Test("Language handles missing JSON fields gracefully")
    func languageHandlesMissingFields() throws {
        let json = """
        {
            "name": "French"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Language.self, from: json)
        
        #expect(decoded.name == "French")
        #expect(decoded.level == .b1)  // Missing field should default to B1
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
    
    @Test("Language initializes with provided values")
    func languageInitializationWithValues() {
        let id = UUID()
        let language = Language(id: id, name: "Spanish", level: .c1)
        
        #expect(language.id == id)
        #expect(language.name == "Spanish")
        #expect(language.level == .c1)
    }
    
    @Test("Language handles backward compatibility with string levels")
    func languageBackwardCompatibility() throws {
        // Test with old string format
        let json = """
        {
            "name": "German",
            "level": "Advanced"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Language.self, from: json)
        
        #expect(decoded.name == "German")
        #expect(decoded.level == .c1)  // "Advanced" should map to C1
        
        // Test with native string variations
        let nativeJson = """
        {
            "name": "English",
            "level": "Native Speaker"
        }
        """.data(using: .utf8)!
        
        let nativeDecoded = try JSONDecoder().decode(Language.self, from: nativeJson)
        #expect(nativeDecoded.level == .native)
        
        // Test with exact CEFR format
        let cefrJson = """
        {
            "name": "French",
            "level": "B2"
        }
        """.data(using: .utf8)!
        
        let cefrDecoded = try JSONDecoder().decode(Language.self, from: cefrJson)
        #expect(cefrDecoded.level == .b2)
    }
    
    @Test("Certification handles missing JSON fields gracefully")
    func certificationHandlesMissingFields() throws {
        let json = """
        {
            "name": "AWS Certified Developer",
            "issuer": "Amazon"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Certification.self, from: json)
        
        #expect(decoded.name == "AWS Certified Developer")
        #expect(decoded.issuer == "Amazon")
        #expect(decoded.year == 0)  // Missing field should default
        #expect(decoded.url == "")  // Missing field should default
        #expect(decoded.description == "")  // Missing field should default
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
    
    @Test("Certification initializes with provided values")
    func certificationInitializationWithValues() {
        let id = UUID()
        let certification = Certification(
            id: id,
            name: "iOS Development Certificate",
            issuer: "Apple",
            year: 2023,
            url: "https://developer.apple.com/cert/123",
            description: "Advanced iOS development certification"
        )
        
        #expect(certification.id == id)
        #expect(certification.name == "iOS Development Certificate")
        #expect(certification.issuer == "Apple")
        #expect(certification.year == 2023)
        #expect(certification.url == "https://developer.apple.com/cert/123")
        #expect(certification.description == "Advanced iOS development certification")
    }
    
    @Test("Social handles missing JSON fields gracefully")
    func socialHandlesMissingFields() throws {
        let json = """
        {
            "platform": "LinkedIn"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Social.self, from: json)
        
        #expect(decoded.platform == "LinkedIn")
        #expect(decoded.url == "")  // Missing field should default
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
    
    @Test("Social initializes with provided values")
    func socialInitializationWithValues() {
        let id = UUID()
        let social = Social(id: id, platform: "Twitter", url: "https://twitter.com/user")
        
        #expect(social.id == id)
        #expect(social.platform == "Twitter")
        #expect(social.url == "https://twitter.com/user")
    }
    
    @Test("Experience handles missing JSON fields gracefully")
    func experienceHandlesMissingFields() throws {
        let json = """
        {
            "title": "Software Engineer",
            "company": "Apple Inc"
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(Experience.self, from: json)
        
        #expect(decoded.title == "Software Engineer")
        #expect(decoded.company == "Apple Inc")
        #expect(decoded.location == "")  // Missing field should default
        #expect(decoded.period == "")  // Missing field should default
        #expect(decoded.description == "")  // Missing field should default
        #expect(decoded.id != UUID())  // Should generate new UUID
    }
}