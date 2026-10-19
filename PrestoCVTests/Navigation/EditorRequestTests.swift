import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// A route to the editor is told apart from another by the request it carries, so that the navigation path never
/// takes two editors for one.
@MainActor
@Suite("EditorRequest Tests - what tells two requests of the editor apart")
struct EditorRequestTests {

    private func restored() -> RestoredUnsavedEdits {
        RestoredUnsavedEdits(
            edits: UnsavedEdits(id: UUID(), cv: CVModel(name: "Kept"), base: nil, keptAt: Date(timeIntervalSince1970: 1_700_000_000)),
            claim: nil,
            useCase: nil
        )
    }

    @Test("The same stored CV is the same request; another CV is another")
    func storedCVs() {
        let requests: Set<EditorRequest> = [.stored(cvId: "a"), .stored(cvId: "a"), .stored(cvId: "b")]

        #expect(requests == [.stored(cvId: "a"), .stored(cvId: "b")])
    }

    @Test("A new CV is told apart by its template and by its notice")
    func newCVs() {
        let template = CVModel(name: "Draft")
        let requests: Set<EditorRequest> = [
            .new(template: template, notice: nil),
            .new(template: template, notice: nil),
            .new(template: template, notice: .aiDraft),
            .new(template: CVModel(name: "Draft"), notice: nil),
        ]

        #expect(requests.count == 3, "The same template with the same notice is one request")
    }

    @Test("Restores are told apart by their claim, not by their edits")
    func restores() {
        let restore = restored()
        let requests: Set<EditorRequest> = [.restoring(restore), .restoring(restore), .restoring(restored())]

        #expect(requests.count == 2)
    }

    @Test("Requests of different kinds are never the same, even for the same CV")
    func kinds() {
        let restore = restored()
        let cvId = restore.edits.cv.id

        #expect(EditorRequest.stored(cvId: cvId.uuidString) != .new(template: restore.edits.cv, notice: nil))
        #expect(EditorRequest.stored(cvId: cvId.uuidString) != .restoring(restore))
        #expect(EditorRequest.new(template: restore.edits.cv, notice: nil) != .restoring(restore))
    }
}
