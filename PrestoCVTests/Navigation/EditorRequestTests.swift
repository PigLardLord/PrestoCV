import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// A route to the editor is told apart from another by the request it carries, so that the navigation path never
/// takes two editors for one.
@MainActor
@Suite("EditorRequest Tests - what tells two requests of the editor apart")
struct EditorRequestTests {

    @Test("The same stored CV is the same request; another CV is another")
    func storedCVs() {
        let requests: Set<EditorRequest> = [.stored(cvId: "a"), .stored(cvId: "a"), .stored(cvId: "b")]

        #expect(requests == [.stored(cvId: "a"), .stored(cvId: "b")])
    }

    @Test("A new CV is told apart by its template")
    func newCVs() {
        let template = CVModel(name: "Example")
        let requests: Set<EditorRequest> = [
            .new(template: template),
            .new(template: template),
            .new(template: CVModel(name: "Example")),
        ]

        #expect(requests.count == 2, "The same template is one request")
    }

    @Test("A draft is told apart by its CV")
    func drafts() {
        let draft = CVModel(name: "Draft")
        let requests: Set<EditorRequest> = [.draft(draft), .draft(draft), .draft(CVModel(name: "Draft"))]

        #expect(requests.count == 2)
    }

    @Test("Requests of different kinds are never the same, even for the same CV")
    func kinds() {
        let cv = CVModel(name: "Kept")

        #expect(EditorRequest.stored(cvId: cv.id.uuidString) != .new(template: cv))
        #expect(EditorRequest.stored(cvId: cv.id.uuidString) != .draft(cv))
        #expect(EditorRequest.new(template: cv) != .draft(cv))
    }
}
