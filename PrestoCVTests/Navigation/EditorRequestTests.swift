import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// A route to the editor is told apart from another by the request it carries, so that the navigation path never
/// takes two editors for one.
@MainActor
@Suite("EditorRequest Tests - what tells two requests of the editor apart")
struct EditorRequestTests {

    private static let review = ImportReview(
        items: [ImportReview.Item(field: .name, reason: .byPosition, text: "Lena Hartmann")],
        notImported: "Geburtsdatum: 14.05.1992"
    )

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
            .new(template: template, notice: .aiDraftUnchecked),
            .new(template: template, notice: .imported(Self.review)),
            .new(template: CVModel(name: "Draft"), notice: nil),
        ]

        #expect(requests.count == 5, "The same template with the same notice is one request")
    }

    @Test("Requests of different kinds are never the same, even for the same CV")
    func kinds() {
        let cv = CVModel(name: "Kept")

        #expect(EditorRequest.stored(cvId: cv.id.uuidString) != .new(template: cv, notice: nil))
        #expect(EditorRequest.stored(cvId: cv.id.uuidString) != .new(template: cv, notice: .aiDraft))
    }

    // MARK: - Stored as it is

    @Test("An AI draft and an imported CV are stored as they open, without waiting for a change")
    func draftsAndImportsAreStoredAsTheyAre() {
        let cv = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann"))

        #expect(EditorRequest.new(template: cv, notice: .aiDraft).storesAsItIs)
        #expect(EditorRequest.new(template: cv, notice: .aiDraftUnchecked).storesAsItIs, "A draft whose personal items were withdrawn too")
        #expect(EditorRequest.new(template: cv, notice: .imported(Self.review)).storesAsItIs)
        #expect(EditorRequest.new(template: cv, notice: .imported(ImportReview(items: [], notImported: ""))).storesAsItIs,
                "An import with nothing to check is stored too")
    }

    @Test("A blank CV, an example and a stored CV are not stored as they open")
    func blankExampleAndStoredWaitForAChange() {
        #expect(!EditorRequest.new(template: CVModel(), notice: nil).storesAsItIs, "A blank CV")
        #expect(!EditorRequest.new(template: CVModel(personalInfo: PersonalInfo(title: "Nurse")), notice: nil).storesAsItIs, "An example")
        #expect(!EditorRequest.stored(cvId: UUID().uuidString).storesAsItIs, "The store holds it already")
    }
}
