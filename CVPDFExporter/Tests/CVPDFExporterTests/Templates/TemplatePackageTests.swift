import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Package Tests (TDD)

@Suite("Template Package Domain Model")
struct TemplatePackageTests {

    // MARK: - Model Structure Tests

    @Test("TemplatePackage has all required properties")
    func templatePackageHasRequiredProperties() {
        // Given
        let manifest = TemplateManifest(
            id: "modern-blue",
            name: "Modern Blue",
            description: "A modern template with blue accents",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let cssContent = "body { color: blue; }"
        let htmlContent: String? = nil

        // When
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: cssContent,
            htmlContent: htmlContent
        )

        // Then
        #expect(package.manifest.id == "modern-blue")
        #expect(package.manifest.name == "Modern Blue")
        #expect(package.cssContent == cssContent)
        #expect(package.htmlContent == nil)
    }

    // MARK: - Codable Tests

    @Test("TemplatePackage can be encoded to JSON")
    func templatePackageCanBeEncodedToJSON() throws {
        // Given
        let manifest = TemplateManifest(
            id: "test-template",
            name: "Test Template",
            description: "Test description",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body { margin: 0; }",
            htmlContent: nil
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(package)

        // Then
        #expect(data.count > 0)

        // Verify we can decode it back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplatePackage.self, from: data)
        #expect(decoded.manifest.id == package.manifest.id)
        #expect(decoded.cssContent == package.cssContent)
    }

    @Test("TemplatePackage can be decoded from JSON")
    func templatePackageCanBeDecodedFromJSON() throws {
        // Given
        let json = """
        {
            "manifest": {
                "id": "professional",
                "name": "Professional",
                "description": "A professional template",
                "author": "John Doe",
                "version": "2.0.0",
                "previewImage": "preview.png",
                "price": 4.99
            },
            "cssContent": "body { font-family: Arial; }",
            "htmlContent": null
        }
        """.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let package = try decoder.decode(TemplatePackage.self, from: json)

        // Then
        #expect(package.manifest.id == "professional")
        #expect(package.manifest.name == "Professional")
        #expect(package.manifest.price == 4.99)
        #expect(package.cssContent == "body { font-family: Arial; }")
        #expect(package.htmlContent == nil)
    }

    @Test("TemplatePackage supports optional HTML content")
    func templatePackageSupportsOptionalHTMLContent() throws {
        // Given - Package with HTML content
        let manifestWithHTML = TemplateManifest(
            id: "custom",
            name: "Custom",
            description: "Custom template",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let packageWithHTML = TemplatePackage(
            manifest: manifestWithHTML,
            cssContent: "body {}",
            htmlContent: "<html><body>Custom</body></html>"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(packageWithHTML)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplatePackage.self, from: data)

        // Then
        #expect(decoded.htmlContent == "<html><body>Custom</body></html>")
    }

    // MARK: - Validation Tests

    @Test("TemplatePackage validates CSS content is not empty")
    func templatePackageValidatesCSSNotEmpty() {
        // Given
        let manifest = TemplateManifest(
            id: "test",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let emptyCSS = TemplatePackage(
            manifest: manifest,
            cssContent: "",
            htmlContent: nil
        )

        let validCSS = TemplatePackage(
            manifest: manifest,
            cssContent: "body { margin: 0; }",
            htmlContent: nil
        )

        // When/Then
        #expect(!emptyCSS.isValid)
        #expect(validCSS.isValid)
    }

    @Test("TemplatePackage validation checks manifest validity")
    func templatePackageValidationChecksManifest() {
        // Given
        let invalidManifest = TemplateManifest(
            id: "",  // Invalid - empty ID
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let package = TemplatePackage(
            manifest: invalidManifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        #expect(!package.isValid)
    }
}
