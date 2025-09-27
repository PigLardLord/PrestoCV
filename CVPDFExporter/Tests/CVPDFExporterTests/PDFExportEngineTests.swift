#if canImport(UIKit)
import XCTest
@testable import CVPDFExporter

@MainActor
final class PDFExportEngineTests: XCTestCase {

    private var sut: PDFExportEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = PDFExportEngineFactory.create()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Export Tests

    func testExportToPDFGeneratesData() async throws {
        // Given
        let document = createSampleDocument()
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.exportToPDF(document: document, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        XCTAssertTrue(pdfData.count > 1000, "PDF should have substantial content")
    }

    func testExportToPDFWithCustomOptions() async throws {
        // Given
        let document = createSampleDocument()
        let options = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36)
        )

        // When
        let pdfData = try await sut.exportToPDF(document: document, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)

        // Verify it's a valid PDF by checking the header
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        let headerRange = pdfData.prefix(4)
        XCTAssertEqual(headerRange, pdfHeader, "Data should start with PDF header")
    }

    func testExportToPDFWithEmptyDocument() async throws {
        // Given
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "", email: ""),
            sections: [],
            metadata: DocumentMetadata()
        )
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.exportToPDF(document: document, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty, "Even empty document should generate PDF")
    }

    func testExportToPDFWithComplexDocument() async throws {
        // Given
        let document = createComplexDocument()
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.exportToPDF(document: document, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(pdfData.count > 5000, "Complex document should generate larger PDF")
    }

    // MARK: - Performance Tests

    func testExportPerformance() async throws {
        let document = createSampleDocument()
        let options = ExportOptions.default

        // Measure time to export PDF
        let startTime = Date()
        _ = try await sut.exportToPDF(document: document, options: options)
        let endTime = Date()

        let timeInterval = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(timeInterval, 5.0, "PDF export should complete within 5 seconds")
    }

    // MARK: - Factory Tests

    func testPDFExportEngineFactoryCreatesInstance() {
        let engine = PDFExportEngineFactory.create()
        XCTAssertNotNil(engine)
        XCTAssertTrue(engine is PDFExportEngineImpl)
    }

    // MARK: - Helper Methods

    private func createSampleDocument() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com",
            phone: "+1234567890",
            location: "Test City",
            website: "https://example.com",
            summary: "Test summary for PDF export"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Experience",
            items: [
                CVItem(
                    title: "Senior Developer",
                    subtitle: "Tech Company",
                    description: "Developed applications",
                    startDate: "2020",
                    endDate: "Present"
                )
            ],
            order: 1
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workSection],
            metadata: DocumentMetadata()
        )
    }

    private func createComplexDocument() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "John Smith",
            email: "john.smith@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: "https://johnsmith.dev",
            summary: "Senior Software Engineer with 10+ years of experience in building scalable applications. Expertise in iOS development, system architecture, and team leadership. Passionate about clean code and user experience."
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Professional Experience",
            items: [
                CVItem(
                    title: "Senior iOS Engineer",
                    subtitle: "Tech Innovations Inc.",
                    description: "Led iOS development team of 5 engineers. Architected and implemented core features for flagship app with 5M+ users. Reduced app launch time by 60% through optimization.",
                    startDate: "Jan 2021",
                    endDate: "Present",
                    location: "San Francisco, CA",
                    tags: ["Swift", "SwiftUI", "Team Lead"]
                ),
                CVItem(
                    title: "iOS Developer",
                    subtitle: "StartupXYZ",
                    description: "Developed consumer iOS app from scratch. Implemented complex UI animations and real-time data synchronization.",
                    startDate: "Mar 2018",
                    endDate: "Dec 2020",
                    location: "New York, NY",
                    tags: ["UIKit", "Core Data", "REST APIs"]
                ),
                CVItem(
                    title: "Junior Developer",
                    subtitle: "Digital Solutions",
                    description: "Maintained and enhanced multiple client iOS applications.",
                    startDate: "Jun 2015",
                    endDate: "Feb 2018",
                    location: "Boston, MA",
                    tags: ["Objective-C", "iOS"]
                )
            ],
            order: 1
        )

        let educationSection = CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: [
                CVItem(
                    title: "Master of Computer Science",
                    subtitle: "Stanford University",
                    description: "Specialized in Mobile Computing and Human-Computer Interaction",
                    startDate: "2013",
                    endDate: "2015",
                    location: "Stanford, CA"
                ),
                CVItem(
                    title: "Bachelor of Science in Computer Science",
                    subtitle: "MIT",
                    description: "Graduated Magna Cum Laude, GPA: 3.9/4.0",
                    startDate: "2009",
                    endDate: "2013",
                    location: "Cambridge, MA"
                )
            ],
            order: 2
        )

        let skillsSection = CVSection(
            id: "skills",
            type: .skills,
            title: "Technical Skills",
            items: [
                CVItem(
                    title: "Programming Languages",
                    tags: ["Swift", "Objective-C", "Python", "JavaScript", "TypeScript"]
                ),
                CVItem(
                    title: "Frameworks & Tools",
                    tags: ["SwiftUI", "UIKit", "Combine", "Core Data", "Xcode", "Git"]
                ),
                CVItem(
                    title: "Architecture",
                    tags: ["MVVM", "Clean Architecture", "TDD", "CI/CD", "Microservices"]
                )
            ],
            order: 3
        )

        let projectsSection = CVSection(
            id: "projects",
            type: .projects,
            title: "Projects",
            items: [
                CVItem(
                    title: "OpenSource iOS Library",
                    subtitle: "GitHub: 2000+ stars",
                    description: "Created and maintain popular iOS networking library used by 500+ apps",
                    startDate: "2019",
                    endDate: "Present",
                    tags: ["Swift", "Open Source"]
                )
            ],
            order: 4
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workSection, educationSection, skillsSection, projectsSection],
            metadata: DocumentMetadata(version: "2.0")
        )
    }
}
#endif