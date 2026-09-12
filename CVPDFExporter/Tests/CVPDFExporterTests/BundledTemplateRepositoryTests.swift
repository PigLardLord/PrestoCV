import XCTest
@testable import CVPDFExporter

final class BundledTemplateRepositoryTests: XCTestCase {

    static let knownIssue = "Bundled templates are never registered: https://github.com/PigLardLord/PrestoCV-archive/issues/1"

    var sut: BundledTemplateRepository!

    override func setUp() {
        super.setUp()
        sut = BundledTemplateRepository()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Thumbnail URL Tests

    func test_availableTemplates_allTemplatesHaveNonNilThumbnailURL() {
        XCTExpectFailure(Self.knownIssue)

        // When
        let templates = sut.availableTemplates()

        // Then
        XCTAssertFalse(templates.isEmpty, "Should have at least one template")
        for template in templates {
            XCTAssertNotNil(
                template.thumbnailURL,
                "Template '\(template.id)' should have a thumbnailURL"
            )
        }
    }

    func test_professionalTemplate_hasProfessionalPreviewPNG() throws {
        XCTExpectFailure(Self.knownIssue)

        // When
        let template = try sut.loadTemplate(id: "professional")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Professional template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "professional_preview.png",
                "Professional template should reference professional_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_modernTemplate_hasModernPreviewPNG() throws {
        XCTExpectFailure(Self.knownIssue)

        // When
        let template = try sut.loadTemplate(id: "modern")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Modern template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "modern_preview.png",
                "Modern template should reference modern_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_minimalTemplate_hasMinimalPreviewPNG() throws {
        XCTExpectFailure(Self.knownIssue)

        // When
        let template = try sut.loadTemplate(id: "minimal")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Minimal template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "minimal_preview.png",
                "Minimal template should reference minimal_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_thumbnailURLs_pointToValidBundleResources() throws {
        // When
        let templates = sut.availableTemplates()

        // Then
        for template in templates {
            guard let url = template.thumbnailURL else {
                XCTFail("Template '\(template.id)' has nil thumbnailURL")
                continue
            }

            // Check that the file exists at the URL
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path),
                "Thumbnail file should exist at path: \(url.path) for template '\(template.id)'"
            )
        }
    }

    func test_thumbnailURLs_areImageFiles() throws {
        // When
        let templates = sut.availableTemplates()

        // Then
        for template in templates {
            guard let url = template.thumbnailURL else {
                XCTFail("Template '\(template.id)' has nil thumbnailURL")
                continue
            }

            let pathExtension = url.pathExtension.lowercased()
            XCTAssertTrue(
                pathExtension == "png" || pathExtension == "jpg" || pathExtension == "jpeg",
                "Thumbnail should be an image file (png/jpg), got: \(pathExtension) for template '\(template.id)'"
            )
        }
    }

    // MARK: - Existing Functionality Tests

    func test_availableTemplates_returnsExpectedTemplates() {
        XCTExpectFailure(Self.knownIssue)

        // When
        let templates = sut.availableTemplates()

        // Then
        XCTAssertEqual(templates.count, 3, "Should have 3 bundled templates")

        let templateIds = Set(templates.map { $0.id })
        XCTAssertTrue(templateIds.contains("professional"))
        XCTAssertTrue(templateIds.contains("modern"))
        XCTAssertTrue(templateIds.contains("minimal"))
    }

    func test_loadTemplate_existingId_returnsTemplate() throws {
        XCTExpectFailure(Self.knownIssue)

        // When
        let template = try sut.loadTemplate(id: "professional")

        // Then
        XCTAssertEqual(template.id, "professional")
        XCTAssertEqual(template.name, "Professional")
        XCTAssertFalse(template.htmlContent.isEmpty)
    }

    func test_loadTemplate_nonExistingId_throwsError() {
        // When/Then
        XCTAssertThrowsError(try sut.loadTemplate(id: "nonexistent")) { error in
            if case TemplateError.templateNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected TemplateError.templateNotFound, got \(error)")
            }
        }
    }
}
