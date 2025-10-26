import XCTest
@testable import PrestoCV
import CVPDFExporter

final class TemplateDisplayModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_init_fromTemplate_setsAllProperties() {
        // Given
        let thumbnailURL = URL(fileURLWithPath: "/test/preview.png")
        let template = Template(
            id: "test-template",
            name: "Test Template",
            description: "A test template for unit testing",
            htmlContent: "<html>test</html>",
            supportedVariables: ["name", "email"],
            thumbnailURL: thumbnailURL,
            isPremium: true
        )

        // When
        let displayModel = TemplateDisplayModel(from: template)

        // Then
        XCTAssertEqual(displayModel.id, "test-template")
        XCTAssertEqual(displayModel.name, "Test Template")
        XCTAssertEqual(displayModel.description, "A test template for unit testing")
        XCTAssertEqual(displayModel.previewURL, thumbnailURL)
        XCTAssertTrue(displayModel.isPremium)
    }

    func test_init_fromTemplateWithoutThumbnail_setsPreviewURLToNil() {
        // Given
        let template = Template(
            id: "no-thumbnail",
            name: "No Thumbnail",
            htmlContent: "<html>test</html>",
            thumbnailURL: nil
        )

        // When
        let displayModel = TemplateDisplayModel(from: template)

        // Then
        XCTAssertNil(displayModel.previewURL)
    }

    // MARK: - Computed Property Tests

    func test_hasValidPreview_withURL_returnsTrue() {
        // Given
        let template = Template(
            id: "test",
            name: "Test",
            htmlContent: "",
            thumbnailURL: URL(fileURLWithPath: "/test.png")
        )
        let displayModel = TemplateDisplayModel(from: template)

        // When
        let hasValidPreview = displayModel.hasValidPreview

        // Then
        XCTAssertTrue(hasValidPreview)
    }

    func test_hasValidPreview_withoutURL_returnsFalse() {
        // Given
        let template = Template(
            id: "test",
            name: "Test",
            htmlContent: "",
            thumbnailURL: nil
        )
        let displayModel = TemplateDisplayModel(from: template)

        // When
        let hasValidPreview = displayModel.hasValidPreview

        // Then
        XCTAssertFalse(hasValidPreview)
    }

    // MARK: - Identifiable Tests

    func test_identifiable_conformance() {
        // Given
        let template = Template(
            id: "unique-id",
            name: "Test",
            htmlContent: ""
        )

        // When
        let displayModel = TemplateDisplayModel(from: template)

        // Then
        XCTAssertEqual(displayModel.id, "unique-id")
    }

    // MARK: - Collection Mapping Tests

    func test_mappingCollectionOfTemplates() {
        // Given
        let templates = [
            Template(id: "1", name: "Template 1", htmlContent: ""),
            Template(id: "2", name: "Template 2", htmlContent: ""),
            Template(id: "3", name: "Template 3", htmlContent: "")
        ]

        // When
        let displayModels = templates.map { TemplateDisplayModel(from: $0) }

        // Then
        XCTAssertEqual(displayModels.count, 3)
        XCTAssertEqual(displayModels[0].id, "1")
        XCTAssertEqual(displayModels[1].id, "2")
        XCTAssertEqual(displayModels[2].id, "3")
    }

    // MARK: - Equatable Tests

    func test_equatable_sameValues_returnsTrue() {
        // Given
        let template = Template(
            id: "test",
            name: "Test",
            description: "Description",
            htmlContent: "",
            thumbnailURL: URL(fileURLWithPath: "/test.png"),
            isPremium: false
        )
        let model1 = TemplateDisplayModel(from: template)
        let model2 = TemplateDisplayModel(from: template)

        // When/Then
        XCTAssertEqual(model1, model2)
    }

    func test_equatable_differentIds_returnsFalse() {
        // Given
        let template1 = Template(id: "test1", name: "Test", htmlContent: "")
        let template2 = Template(id: "test2", name: "Test", htmlContent: "")
        let model1 = TemplateDisplayModel(from: template1)
        let model2 = TemplateDisplayModel(from: template2)

        // When/Then
        XCTAssertNotEqual(model1, model2)
    }
}
