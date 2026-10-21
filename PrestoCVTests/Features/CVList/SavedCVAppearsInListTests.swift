import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles

private struct UnusedSampleCVRepository: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

/// The CVs of the app, with a store that takes its time to create a CV: the write ends when a test lets it.
private actor SlowStore: CVManagementUseCaseProtocol {
    private let base: CVManagementUseCaseProtocol
    private var isReleased = false
    private var writeStarted = false
    private var held: CheckedContinuation<Void, Never>?
    private var startWaiter: CheckedContinuation<Void, Never>?

    init(base: CVManagementUseCaseProtocol) { self.base = base }

    func waitUntilWriting() async {
        guard !writeStarted else { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func release() {
        isReleased = true
        held?.resume()
        held = nil
    }

    func storeNewCV(_ cv: CVModel) async throws -> CVModel {
        writeStarted = true
        startWaiter?.resume()
        startWaiter = nil
        if !isReleased {
            await withCheckedContinuation { held = $0 }
        }
        return try await base.storeNewCV(cv)
    }

    func getAllCVs() async throws -> [CVModel] { try await base.getAllCVs() }
    func getCVListing() async throws -> CVListing { try await base.getCVListing() }
    func acknowledgeUnreadableCVs() async throws { try await base.acknowledgeUnreadableCVs() }
    func createCV(from template: CVModel) async throws -> CVModel { try await base.createCV(from: template) }
    func updateCV(_ cv: CVModel) async throws -> CVModel { try await base.updateCV(cv) }
    func deleteCV(id: UUID) async throws { try await base.deleteCV(id: id) }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { try await base.duplicateCV(id: id, named: name) }
    func getCV(by id: UUID) async throws -> CVModel? { try await base.getCV(by: id) }
}

// MARK: - Editor to List Flow Tests

@MainActor
@Suite("Saved CV appears in the CV list - editor, use case and list working together")
struct SavedCVAppearsInListTests {

    private func makeUseCase() -> CVManagementUseCase {
        CVManagementUseCase(cvRepository: InMemoryCVRepository(), sampleRepository: UnusedSampleCVRepository())
    }

    @Test("A CV saved from a new editor is the only CV in the list")
    func savedCVAppearsInList() async {
        let useCase = makeUseCase()
        let list = CVListViewModel(cvManagementUseCase: useCase)
        let editor = CVEditorViewModel(cvId: nil, cvManagementUseCase: useCase)
        await list.loadCVs()
        #expect(list.cvs.isEmpty, "A new user starts with an empty list")

        editor.cv.name = "iOS Developer"
        editor.cv.personalInfo.name = "John Doe"
        await editor.saveNow()
        await list.loadCVs()

        #expect(list.cvs.count == 1)
        #expect(list.cvs.first?.name == "iOS Developer")
    }

    @Test("Saving a new CV twice leaves one CV in the list with the latest edits")
    func savingTwiceLeavesOneCV() async {
        let useCase = makeUseCase()
        let list = CVListViewModel(cvManagementUseCase: useCase)
        let editor = CVEditorViewModel(cvId: nil, cvManagementUseCase: useCase)
        editor.cv.personalInfo.name = "John Doe"
        await editor.saveNow()

        editor.cv.personalInfo.email = "john@example.com"
        await editor.saveNow()
        await list.loadCVs()

        #expect(list.cvs.count == 1, "The second save must update the CV, not add a copy of it")
        #expect(list.cvs.first?.personalInfo.email == "john@example.com")
    }

    @Test("A CV typed into a new editor that is left at once is in the list that is read next, however long the store takes")
    func leftAtOnceIsInTheNextRead() async {
        let store = SlowStore(base: makeUseCase())
        let saves = LeftEditorSaves()
        let router = AppRouter(isAIShipped: false, leftEditorSaves: saves)
        let list = CVListViewModel(cvManagementUseCase: store, awaitLeftEditors: saves.allEnded)
        let editor = CVEditorViewModel(cvId: nil, cvManagementUseCase: store)
        router.openEditor(.new(template: CVModel(), notice: nil))
        router.editorAppeared(editor)
        editor.cv.personalInfo.name = "John Doe"

        // Back, or the edge swipe: the list comes back and reads the store while the editor's last edits are being stored
        router.navigateBack()
        router.editorDisappeared(editor)
        let reading = Task { await list.loadCVs() }
        await store.waitUntilWriting()
        await store.release()
        await reading.value

        #expect(list.cvs.map(\.personalInfo.name) == ["John Doe"], "The list is read after the editor stored its CV")
    }
}
