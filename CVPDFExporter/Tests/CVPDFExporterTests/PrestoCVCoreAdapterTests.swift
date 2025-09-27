import XCTest
@testable import CVPDFExporter

final class PrestoCVCoreAdapterTests: XCTestCase {

    private var sut: PrestoCVCoreAdapter!

    override func setUp() {
        super.setUp()
        sut = PrestoCVCoreAdapter()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Adapter Tests

    func testConvertToCVReturnsValidDocument() {
        // Given
        let mockProfile: Any? = nil // Sprint 0 uses hardcoded data

        // When
        let document = sut.convertToCV(from: mockProfile)

        // Then
        XCTAssertNotNil(document)
        XCTAssertFalse(document.personalInfo.name.isEmpty)
        XCTAssertFalse(document.personalInfo.email.isEmpty)
        XCTAssertFalse(document.sections.isEmpty)
    }

    func testConvertToCVPersonalInfo() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        let info = document.personalInfo
        XCTAssertEqual(info.name, "John Doe")
        XCTAssertEqual(info.email, "john.doe@example.com")
        XCTAssertEqual(info.phone, "+1 (555) 123-4567")
        XCTAssertEqual(info.location, "San Francisco, CA")
        XCTAssertEqual(info.website, "https://linkedin.com/in/johndoe")
        XCTAssertNotNil(info.summary)
        XCTAssertTrue(info.summary!.contains("Software Engineer"))
    }

    func testConvertToCVWorkSection() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        let workSection = document.sections.first { $0.type == .work }
        XCTAssertNotNil(workSection)
        XCTAssertEqual(workSection?.title, "Work Experience")
        XCTAssertEqual(workSection?.items.count, 3)

        // Verify first work item
        if let firstItem = workSection?.items.first {
            XCTAssertEqual(firstItem.title, "Senior iOS Developer")
            XCTAssertEqual(firstItem.subtitle, "Tech Corp")
            XCTAssertNotNil(firstItem.description)
            XCTAssertEqual(firstItem.startDate, "Jan 2020")
            XCTAssertEqual(firstItem.endDate, "Present")
            XCTAssertEqual(firstItem.location, "San Francisco, CA")
            XCTAssertTrue(firstItem.tags.contains("Swift"))
            XCTAssertTrue(firstItem.tags.contains("SwiftUI"))
        }
    }

    func testConvertToCVEducationSection() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        let educationSection = document.sections.first { $0.type == .education }
        XCTAssertNotNil(educationSection)
        XCTAssertEqual(educationSection?.title, "Education")
        XCTAssertEqual(educationSection?.items.count, 1)

        // Verify education item
        if let eduItem = educationSection?.items.first {
            XCTAssertEqual(eduItem.title, "Bachelor of Science in Computer Science")
            XCTAssertEqual(eduItem.subtitle, "University of California, Berkeley")
            XCTAssertNotNil(eduItem.description)
            XCTAssertEqual(eduItem.startDate, "2011")
            XCTAssertEqual(eduItem.endDate, "2015")
        }
    }

    func testConvertToCVSkillsSection() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        let skillsSection = document.sections.first { $0.type == .skills }
        XCTAssertNotNil(skillsSection)
        XCTAssertEqual(skillsSection?.title, "Technical Skills")
        XCTAssertEqual(skillsSection?.items.count, 4)

        // Verify skill categories
        let titles = skillsSection?.items.map { $0.title } ?? []
        XCTAssertTrue(titles.contains("Languages & Frameworks"))
        XCTAssertTrue(titles.contains("Tools & Platforms"))
        XCTAssertTrue(titles.contains("Architecture & Design"))
        XCTAssertTrue(titles.contains("Soft Skills"))

        // Verify tags are present
        if let langItem = skillsSection?.items.first(where: { $0.title == "Languages & Frameworks" }) {
            XCTAssertTrue(langItem.tags.contains("Swift"))
            XCTAssertTrue(langItem.tags.contains("SwiftUI"))
        }
    }

    func testConvertToCVSectionOrder() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        XCTAssertEqual(document.sections.count, 3)

        // Verify sections are in correct order
        let sortedSections = document.sections.sorted { $0.order < $1.order }
        XCTAssertEqual(sortedSections[0].type, .work)
        XCTAssertEqual(sortedSections[0].order, 1)
        XCTAssertEqual(sortedSections[1].type, .education)
        XCTAssertEqual(sortedSections[1].order, 2)
        XCTAssertEqual(sortedSections[2].type, .skills)
        XCTAssertEqual(sortedSections[2].order, 3)
    }

    func testConvertToCVMetadata() {
        // When
        let document = sut.convertToCV(from: nil)

        // Then
        XCTAssertNotNil(document.metadata)
        XCTAssertNotNil(document.metadata.createdAt)
        XCTAssertNotNil(document.metadata.updatedAt)
        XCTAssertEqual(document.metadata.version, "1.0")
    }

    func testConvertToCVConsistency() {
        // When - Call multiple times
        let document1 = sut.convertToCV(from: nil)
        let document2 = sut.convertToCV(from: nil)

        // Then - Should return same data structure
        XCTAssertEqual(document1.personalInfo.name, document2.personalInfo.name)
        XCTAssertEqual(document1.sections.count, document2.sections.count)
        XCTAssertEqual(document1.sections[0].items.count, document2.sections[0].items.count)
    }

    // MARK: - Sprint 0 Specific Tests

    func testSprint0ReturnsHardcodedData() {
        // This test documents that Sprint 0 returns hardcoded data
        // Will need to be updated when actual PrestoCVCore integration is implemented

        // When
        let document = sut.convertToCV(from: "any input")

        // Then - Should ignore input and return hardcoded data
        XCTAssertEqual(document.personalInfo.name, "John Doe")
        XCTAssertEqual(document.personalInfo.email, "john.doe@example.com")
    }

    func testAdapterInitialization() {
        // Test that adapter can be initialized
        let adapter = PrestoCVCoreAdapter()
        XCTAssertNotNil(adapter)
    }
}
