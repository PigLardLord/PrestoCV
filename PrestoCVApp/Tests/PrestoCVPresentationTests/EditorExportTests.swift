import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the editor gives the export sheet: the CV as the form shows it.
@MainActor
@Suite("Editor export snapshot")
struct EditorExportTests {

    @Test("the snapshot is the form as it stands, saved or not, in the CV's language, and touches no store")
    func snapshotIsTheUnsavedForm() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.type(\.fullName, "Mara Ellison-Renn")

        let snapshot = try #require(editor.exportSnapshot(), "an open CV gives a snapshot")

        #expect(snapshot.cv.personal.fullName == "Mara Ellison-Renn")
        #expect(snapshot.cv.language?.tag == "it")
        #expect(snapshot.cv.id == cv.id)
        #expect(world.editing.loads.withLock { $0 } == 1, "only the opening read the store")
        #expect(world.editing.writeCount == 0)
        #expect(editor.saveStatus == .pending, "the snapshot leaves the save status alone")
    }
}
