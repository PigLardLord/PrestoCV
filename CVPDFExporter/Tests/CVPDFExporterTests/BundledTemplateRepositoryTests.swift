import XCTest
@testable import CVPDFExporter

final class BundledTemplateRepositoryTests: XCTestCase {

    var storage: TemplateTestStorage!
    var sut: BundledTemplateRepository!

    override func setUp() async throws {
        try await super.setUp()
        storage = try await TemplateTestStorage.withBundledTemplates()
        sut = storage.repository
    }

    override func tearDown() async throws {
        storage.cleanUp()
        storage = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Thumbnail URL Tests

    func test_availableTemplates_allTemplatesHaveNonNilThumbnailURL() async throws {
        // When
        let templates = try await sut.getTemplates()

        // Then
        XCTAssertFalse(templates.isEmpty, "Should have at least one template")
        for template in templates {
            XCTAssertNotNil(
                template.thumbnailURL,
                "Template '\(template.id)' should have a thumbnailURL"
            )
        }
    }

    func test_professionalTemplate_hasProfessionalPreviewPNG() async throws {
        // When
        let template = try await sut.loadTemplate(id: "professional")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Professional template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "professional_preview.png",
                "Professional template should reference professional_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_modernTemplate_hasModernPreviewPNG() async throws {
        // When
        let template = try await sut.loadTemplate(id: "modern")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Modern template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "modern_preview.png",
                "Modern template should reference modern_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_minimalTemplate_hasMinimalPreviewPNG() async throws {
        // When
        let template = try await sut.loadTemplate(id: "minimal")

        // Then
        XCTAssertNotNil(template.thumbnailURL, "Minimal template should have thumbnailURL")
        if let url = template.thumbnailURL {
            XCTAssertTrue(
                url.lastPathComponent == "minimal_preview.png",
                "Minimal template should reference minimal_preview.png, got: \(url.lastPathComponent)"
            )
        }
    }

    func test_thumbnailURLs_pointToValidBundleResources() async throws {
        // When
        let templates = try await sut.getTemplates()

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

    func test_thumbnailURLs_areImageFiles() async throws {
        // When
        let templates = try await sut.getTemplates()

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

    func test_availableTemplates_returnsExpectedTemplates() async throws {
        // When
        let templates = try await sut.getTemplates()

        // Then
        XCTAssertEqual(templates.count, 3, "Should have 3 bundled templates")

        let templateIds = Set(templates.map { $0.id })
        XCTAssertTrue(templateIds.contains("professional"))
        XCTAssertTrue(templateIds.contains("modern"))
        XCTAssertTrue(templateIds.contains("minimal"))
    }

    func test_availableTemplates_listsProfessionalFirst() async throws {
        // When
        let templates = try await sut.getTemplates()

        // Then: the export sheet preselects the first template
        XCTAssertEqual(templates.map(\.id), ["professional", "modern", "minimal"])
    }

    func test_loadTemplate_existingId_returnsTemplate() async throws {
        // When
        let template = try await sut.loadTemplate(id: "professional")

        // Then
        XCTAssertEqual(template.id, "professional")
        XCTAssertEqual(template.name, "Professional")
        XCTAssertFalse(template.htmlContent.isEmpty)
    }

    func test_loadTemplate_nonExistingId_throwsError() async {
        // When/Then
        do {
            _ = try await sut.loadTemplate(id: "nonexistent")
            XCTFail("Expected TemplateError.templateNotFound")
        } catch TemplateError.templateNotFound(let id) {
            XCTAssertEqual(id, "nonexistent")
        } catch {
            XCTFail("Expected TemplateError.templateNotFound, got \(error)")
        }
    }

    func test_installTemplate_isRejected() async {
        // When/Then: the bundled repository is read-only
        let package = TemplatePackage(
            manifest: TemplateManifest(
                id: "extra",
                name: "Extra",
                description: "Extra template",
                author: "Test",
                version: "1.0.0",
                previewImage: "preview.png",
                price: 0
            ),
            cssContent: "body { margin: 0; }"
        )

        do {
            try await sut.installTemplate(package)
            XCTFail("Expected the installation to be rejected")
        } catch TemplateRepositoryError.ioError {
            // Expected
        } catch {
            XCTFail("Expected TemplateRepositoryError.ioError, got \(error)")
        }
    }
}
