import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Manifest Tests (TDD)

@Suite("Template Manifest Domain Model")
struct TemplateManifestTests {

    // MARK: - Model Structure Tests

    @Test("TemplateManifest has all required properties")
    func templateManifestHasRequiredProperties() {
        // Given/When
        let manifest = TemplateManifest(
            id: "modern-blue",
            name: "Modern Blue",
            description: "A modern template with blue accents",
            author: "John Doe",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 4.99
        )

        // Then
        #expect(manifest.id == "modern-blue")
        #expect(manifest.name == "Modern Blue")
        #expect(manifest.description == "A modern template with blue accents")
        #expect(manifest.author == "John Doe")
        #expect(manifest.version == "1.0.0")
        #expect(manifest.previewImage == "preview.png")
        #expect(manifest.price == 4.99)
    }

    // MARK: - Codable Tests

    @Test("TemplateManifest can be encoded to JSON")
    func templateManifestCanBeEncodedToJSON() throws {
        // Given
        let manifest = TemplateManifest(
            id: "test-template",
            name: "Test Template",
            description: "A test template for unit testing",
            author: "Test Author",
            version: "2.1.0",
            previewImage: "preview.png",
            price: 0.0
        )

        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(manifest)

        // Then
        #expect(data.count > 0)

        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("\"id\""))
        #expect(jsonString.contains("\"test-template\""))
        #expect(jsonString.contains("\"name\""))
        #expect(jsonString.contains("\"Test Template\""))
    }

    @Test("TemplateManifest can be decoded from JSON")
    func templateManifestCanBeDecodedFromJSON() throws {
        // Given
        let json = """
        {
            "id": "professional-dark",
            "name": "Professional Dark",
            "description": "A professional dark theme template",
            "author": "Jane Smith",
            "version": "3.0.0",
            "previewImage": "preview.png",
            "price": 9.99
        }
        """.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(TemplateManifest.self, from: json)

        // Then
        #expect(manifest.id == "professional-dark")
        #expect(manifest.name == "Professional Dark")
        #expect(manifest.description == "A professional dark theme template")
        #expect(manifest.author == "Jane Smith")
        #expect(manifest.version == "3.0.0")
        #expect(manifest.previewImage == "preview.png")
        #expect(manifest.price == 9.99)
    }

    @Test("TemplateManifest roundtrip encoding/decoding preserves data")
    func templateManifestRoundtripPreservesData() throws {
        // Given
        let original = TemplateManifest(
            id: "minimal-elegant",
            name: "Minimal Elegant",
            description: "Clean and elegant design",
            author: "Design Co",
            version: "1.5.2",
            previewImage: "preview.png",
            price: 2.99
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplateManifest.self, from: data)

        // Then
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.author == original.author)
        #expect(decoded.version == original.version)
        #expect(decoded.previewImage == original.previewImage)
        #expect(decoded.price == original.price)
    }

    // MARK: - Validation Tests

    @Test("TemplateManifest validates ID is not empty")
    func templateManifestValidatesIDNotEmpty() {
        // Given
        let emptyID = TemplateManifest(
            id: "",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let validID = TemplateManifest(
            id: "valid-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        // When/Then
        #expect(!emptyID.isValid)
        #expect(validID.isValid)
    }

    @Test("TemplateManifest validates name is not empty")
    func templateManifestValidatesNameNotEmpty() {
        // Given
        let emptyName = TemplateManifest(
            id: "test-id",
            name: "",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let validName = TemplateManifest(
            id: "test-id",
            name: "Valid Name",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        // When/Then
        #expect(!emptyName.isValid)
        #expect(validName.isValid)
    }

    @Test("TemplateManifest validates version format")
    func templateManifestValidatesVersionFormat() {
        // Given
        let invalidVersion = TemplateManifest(
            id: "test-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "",
            previewImage: "preview.png",
            price: 0.0
        )

        let validVersion = TemplateManifest(
            id: "test-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        // When/Then
        #expect(!invalidVersion.isValid)
        #expect(validVersion.isValid)
    }

    @Test("TemplateManifest validates price is non-negative")
    func templateManifestValidatesPriceNonNegative() {
        // Given
        let negativePrice = TemplateManifest(
            id: "test-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: -5.0
        )

        let freeTemplate = TemplateManifest(
            id: "test-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let paidTemplate = TemplateManifest(
            id: "test-id",
            name: "Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 4.99
        )

        // When/Then
        #expect(!negativePrice.isValid)
        #expect(freeTemplate.isValid)
        #expect(paidTemplate.isValid)
    }

    @Test("TemplateManifest has isFree computed property")
    func templateManifestHasIsFreeProperty() {
        // Given
        let freeTemplate = TemplateManifest(
            id: "free-id",
            name: "Free Template",
            description: "Free",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let paidTemplate = TemplateManifest(
            id: "paid-id",
            name: "Paid Template",
            description: "Paid",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 4.99
        )

        // When/Then
        #expect(freeTemplate.isFree)
        #expect(!paidTemplate.isFree)
    }
}
