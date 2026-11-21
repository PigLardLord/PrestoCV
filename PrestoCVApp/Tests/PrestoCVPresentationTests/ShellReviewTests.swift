import Testing
import PrestoCVDomain
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// The review of an import in the shell (#404): it comes with the imported draft, ends once the editor stored the CV, and
/// goes with the editor when anything else opens.
@MainActor
@Suite("The shell's import review")
struct ShellReviewTests {

    /// The shell on a store, its import answering with values to check and a text it could not place.
    @MainActor
    struct World {
        let editing = Editing()
        let imports: ImportWorld
        let shell: ShellNavigationModel

        init() {
            imports = ImportWorld(answers: [.success(ShellReviewTests.outcome), .success(ShellReviewTests.outcome)])
            shell = editing.shell(imports: imports)
        }

        /// Imports the text and opens its draft in the editor, which reads it.
        @discardableResult
        func importDraft() async throws -> EditorViewModel {
            shell.showImport()
            let importer = try #require(shell.importer)
            importer.text = "Ada Ferro\nStructural engineer"
            importer.importText()
            await waitUntil("the draft") { importer.status == .ready }
            shell.importStatusChanged()
            let editor = try #require(shell.editor)
            await editor.load()
            return editor
        }
    }

    static let outcome = ImportValues.outcome(
        review: [ImportReviewItem(field: .experiencePeriod(2), reason: .periodOpenEnd, text: "03/2019 –"),
                 ImportReviewItem(field: .name, reason: .nameByPosition, text: "Ada Ferro")],
        notImported: "Hobbies: chess, sailing"
    )

    @Test("the imported draft opens with its review: the values to check in their order and the text not imported")
    func reviewStartsWithTheImportedDraft() async throws {
        let world = World()

        try await world.importDraft()

        let review = try #require(world.shell.review)
        #expect(review.entries == [ReviewEntry(field: .experiencePeriod(2), reason: .periodOpenEnd, text: "03/2019 –"),
                                   ReviewEntry(field: .name, reason: .nameByPosition, text: "Ada Ferro")])
        #expect(review.notImported == "Hobbies: chess, sailing")
        #expect(review.isShown)
    }

    @Test("once the editor stored the CV the review ends, and the list is told of the store too")
    func reviewEndsWhenTheEditorStores() async throws {
        let world = World()
        let editor = try await world.importDraft()
        let review = try #require(world.shell.review)

        editor.type(\.fullName, "Ada Ferro-Renn")
        await world.editing.passThePause(thenWrites: 1)

        await waitUntil("the review ended") { !review.isShown }
        #expect(world.shell.review === review, "the review stays for a sheet open over it")
        #expect(world.editing.storesTold.count == 1)
    }

    @Test("dismissing the review ends it, and the shell keeps it for a sheet open over it")
    func reviewEndsOnDismiss() async throws {
        let world = World()
        try await world.importDraft()
        let review = try #require(world.shell.review)

        review.dismiss()

        #expect(!review.isShown)
        #expect(world.shell.review === review)
    }

    @Test("a store that failed leaves the review shown")
    func reviewSurvivesAFailedStore() async throws {
        let world = World()
        let editor = try await world.importDraft()
        let review = try #require(world.shell.review)
        world.editing.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }

        editor.type(\.fullName, "Ada Ferro-Renn")
        await world.editing.passThePause(thenWrites: 1)

        await waitUntil("the write failed") { editor.saveStatus == .failed }
        #expect(review.isShown)
    }

    /// The ways to open something else, each from the imported draft open in the editor.
    enum Elsewhere: CaseIterable {
        case storedCV, draft, list, importScreen
    }

    @Test("opening anything else, or going back to the list, drops the review", arguments: Elsewhere.allCases)
    func anotherCVHasNoReview(_ elsewhere: Elsewhere) async throws {
        let world = World()
        let cv = try await world.editing.storedCV()
        try await world.importDraft()
        #expect(world.shell.review != nil)

        switch elsewhere {
        case .storedCV: world.shell.open(.stored(CVReference(id: cv.id)))
        case .draft: world.shell.open(.draft(CVDraft(cv: ImportValues.cv("Mara Ellison"))))
        case .list: world.shell.deselect()
        case .importScreen: world.shell.showImport()
        }

        #expect(world.shell.review == nil)
    }

    @Test("an editor no write can store dropped on the person's word takes its review with it")
    func discardDropsTheReview() async throws {
        let world = World()
        let editor = try await world.importDraft()
        editor.type(\.fullName, "Ada Ferro-Renn")
        await editor.saveNow()
        let stored = try await world.editing.editing.inStore(ImportValues.cv("Ada Ferro").id)
        try await world.editing.editing.store.delete(stored.id, revision: stored.revision)
        editor.type(\.fullName, "Ada Ferro-Reyes")
        await editor.saveNow()
        #expect(editor.saveStatus == .deletedElsewhere)
        #expect(world.shell.review != nil)

        world.shell.discardEditor()

        #expect(world.shell.review == nil)
    }

    @Test("a late write of an imported draft left behind leaves the review of the next import shown")
    func lateWriteOfAnEarlierDraftLeavesTheNextReview() async throws {
        let world = World()
        let first = try await world.importDraft()
        first.type(\.fullName, "Ada Ferro-Renn")
        await world.editing.editing.gate.close()
        world.shell.deselect()
        await waitUntil("the left draft's write at the store's door") { await world.editing.editing.gate.waiting == 1 }

        try await world.importDraft()
        let next = try #require(world.shell.review)
        await world.editing.editing.gate.open()

        await waitUntil("the left draft stored") { world.editing.storesTold.count == 1 }
        #expect(next.isShown)
    }
}
