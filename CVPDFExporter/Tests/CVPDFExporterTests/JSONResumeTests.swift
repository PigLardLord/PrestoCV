import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - JSON Resume Tests (Sprint 5)

@Suite("JSON Resume Model")
struct JSONResumeTests {

    @Test("JSON Resume basics initialization")
    func jsonResumeBasicsInit() {
        // Given
        let basics = JSONResume.Basics(
            name: "John Doe",
            label: "Software Engineer",
            email: "john@example.com",
            phone: "+1 234 567 8900",
            url: "https://johndoe.com",
            summary: "Experienced developer",
            location: JSONResume.Location(
                address: "123 Main St",
                postalCode: "12345",
                city: "San Francisco",
                countryCode: "US",
                region: "CA"
            )
        )

        // Then
        #expect(basics.name == "John Doe")
        #expect(basics.label == "Software Engineer")
        #expect(basics.email == "john@example.com")
        #expect(basics.location?.city == "San Francisco")
    }

    @Test("JSON Resume work experience")
    func jsonResumeWorkExperience() {
        // Given
        let work = JSONResume.Work(
            name: "Tech Corp",
            position: "Senior Developer",
            url: "https://techcorp.com",
            startDate: "2020-01-01",
            endDate: "2023-12-31",
            summary: "Led development team",
            highlights: ["Built microservices", "Mentored juniors"]
        )

        // Then
        #expect(work.name == "Tech Corp")
        #expect(work.position == "Senior Developer")
        #expect(work.highlights?.count == 2)
        #expect(work.highlights?.first == "Built microservices")
    }

    @Test("JSON Resume education")
    func jsonResumeEducation() {
        // Given
        let education = JSONResume.Education(
            institution: "University of Technology",
            area: "Computer Science",
            studyType: "Bachelor",
            startDate: "2016",
            endDate: "2020",
            gpa: "3.8",
            courses: ["Data Structures", "Algorithms"]
        )

        // Then
        #expect(education.institution == "University of Technology")
        #expect(education.area == "Computer Science")
        #expect(education.studyType == "Bachelor")
        #expect(education.gpa == "3.8")
    }

    @Test("JSON Resume skills")
    func jsonResumeSkills() {
        // Given
        let skill = JSONResume.Skill(
            name: "Programming",
            level: "Expert",
            keywords: ["Swift", "Python", "JavaScript"]
        )

        // Then
        #expect(skill.name == "Programming")
        #expect(skill.level == "Expert")
        #expect(skill.keywords?.count == 3)
        #expect(skill.keywords?.contains("Swift") == true)
    }

    @Test("Complete JSON Resume document")
    func completeJSONResumeDocument() {
        // Given
        let resume = JSONResume(
            basics: JSONResume.Basics(
                name: "Jane Smith",
                label: "Designer",
                email: "jane@example.com"
            ),
            work: [
                JSONResume.Work(
                    name: "Design Co",
                    position: "UX Designer",
                    startDate: "2020"
                )
            ],
            education: [
                JSONResume.Education(
                    institution: "Art School",
                    area: "Design",
                    studyType: "BFA"
                )
            ],
            skills: [
                JSONResume.Skill(
                    name: "Design",
                    level: "Expert"
                )
            ]
        )

        // Then
        #expect(resume.basics?.name == "Jane Smith")
        #expect(resume.work?.count == 1)
        #expect(resume.education?.count == 1)
        #expect(resume.skills?.count == 1)
    }

    @Test("JSON Resume encoding and decoding")
    func jsonResumeEncodingDecoding() throws {
        // Given
        let resume = JSONResume(
            basics: JSONResume.Basics(
                name: "Test User",
                email: "test@example.com"
            )
        )

        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(resume)
        let jsonString = String(data: data, encoding: .utf8)

        // Then
        #expect(jsonString != nil)
        #expect(jsonString!.contains("\"name\" : \"Test User\""))
        #expect(jsonString!.contains("\"email\" : \"test@example.com\""))

        // Test decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONResume.self, from: data)
        #expect(decoded.basics?.name == "Test User")
    }

    @Test("JSON Resume with optional fields")
    func jsonResumeOptionalFields() {
        // Given - minimal resume with only required fields
        let resume = JSONResume()

        // Then
        #expect(resume.basics == nil)
        #expect(resume.work == nil)
        #expect(resume.education == nil)
        #expect(resume.skills == nil)
        #expect(resume.languages == nil)
        #expect(resume.interests == nil)
        #expect(resume.references == nil)
    }

    @Test("JSON Resume profile links")
    func jsonResumeProfileLinks() {
        // Given
        let profile = JSONResume.Profile(
            network: "LinkedIn",
            username: "johndoe",
            url: "https://linkedin.com/in/johndoe"
        )

        let basics = JSONResume.Basics(
            name: "John Doe",
            email: "john@example.com",
            profiles: [profile]
        )

        // Then
        #expect(basics.profiles?.count == 1)
        #expect(basics.profiles?.first?.network == "LinkedIn")
        #expect(basics.profiles?.first?.url == "https://linkedin.com/in/johndoe")
    }
}