import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Export Manager Tests (Sprint 5)

@Suite("Export Manager")
struct ExportManagerTests {

    @Test("Export CVDocument to JSON string")
    func exportToJSONString() throws {
        // Given
        let manager = ExportManager()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "Test User",
                email: "test@example.com",
                phone: "+1 234 567",
                summary: "Test summary"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let jsonString = try manager.exportToJSON(document: document)

        // Then
        #expect(jsonString.contains("\"name\" : \"Test User\""))
        #expect(jsonString.contains("\"email\" : \"test@example.com\""))
        #expect(jsonString.contains("\"phone\" : \"+1 234 567\""))
    }

    @Test("Export CVDocument to JSON data")
    func exportToJSONData() throws {
        // Given
        let manager = ExportManager()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "Data User",
                email: "data@example.com"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let jsonData = try manager.exportToJSONData(document: document)

        // Then
        #expect(jsonData.count > 0)

        // Verify it's valid JSON
        let decoded = try JSONDecoder().decode(JSONResume.self, from: jsonData)
        #expect(decoded.basics?.name == "Data User")
    }

    @Test("Import JSONResume from string")
    func importFromJSONString() throws {
        // Given
        let manager = ExportManager()
        let jsonString = """
        {
            "basics": {
                "name": "Imported User",
                "email": "imported@example.com",
                "phone": "+1 555 1234"
            },
            "work": [{
                "name": "Company",
                "position": "Developer",
                "startDate": "2020"
            }]
        }
        """

        // When
        let document = try manager.importFromJSON(jsonString)

        // Then
        #expect(document.personalInfo.name == "Imported User")
        #expect(document.personalInfo.email == "imported@example.com")
        #expect(document.personalInfo.phone == "+1 555 1234")

        let workSection = document.sections.first { $0.type == .work }
        #expect(workSection != nil)
        #expect(workSection?.items.first?.title == "Developer")
    }

    @Test("Import JSONResume from data")
    func importFromJSONData() throws {
        // Given
        let manager = ExportManager()
        let jsonString = """
        {
            "basics": {
                "name": "Data Import",
                "email": "dataimport@example.com"
            }
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        // When
        let document = try manager.importFromJSONData(jsonData)

        // Then
        #expect(document.personalInfo.name == "Data Import")
        #expect(document.personalInfo.email == "dataimport@example.com")
    }

    @Test("Export with pretty printing")
    func exportWithPrettyPrinting() throws {
        // Given
        let manager = ExportManager()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "Pretty User",
                email: "pretty@example.com"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let prettyJSON = try manager.exportToJSON(document: document, prettyPrinted: true)
        let compactJSON = try manager.exportToJSON(document: document, prettyPrinted: false)

        // Then
        #expect(prettyJSON.contains("\n"))
        #expect(!compactJSON.contains("\n"))
        #expect(prettyJSON.count > compactJSON.count)
    }

    @Test("Handle invalid JSON on import")
    func handleInvalidJSON() {
        // Given
        let manager = ExportManager()
        let invalidJSON = "{ invalid json }"

        // When/Then
        #expect(throws: ExportError.self) {
            _ = try manager.importFromJSON(invalidJSON)
        }
    }

    @Test("Export preserves all document fields")
    func exportPreservesAllFields() throws {
        // Given
        let manager = ExportManager()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "Complete User",
                email: "complete@example.com",
                phone: "+1 234 567 8900",
                location: "San Francisco, CA",
                website: "https://example.com",
                summary: "Complete profile"
            ),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Developer",
                            subtitle: "Tech Co",
                            description: "Built apps",
                            startDate: "2020",
                            endDate: "2023"
                        )
                    ]
                ),
                CVSection(
                    id: "skills",
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(
                            title: "Programming",
                            tags: ["Swift", "Python"]
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let json = try manager.exportToJSON(document: document)
        let imported = try manager.importFromJSON(json)

        // Then
        #expect(imported.personalInfo.name == document.personalInfo.name)
        #expect(imported.personalInfo.email == document.personalInfo.email)
        #expect(imported.personalInfo.phone == document.personalInfo.phone)
        #expect(imported.sections.count == document.sections.count)
    }

    @Test("Export manager is thread safe")
    func exportManagerIsThreadSafe() async throws {
        // Given
        let manager = ExportManager()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "Concurrent User",
                email: "concurrent@example.com"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When - perform concurrent exports
        async let export1 = Task { try manager.exportToJSON(document: document) }.value
        async let export2 = Task { try manager.exportToJSONData(document: document) }.value
        async let export3 = Task { try manager.exportToJSON(document: document, prettyPrinted: true) }.value

        let results = try await (export1, export2, export3)

        // Then
        #expect(results.0.contains("Concurrent User"))
        #expect(results.1.count > 0)
        #expect(results.2.contains("Concurrent User"))
    }
}