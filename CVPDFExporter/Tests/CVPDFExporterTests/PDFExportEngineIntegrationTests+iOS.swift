#if canImport(UIKit)
import XCTest
@testable import CVPDFExporter

// iOS-specific integration tests
@MainActor
final class PDFExportEngineIntegrationTestsiOS: XCTestCase {

    private var sut: PDFExportEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = PDFExportEngineFactory.create()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - iOS PDF Export Tests

    func testExportToPDFGeneratesData() async throws {
        let document = createSampleDocument()
        let options = ExportOptions.default

        let pdfData = try await sut.exportToPDF(document: document, options: options)

        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        XCTAssertTrue(pdfData.count > 1000, "PDF should have substantial content")
        XCTAssertTrue(isPDFData(pdfData), "Data should be valid PDF")
    }

    func testExportToPDFWithCustomOptions() async throws {
        let document = createSampleDocument()
        let options = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36)
        )

        let pdfData = try await sut.exportToPDF(document: document, options: options)

        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testExportToPDFWithEmptyDocument() async throws {
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "", email: ""),
            sections: [],
            metadata: DocumentMetadata()
        )
        let options = ExportOptions.default

        let pdfData = try await sut.exportToPDF(document: document, options: options)

        XCTAssertFalse(pdfData.isEmpty, "Even empty document should generate PDF")
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testExportPerformance() async throws {
        let document = createSampleDocument()
        let options = ExportOptions.default

        let startTime = Date()
        _ = try await sut.exportToPDF(document: document, options: options)
        let endTime = Date()

        let timeInterval = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(timeInterval, 5.0, "PDF export should complete within 5 seconds")
    }

    // MARK: - Helper Methods

    private func isPDFData(_ data: Data) -> Bool {
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        return data.prefix(4) == pdfHeader
    }

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
}
#endif