import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The export of the CV as the form shows it, and its own status.
@MainActor
@Suite("Editor export")
struct EditorExportTests {

    struct NotAnExportFailure: Error {}

    @Test("export sends the form as it stands, saved or not, and never reads the store")
    func exportUsesTheUnsavedSnapshot() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.type(\.fullName, "Mara Ellison-Renn")

        let document = await editor.export()

        let snapshots = world.exporting.snapshots.withLock { $0 }
        #expect(snapshots.map(\.personal.fullName) == ["Mara Ellison-Renn"])
        #expect(world.exporting.languages.withLock { $0.map(\.tag) } == ["it"])
        #expect(world.editing.loads.withLock { $0 } == 1)
        #expect(world.editing.writeCount == 0)
        #expect(document == ExportedDocument(pdf: Data([1, 2, 3]), pages: 1))
        #expect(editor.exportStatus == .done(pages: 1))
        #expect(editor.saveStatus == .pending)
    }

    @Test("an export in flight leaves the save status, and a save in flight leaves the export status")
    func saveAndExportStatusesAreSeparate() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await world.exporting.gate.close()
        await world.editing.gate.close()

        let exporting = Task { await editor.export() }
        await waitUntil("the export to start") { await world.exporting.gate.waiting == 1 }
        #expect(editor.exportStatus == .exporting)
        #expect(editor.saveStatus == .saved)

        editor.type(\.fullName, "Mara Ellison-Renn")
        let saving = Task { await editor.saveNow() }
        await waitUntil("the write to start") { await world.editing.gate.waiting == 1 }
        #expect(editor.saveStatus == .saving)
        #expect(editor.exportStatus == .exporting)

        await world.exporting.gate.open()
        _ = await exporting.value
        #expect(editor.exportStatus == .done(pages: 1))
        #expect(editor.saveStatus == .saving)

        await world.editing.gate.open()
        await saving.value
        #expect(editor.saveStatus == .saved)
        #expect(editor.exportStatus == .done(pages: 1))
    }

    @Test("a new intent resets only its own status")
    func newIntentResetsOnlyItsOwnStatus() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        world.exporting.result.withLock { $0 = .failure(ExportFailure.notReady) }
        _ = await editor.export()
        world.editing.writeErrors.withLock { $0 = [EditFailure.unavailable] }
        editor.type(\.fullName, "Mara A")
        await editor.saveNow()
        #expect(editor.exportStatus == .notReady)
        #expect(editor.saveStatus == .failed)

        world.exporting.result.withLock { $0 = .success(ExportOutcome(pdf: Data([4]), pageCount: 2, requiredPages: 2)) }
        _ = await editor.export()
        #expect(editor.exportStatus == .done(pages: 2))
        #expect(editor.saveStatus == .failed)

        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(editor.exportStatus == .done(pages: 2))
    }

    @Test("a cancelled export goes back to idle and gives no document")
    func cancelledExportIsIdle() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.exporting.result.withLock { $0 = .failure(CancellationError()) }

        let document = await editor.export()

        #expect(document == nil)
        #expect(editor.exportStatus == .idle)
    }

    @Test("each kind of export failure has its own status")
    func eachExportFailureHasItsStatus() async throws {
        let cases: [(any Error, ExportStatus)] = [
            (ExportFailure.notReady, .notReady),
            (ExportFailure.unsupportedLanguage, .unsupportedLanguage),
            (ExportFailure.invalidDocument, .invalid),
            (ExportFailure.incomplete(missing: 2), .incomplete),
            (ExportFailure.renderingFailed, .failed),
            (NotAnExportFailure(), .failed),
        ]
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        for (error, expected) in cases {
            world.exporting.result.withLock { $0 = .failure(error) }
            let document = await editor.export()
            #expect(document == nil)
            #expect(editor.exportStatus == expected, "\(error)")
        }
    }

    @Test("a truncated document keeps both page counts")
    func truncatedKeepsBothPageCounts() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        world.exporting.result.withLock { $0 = .success(ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 3)) }

        let document = await editor.export()

        #expect(editor.exportStatus == .truncated(pages: 2, required: 3))
        #expect(document?.pages == 2)
    }

    @Test("an unsupported language is reported, never exported in another one; no language asks for one")
    func unsupportedLanguageIsNotAnotherLanguage() async throws {
        let world = Editing()
        let cv = try await world.editing.stored(title: "Design roles", fullName: "Mara Ellison", language: "tlh")
        let editor = await world.editor(on: cv)
        world.exporting.result.withLock { $0 = .failure(ExportFailure.unsupportedLanguage) }

        _ = await editor.export()
        #expect(editor.exportStatus == .unsupportedLanguage)
        #expect(world.exporting.languages.withLock { $0.map(\.tag) } == ["tlh"])

        let unnamed = try await world.editing.stored(title: "Design roles", fullName: "Mara Ellison", language: nil)
        let other = await world.editor(on: unnamed)
        _ = await other.export()
        #expect(other.exportStatus == .languageNeeded)
        #expect(world.exporting.languages.withLock { $0.count } == 1)
    }
}
