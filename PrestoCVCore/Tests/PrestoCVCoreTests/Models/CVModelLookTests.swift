import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVModel look")
struct CVModelLookTests {

    private let modern = CVLook(design: "modern", palette: "creative", fonts: "serif")

    private func decode(_ json: String) throws -> CVModel {
        try JSONDecoder().decode(CVModel.self, from: Data(json.utf8))
    }

    private func json(of cv: CVModel) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(cv)) as? [String: Any])
    }

    @Test("A CV saved before the look existed decodes with no look")
    func oldJSONHasNoLook() throws {
        let cv = try decode(#"{"name":"Backend","personalInfo":{"name":"Ada"},"skills":[],"interests":["Chess"]}"#)

        #expect(cv.look == nil)
        #expect(cv.name == "Backend")
        #expect(cv.interests == ["Chess"])
    }

    @Test("A null look decodes as no look")
    func nullLookDecodesAsNil() throws {
        let cv = try decode(#"{"name":"Backend","look":null}"#)

        #expect(cv.look == nil)
    }

    @Test("The design, palette and fonts survive an encode and decode round trip")
    func lookRoundTrip() throws {
        let original = CVModel(name: "Backend", look: modern)

        let decoded = try JSONDecoder().decode(CVModel.self, from: JSONEncoder().encode(original))

        #expect(decoded.look == modern)
        #expect(decoded.look?.design == "modern")
        #expect(decoded.look?.palette == "creative")
        #expect(decoded.look?.fonts == "serif")
        #expect(decoded == original)
    }

    @Test("A CV with no look does not write the key")
    func unsetLookIsNotWritten() throws {
        let object = try json(of: CVModel(name: "Backend"))

        #expect(object["look"] == nil)
    }

    @Test("A look is written as three plain ids under one key")
    func lookIsWrittenAsPlainIds() throws {
        let object = try json(of: CVModel(name: "Backend", look: modern))

        #expect(object["look"] as? [String: String] == ["design": "modern", "palette": "creative", "fonts": "serif"])
    }

    @Test("Ids the app does not know still decode, and are written back as they are")
    func unknownIdsAreKept() throws {
        let cv = try decode(#"{"name":"Backend","look":{"design":"retired-design","palette":"Neon","fonts":"comic"}}"#)

        #expect(cv.look == CVLook(design: "retired-design", palette: "Neon", fonts: "comic"))
        #expect(try json(of: cv)["look"] as? [String: String] == ["design": "retired-design", "palette": "Neon", "fonts": "comic"])
    }

    @Test("A look with some of its ids decodes, and the missing ones stay missing")
    func partialLookDecodes() throws {
        let cv = try decode(#"{"name":"Backend","look":{"palette":"minimal"}}"#)

        #expect(cv.look == CVLook(design: nil, palette: "minimal", fonts: nil))
        #expect(try json(of: cv)["look"] as? [String: String] == ["palette": "minimal"])
    }

    @Test("Changing the look makes the CV differ")
    func lookIsPartOfEquality() {
        let cv = CVModel(name: "Backend")
        var changed = cv
        changed.look = modern

        #expect(changed != cv)
    }

    @Test("A copy keeps the look")
    func copyKeepsLook() {
        let original = CVModel(name: "Backend", look: modern)

        #expect(original.copy().look == modern)
        #expect(CVModel(from: original).look == modern)
    }

    @Test("A CV made new from a template starts with the standard look, never the template's")
    func newCVStartsWithTheStandardLook() {
        let template = CVModel(name: "Example", look: modern)

        let new = template.startingAsNewCV()

        #expect(new.look == CVLook.standard)
        #expect(new.id != template.id)
        #expect(new.name == "Example")
        #expect(template.look == modern, "The template is left as it was")
    }

    @Test("The standard look names the bundled design, palette and fonts that the exporter defaults to")
    func standardLookIds() {
        #expect(CVLook.standard == CVLook(design: "professional", palette: "professional", fonts: "classic"))
    }
}
