import Testing
import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

/// An importer that answers as it was told, and remembers the texts it was given.
private final class ScriptedImporter: CVTextImporting, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []
    private let answer: @Sendable (String) throws -> ImportResult
    init(_ answer: @escaping @Sendable (String) throws -> ImportResult) { self.answer = answer }
    var received: [String] { lock.withLock { texts } }
    func importText(_ text: String) throws -> ImportResult {
        lock.withLock { texts.append(text) }
        return try answer(text)
    }
}

private func workflow(_ importer: ScriptedImporter, id: Int = 5) -> ImportCVWorkflow {
    ImportCVWorkflow(importer: importer, ids: FixedID(id))
}

@Suite("Import CV workflow")
struct ImportCVWorkflowTests {
    @Test("an import gives an unsaved CV with an id from the generator, its review and its text not imported")
    func importGivesUnsavedCVWithReview() async throws {
        let importer = ScriptedImporter { _ in FullImport.result }
        let outcome = try await workflow(importer).importCV(fromText: FullImport.text)
        #expect(outcome.cv.id == FixedID(5).id)
        #expect(outcome.cv.revision == 0 && outcome.cv.createdAt == nil && outcome.cv.updatedAt == nil)
        #expect(outcome == ImportedCVMapper().map(FullImport.result, id: FixedID(5).id))
        #expect(outcome.review.isEmpty == false)
    }

    @Test("the text not imported is returned whole, each piece as the person wrote it")
    func notImportedTextIsReturnedWhole() async throws {
        let f = ImportFixture(text: "Ada\nA long paragraph, with punctuation; and a second sentence.\nAnother piece")
        var imported = ImportedCV()
        imported.person.name = f.quoted("Ada")
        let result = f.result(imported, unplaced: [f.unplaced("A long paragraph, with punctuation; and a second sentence."), f.unplaced("Another piece")])
        let outcome = try await workflow(ScriptedImporter { _ in result }).importCV(fromText: f.text)
        #expect(outcome.notImported == "A long paragraph, with punctuation; and a second sentence.\nAnother piece")
    }

    @Test("a text with nothing in it is a failure, not an empty CV, and takes no id")
    func emptyTextIsAFailureNotACV() async {
        await #expect(throws: ImportFailure.empty) {
            try await workflow(ScriptedImporter { _ in throw ImportError.empty }).importCV(fromText: "")
        }
    }

    @Test("every reason the import cannot read a text is a failure of its own")
    func unreadableTextIsAFailure() async {
        let pairs: [(ImportError, ImportFailure)] = [
            (.empty, .empty), (.tooLarge, .tooLarge), (.tooManyPages, .tooManyPages), (.encrypted, .encrypted),
            (.unreadable, .unreadable), (.noText, .noText),
        ]
        for (error, failure) in pairs {
            await #expect(throws: failure) { try await workflow(ScriptedImporter { _ in throw error }).importCV(fromText: "x") }
        }
        struct Unexpected: Error {}
        await #expect(throws: ImportFailure.unreadable) { try await workflow(ScriptedImporter { _ in throw Unexpected() }).importCV(fromText: "x") }
    }

    @Test("a cancelled task stays a cancellation")
    func cancellationPassesThrough() async {
        await #expect(throws: CancellationError.self) {
            try await workflow(ScriptedImporter { _ in throw CancellationError() }).importCV(fromText: "x")
        }
    }

    @Test("a pasted CV is read by the same import, with its text as pasted")
    func pastedCVUsesTheSameImport() async throws {
        let importer = ScriptedImporter { _ in FullImport.result }
        let pasted = "  Mira Valdez\r\n\tPlatform Engineer \n"
        _ = try await workflow(importer).importCV(fromText: pasted)
        #expect(importer.received == [pasted])
    }

    @Test("a CV too big to save is still returned, whole")
    func aCVTooBigToSaveIsStillReturned() async throws {
        let big = String(repeating: "word ", count: 200_000)
        let f = ImportFixture(text: big)
        var imported = ImportedCV()
        imported.person.summary = f.quoted(big.trimmingCharacters(in: .whitespaces))
        let cv = imported
        let outcome = try await workflow(ScriptedImporter { _ in f.result(cv) }).importCV(fromText: big)
        #expect(outcome.cv.personal.summary == big.trimmingCharacters(in: .whitespaces))
        #expect(outcome.cv.revision == 0)
    }
}
