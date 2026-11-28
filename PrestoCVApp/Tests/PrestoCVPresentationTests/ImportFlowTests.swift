import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The import of a text: one at a time, a draft with its review, a problem of its own for each failure, and nothing
/// published by an import that is no longer the latest.
@MainActor
@Suite("Import of a text")
struct ImportFlowTests {

    private let someText = "Ada Ferro\nStructural engineer"

    @Test("a text gives a draft of the import's CV, with its review and its text not imported")
    func textGivesADraftWithItsReview() async throws {
        let items = [ImportReviewItem(field: .title, reason: .titleByPosition, text: "Structural engineer")]
        let outcome = ImportValues.outcome(review: items, notImported: "Hobbies: chess")
        let world = ImportWorld(answers: [.success(outcome)])
        let model = world.model()
        model.text = someText

        model.importText()
        await waitUntil("the draft") { model.status == .ready }

        let result = try #require(model.result)
        guard case .draft(let draft) = result.start else {
            Issue.record("no draft in \(result.start)")
            return
        }
        #expect(draft.cv == outcome.cv)
        #expect(result.review.entries == [
            ReviewEntry(field: .title, reason: .titleByPosition, text: "Structural engineer"),
        ])
        #expect(result.review.notImported == "Hobbies: chess")
        #expect(result.saving == nil)
    }

    @Test("a text goes to the text method, as it was typed, and its source is pasted")
    func sourceIsPastedForText() async {
        let world = ImportWorld()
        let model = world.model()
        model.text = "  Ada Ferro \r\n"

        model.importText()
        await waitUntil("the draft") { model.status == .ready }

        #expect(world.importer.texts.withLock { $0 } == ["  Ada Ferro \r\n"])
        #expect(world.importer.pdfs.withLock { $0 }.isEmpty)
        #expect(model.source == .pasted)
        #expect(model.result?.review.source == .pasted)
        #expect(world.files.recorded.isEmpty)
    }

    @Test("a paste takes the place of the text, its strings joined by a new line")
    func pasteReplacesTheTextJoinedByNewline() {
        let model = ImportWorld().model()
        model.text = "typed before"

        model.paste(["Ada Ferro", "Structural engineer"], pdfs: [])

        #expect(model.text == "Ada Ferro\nStructural engineer")
    }

    @Test("a paste of nothing leaves the text as it was")
    func emptyPasteChangesNothing() {
        let model = ImportWorld().model()
        model.text = "typed before"

        model.paste([], pdfs: [])
        model.paste([""], pdfs: [])

        #expect(model.text == "typed before")
    }

    @Test("a text with no letter cannot be imported, and nothing reaches the import",
          arguments: ["", " \n\t", "2019 – 2024"])
    func blankOrDigitsOnlyTextCannotBeImported(_ typed: String) async {
        let world = ImportWorld()
        let model = world.model()
        model.text = typed

        #expect(model.canImportText == false)
        model.importText()
        await settle()

        #expect(world.importer.calls == 0)
        #expect(model.status == .idle)
    }

    @Test("a second import while one runs is ignored: one call, one draft")
    func secondImportWhileRunningIsIgnored() async {
        let world = ImportWorld()
        let model = world.model()
        model.text = someText
        await world.hold(model) { $0.importText() }

        #expect(model.canImportText == false)
        model.importText()
        model.paste([], pdfs: [ImportValues.pdf])
        #expect(model.status == .importing)
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await settle()

        #expect(world.importer.texts.withLock { $0 } == [someText])
        #expect(world.importer.pdfs.withLock { $0 }.isEmpty)
    }

    @Test("a cancel, or an import cancelled from outside, stops with nothing to tell")
    func cancelStopsWithNothingToTell() async {
        let world = ImportWorld()
        let model = world.model()
        model.text = someText
        await world.hold(model) { $0.importText() }

        model.cancel()

        #expect(model.status == .idle)
        #expect(model.source == nil && model.result == nil)
        await waitUntil("the cancel to reach the port") { world.importer.cancellations.withLock { $0 } == 1 }

        let outside = ImportWorld(answers: [.failure(CancellationError())])
        let other = outside.model()
        other.text = someText
        other.importText()
        await waitUntil("the import to end") { outside.importer.calls == 1 && other.status != .importing }
        #expect(other.status == .idle)
        #expect(other.source == nil && other.result == nil)
    }

    @Test("a cancel with nothing running changes nothing: no idle import, no problem, no draft")
    func cancelWithNothingRunningChangesNothing() async {
        let world = ImportWorld(answers: [.failure(ImportFailure.noText), .success(ImportValues.outcome())])
        let model = world.model()
        model.text = someText
        model.cancel()
        #expect(model.status == .idle)

        model.importText()
        await waitUntil("the problem") { model.status == .failed(.noText) }
        model.cancel()
        #expect(model.status == .failed(.noText))

        model.importText()
        await waitUntil("the draft") { model.status == .ready }
        model.cancel()
        #expect(model.status == .ready)
        #expect(model.result != nil && model.source == .pasted)
    }

    @Test("a result that arrives after a cancel is dropped")
    func resultAfterCancelIsDropped() async {
        let world = ImportWorld()
        let model = world.model()
        model.text = someText
        await world.hold(model) { $0.importText() }
        model.cancel()

        await world.importer.gate.open()
        await settle()

        #expect(world.importer.calls == 1)
        #expect(model.status == .idle)
        #expect(model.result == nil && model.source == nil)
    }

    @Test("the late result of an older import is dropped: the newest import's draft stays")
    func lateResultOfAnOlderImportIsDropped() async throws {
        let older = ImportValues.outcome(name: "Ada Ferro")
        let newer = ImportValues.outcome(name: "Bea Lund")
        let world = ImportWorld(answers: [.success(older), .success(newer)])
        let model = world.model()
        model.text = someText
        await world.hold(model) { $0.importText() }
        model.cancel()
        model.importText()
        await waitUntil("both calls at the gate") { await world.importer.gate.waiting == 2 }

        await world.importer.gate.releaseNewest()
        await waitUntil("the newer draft") { model.status == .ready }
        await world.importer.gate.releaseAll()
        await settle()

        let result = try #require(model.result)
        guard case .draft(let draft) = result.start else {
            Issue.record("no draft in \(result.start)")
            return
        }
        #expect(draft.cv.personal.fullName == "Bea Lund")
        #expect(model.status == .ready)
    }

    @Test("a failure keeps the text, and clearing the problem leaves the screen idle with the text")
    func failureKeepsTheTextAndClearProblemResetsIt() async {
        let world = ImportWorld(answers: [.failure(ImportFailure.noText)])
        let model = world.model()
        model.text = someText

        model.importText()
        await waitUntil("the problem") { model.status == .failed(.noText) }
        #expect(model.text == someText)
        #expect(model.result == nil)

        model.clearProblem()
        #expect(model.status == .idle)
        #expect(model.text == someText)
        #expect(model.canImportText)
    }

    @Test("a new start clears the problem of the import before it")
    func aNewStartClearsThePreviousProblem() async {
        let world = ImportWorld(answers: [.failure(ImportFailure.tooLarge), .success(ImportValues.outcome())])
        let model = world.model()
        model.text = someText
        model.importText()
        await waitUntil("the problem") { model.status == .failed(.tooLarge) }

        await world.hold(model) { $0.importText() }
        #expect(model.status == .importing)
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
    }

    @Test("once the editor opened the draft the screen is idle, and no draft is left to open again")
    func openedClearsTheResultAndReturnsToIdle() async {
        let model = ImportWorld().model()
        model.text = someText
        model.importText()
        await waitUntil("the draft") { model.status == .ready }

        model.opened()

        #expect(model.result == nil)
        #expect(model.status == .idle && model.source == nil)
        #expect(model.text == someText)
    }

    @Test("an import error that is no import failure is unreadable")
    func anyOtherImporterErrorIsUnreadable() async {
        let world = ImportWorld(answers: [.failure(Unexpected())])
        let model = world.model()
        model.text = someText

        model.importText()
        await waitUntil("the problem") { model.status == .failed(.unreadable) }
        #expect(model.result == nil)
    }
}
