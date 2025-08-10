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
        #expect(cv.title == "")
        #expect(cv.location == "")
        #expect(cv.email == "")
        #expect(cv.phone == "")
        #expect(cv.portfolio == "")
        #expect(cv.profile == "")
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
        let cv = CVModel(
            id: id,
            name: "John Doe",
            title: "iOS Developer",
            location: "San Francisco",
            email: "john@example.com",
            phone: "555-1234",
            portfolio: "https://johndoe.dev",
            profile: "Experienced developer"
        )
        
        #expect(cv.id == id)
        #expect(cv.name == "John Doe")
        #expect(cv.title == "iOS Developer")
        #expect(cv.location == "San Francisco")
        #expect(cv.email == "john@example.com")
        #expect(cv.phone == "555-1234")
        #expect(cv.portfolio == "https://johndoe.dev")
        #expect(cv.profile == "Experienced developer")
    }
    
    @Test("CVModel conforms to Identifiable")
    func cvModelIdentifiable() {
        let cv = CVModel()
        // CVModel conforms to Identifiable through its id property
        #expect(type(of: cv.id) == UUID.self)
    }
    
    @Test("CVModel JSON serialization and deserialization")
    func cvModelJSONSerialization() throws {
        let originalCV = CVTestDataBuilder.completeCV().build()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalCV)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedCV = try decoder.decode(CVModel.self, from: data)
        
        #expect(decodedCV.id == originalCV.id)
        #expect(decodedCV.name == originalCV.name)
        #expect(decodedCV.title == originalCV.title)
        #expect(decodedCV.email == originalCV.email)
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
        #expect(skill.level == 1)
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
        #expect(language.level == "")
    }
    
    @Test("Language JSON serialization")
    func languageJSONSerialization() throws {
        let original = Language(name: "Spanish", level: "Fluent")
        
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
        #expect(certification.year == nil)
        #expect(certification.url == "")
        #expect(certification.description == "")
    }
    
    @Test("Certification handles optional year field")
    func certificationOptionalYear() {
        let certWithYear = Certification(name: "iOS Cert", issuer: "Apple", year: 2023)
        let certWithoutYear = Certification(name: "Swift Cert", issuer: "Apple")
        
        #expect(certWithYear.year == 2023)
        #expect(certWithoutYear.year == nil)
    }
    
    @Test("Certification JSON serialization with nil year")
    func certificationJSONSerializationWithNilYear() throws {
        let original = Certification(
            name: "Swift Development",
            issuer: "Apple",
            year: nil,
            url: "https://apple.com/cert",
            description: "Advanced Swift certification"
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Certification.self, from: data)
        
        #expect(decoded.name == original.name)
        #expect(decoded.year == nil)
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
        
        let error1 = AppError.templateNotFound
        let error2 = AppError.templateNotFound
        let error3 = AppError.invalidCVData
        
        #expect(OnboardingState.error(error1) == OnboardingState.error(error2))
        #expect(OnboardingState.error(error1) != OnboardingState.error(error3))
        #expect(OnboardingState.loading != OnboardingState.firstTime)
    }
    
    // MARK: - AppError Tests
    
    @Test("AppError equality comparison")
    func appErrorEquality() {
        #expect(AppError.templateNotFound == AppError.templateNotFound)
        #expect(AppError.invalidCVData == AppError.invalidCVData)
        #expect(AppError.templateNotFound != AppError.invalidCVData)
        
        let error1 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error2 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error3 = NSError(domain: "other", code: 2, userInfo: [NSLocalizedDescriptionKey: "Other error"])
        
        #expect(AppError.fileSystemError(error1) == AppError.fileSystemError(error2))
        #expect(AppError.fileSystemError(error1) != AppError.fileSystemError(error3))
        
        #expect(AppError.storageError("message1") == AppError.storageError("message1"))
        #expect(AppError.storageError("message1") != AppError.storageError("message2"))
    }
    
    @Test("AppError provides meaningful descriptions")
    func appErrorDescriptions() {
        let fsError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        
        #expect(AppError.templateNotFound.errorDescription == "CV template not found")
        #expect(AppError.invalidCVData.errorDescription == "Invalid CV data format")
        #expect(AppError.storageError("Database connection failed").errorDescription == "Storage error: Database connection failed")
        #expect(AppError.fileSystemError(fsError).errorDescription?.contains("File not found") == true)
    }
    
    // MARK: - Complex Model Integration Tests
    
    @Test("Complete CVModel with all nested models serializes correctly")
    func completeModelSerialization() throws {
        let completeCV = CVTestDataBuilder.completeCV().build()
        
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
    }
    
    @Test("CVModel handles empty arrays correctly")
    func cvModelEmptyArrays() {
        let cv = CVTestDataBuilder.minimalCV().build()
        
        #expect(cv.relevant_experience.isEmpty)
        #expect(cv.education.isEmpty)
        #expect(cv.skills.isEmpty)
        #expect(cv.languages.isEmpty)
        #expect(cv.certifications.isEmpty)
        #expect(cv.interests.isEmpty)
        #expect(cv.social.isEmpty)
    }
}