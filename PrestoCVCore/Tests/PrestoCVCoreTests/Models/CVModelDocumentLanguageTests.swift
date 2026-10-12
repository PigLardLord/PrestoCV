import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVModel document language")
struct CVModelDocumentLanguageTests {

    private func decode(_ json: String) throws -> CVModel {
        try JSONDecoder().decode(CVModel.self, from: Data(json.utf8))
    }

    @Test("A CV saved before the document language existed decodes with no language")
    func oldJSONHasNoLanguage() throws {
        let cv = try decode(#"{"name":"Backend","personalInfo":{"name":"Ada"},"skills":[],"interests":["Chess"]}"#)

        #expect(cv.documentLanguage == nil)
        #expect(cv.name == "Backend")
        #expect(cv.interests == ["Chess"])
    }

    @Test("A null document language decodes as no language")
    func nullLanguageDecodesAsNil() throws {
        let cv = try decode(#"{"name":"Backend","documentLanguage":null}"#)

        #expect(cv.documentLanguage == nil)
    }

    @Test("The document language survives an encode and decode round trip")
    func languageRoundTrip() throws {
        let original = CVModel(name: "Backend", documentLanguage: "it")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CVModel.self, from: data)

        #expect(decoded.documentLanguage == "it")
        #expect(decoded == original)
    }

    @Test("A CV with no document language does not write the key")
    func unsetLanguageIsNotWritten() throws {
        let data = try JSONEncoder().encode(CVModel(name: "Backend"))
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("documentLanguage"))
    }

    @Test("Changing the document language makes the CV differ")
    func languageIsPartOfEquality() {
        let cv = CVModel(name: "Backend")
        var changed = cv
        changed.documentLanguage = "de"

        #expect(changed != cv)
    }

    @Test("A copy keeps the document language")
    func copyKeepsLanguage() {
        let original = CVModel(name: "Backend", documentLanguage: "fr")

        #expect(original.copy().documentLanguage == "fr")
        #expect(CVModel(from: original).documentLanguage == "fr")
    }
}
