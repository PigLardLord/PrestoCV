import Testing
import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

/// The answer of an importer asked for what its script does not hold.
private struct NotScripted: Error {}

/// An importer that answers as it was told, and remembers the texts and the PDFs it was given. One made for texts
/// throws for a PDF, one made for PDFs throws for a text.
private final class ScriptedImporter: CVTextImporting, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []
    private var documents: [Data] = []
    private let answer: @Sendable (String) throws -> ImportResult
    private let pdfAnswer: @Sendable (Data) throws -> ImportResult
    init(_ answer: @escaping @Sendable (String) throws -> ImportResult) {
        self.answer = answer; pdfAnswer = { _ in throw NotScripted() }
    }
    private init(pdfAnswer: @escaping @Sendable (Data) throws -> ImportResult) {
        answer = { _ in throw NotScripted() }; self.pdfAnswer = pdfAnswer
    }
    static func pdf(_ answer: @escaping @Sendable (Data) throws -> ImportResult) -> ScriptedImporter {
        ScriptedImporter(pdfAnswer: answer)
    }
    var received: [String] { lock.withLock { texts } }
    var receivedPDFs: [Data] { lock.withLock { documents } }
    func importText(_ text: String) throws -> ImportResult {
        lock.withLock { texts.append(text) }
        return try answer(text)
    }
    func importPDF(_ data: Data) async throws -> ImportResult {
        lock.withLock { documents.append(data) }
        return try pdfAnswer(data)
    }
}

/// Every reason the import gives for reading nothing, with the failure the workflow gives for it.
private let everyImportError: [(ImportError, ImportFailure)] = [
    (.empty, .empty), (.tooLarge, .tooLarge), (.tooManyPages, .tooManyPages), (.encrypted, .encrypted),
    (.unreadable, .unreadable), (.noText, .noText),
]

/// Invented bytes: the scripted importer never reads them.
private let somePDF = Data("%PDF-1.7 invented".utf8)

/// An id generator that gives a fixed id and counts how many times it was asked.
private final class CountingID: IDGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var asked = 0
    private let fixed: FixedID
    init(_ last: Int) { fixed = FixedID(last) }
    var calls: Int { lock.withLock { asked } }
    func next() -> CVID {
        lock.withLock { asked += 1 }
        return fixed.next()
    }
}

private func workflow(_ importer: ScriptedImporter, ids: CountingID) -> ImportCVWorkflow {
    ImportCVWorkflow(importer: importer, ids: ids)
}

