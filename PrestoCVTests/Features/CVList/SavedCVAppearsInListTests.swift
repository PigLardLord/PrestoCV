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
}