private func workflow(_ importer: ScriptedImporter, id: Int = 5) -> ImportCVWorkflow {
    workflow(importer, ids: CountingID(id))
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

    @Test("a successful import takes exactly one id")
    func successTakesOneID() async throws {
        let ids = CountingID(5)
        _ = try await workflow(ScriptedImporter { _ in FullImport.result }, ids: ids).importCV(fromText: FullImport.text)
        #expect(ids.calls == 1)
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
        let ids = CountingID(5)
        await #expect(throws: ImportFailure.empty) {
            try await workflow(ScriptedImporter { _ in throw ImportError.empty }, ids: ids).importCV(fromText: "")
        }
        #expect(ids.calls == 0)
    }

    @Test("every reason the import cannot read a text is a failure of its own")
    func unreadableTextIsAFailure() async {
        let ids = CountingID(5)
        for (error, failure) in everyImportError {
            await #expect(throws: failure) { try await workflow(ScriptedImporter { _ in throw error }, ids: ids).importCV(fromText: "x") }
        }
        struct Unexpected: Error {}
        await #expect(throws: ImportFailure.unreadable) {
            try await workflow(ScriptedImporter { _ in throw Unexpected() }, ids: ids).importCV(fromText: "x")
        }
        #expect(ids.calls == 0)
    }

    @Test("a cancelled task stays a cancellation")
    func cancellationPassesThrough() async {
        let ids = CountingID(5)
        await #expect(throws: CancellationError.self) {
            try await workflow(ScriptedImporter { _ in throw CancellationError() }, ids: ids).importCV(fromText: "x")
        }
        #expect(ids.calls == 0)
    }

    @Test("a pasted CV is read by the same import, with its text as pasted")
    func pastedCVUsesTheSameImport() async throws {
        let importer = ScriptedImporter { _ in FullImport.result }
        let pasted = "  Mira Valdez\r\n\tPlatform Engineer \n"
        _ = try await workflow(importer).importCV(fromText: pasted)
        #expect(importer.received == [pasted])
        #expect(importer.receivedPDFs.isEmpty)
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

    // MARK: Saving verdict

    @Test("a CV above the limit for all its texts is returned with the too-large verdict")
    func aCVAboveTheTotalLimitSaysTooLarge() async throws {
        // 30 entries of 9,000 characters: each text is within its own limit, together they are above the total.
        let lines = (0..<30).map { "Entry \($0) " + String(repeating: "x", count: 8_990) }
        let text = lines.joined(separator: "\n")
        #expect(lines.count * 9_000 > CVLimits.maxTotalTextBytes)
        let f = ImportFixture(text: text)
        var imported = ImportedCV()
        imported.person.name = f.quoted("Entry 0 " + String(repeating: "x", count: 8_990))
        imported.experience = lines.dropFirst().map { f.experience(details: [f.quoted($0)]) }
        let cv = imported
        let outcome = try await workflow(ScriptedImporter { _ in f.result(cv) }).importCV(fromText: text)
        #expect(outcome.saving == .cvTooLarge)
        #expect(outcome.cv.sections.experiences.count == 29)
    }

    @Test("a text above the limit of one field gives the verdict naming that field, and the CV is returned")
    func aTextTooLongNamesItsField() async throws {
        let long = String(repeating: "word ", count: 2_500) + "end"
        #expect(long.count > CVLimits.maxTextCharacters)
        let f = ImportFixture(text: long)
        var imported = ImportedCV()
        imported.person.summary = f.quoted(long)
        let cv = imported
        let outcome = try await workflow(ScriptedImporter { _ in f.result(cv) }).importCV(fromText: long)
        #expect(outcome.saving == .textTooLong(.summary))
        #expect(outcome.cv.personal.summary == long)
    }

    @Test("a normal import gives the ok verdict, the one the CV itself gives")
    func aNormalImportCanBeSaved() async throws {
        let outcome = try await workflow(ScriptedImporter { _ in FullImport.result }).importCV(fromText: FullImport.text)
        #expect(outcome.saving == .ok)
        #expect(outcome.saving == outcome.cv.saveCheck())
    }

    // MARK: A PDF

    @Test("a PDF gives the same kind of outcome as a text: an unsaved CV with its review, and no text is read")
    func pdfGivesTheSameKindOfOutcome() async throws {
        let importer = ScriptedImporter.pdf { _ in FullImport.result }
        let outcome = try await workflow(importer).importCV(fromPDF: somePDF)
        #expect(importer.receivedPDFs == [somePDF])
        #expect(importer.received.isEmpty)
        #expect(outcome.cv.id == FixedID(5).id)
        #expect(outcome.cv.revision == 0 && outcome.cv.createdAt == nil && outcome.cv.updatedAt == nil)
        #expect(outcome.review.isEmpty == false)
        #expect(outcome.saving == .ok)
    }

    @Test("a cancelled PDF import stays a cancellation and takes no id")
    func pdfCancellationPassesThrough() async {
        let ids = CountingID(5)
        await #expect(throws: CancellationError.self) {
            let importer = ScriptedImporter.pdf { _ in throw CancellationError() }
            return try await workflow(importer, ids: ids).importCV(fromPDF: somePDF)
        }
        #expect(ids.calls == 0)
    }

    @Test("every reason the import cannot read a PDF is the failure of its own, and takes no id")
    func eachImportErrorOfAPDFIsItsFailure() async {
        let ids = CountingID(5)
        for (error, failure) in everyImportError {
            await #expect(throws: failure) {
                try await workflow(ScriptedImporter.pdf { _ in throw error }, ids: ids).importCV(fromPDF: somePDF)
            }
        }
        #expect(ids.calls == 0)
    }

    @Test("any other error of a PDF import is unreadable")
    func anyOtherPDFErrorIsUnreadable() async {
        struct Unexpected: Error {}
        await #expect(throws: ImportFailure.unreadable) {
            try await workflow(ScriptedImporter.pdf { _ in throw Unexpected() }).importCV(fromPDF: somePDF)
        }
    }

    @Test("a PDF goes through the same mapper as a text, and a failed one takes no id")
    func pdfUsesTheSameMapperAndNoCVIdOnFailure() async throws {
        let fromPDF = try await workflow(ScriptedImporter.pdf { _ in FullImport.result }).importCV(fromPDF: somePDF)
        let text = ScriptedImporter { _ in FullImport.result }
        let fromText = try await workflow(text).importCV(fromText: FullImport.text)
        #expect(fromPDF == fromText)
        #expect(fromPDF == ImportedCVMapper().map(FullImport.result, id: FixedID(5).id))
        let ids = CountingID(5)
        await #expect(throws: ImportFailure.noText) {
            let importer = ScriptedImporter.pdf { _ in throw ImportError.noText }
            return try await workflow(importer, ids: ids).importCV(fromPDF: somePDF)
        }
        #expect(ids.calls == 0)
    }
}
