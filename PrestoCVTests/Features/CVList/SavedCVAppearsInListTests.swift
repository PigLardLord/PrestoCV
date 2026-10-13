import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles

private actor InMemoryCVRepository: CVRepositoryProtocol {
    private var storedCVs: [UUID: CVModel] = [:]

    func getAllCVs() async throws -> [CVModel] {
        storedCVs.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func getCVListing() async throws -> CVListing {
        CVListing(cvs: try await getAllCVs())
    }

    func acknowledgeUnreadableCVs() async throws {}

    func getCV(by id: UUID) async throws -> CVModel? {
        storedCVs[id]
    }

    func saveCV(_ cv: CVModel) async throws -> CVModel {
        storedCVs[cv.id] = cv
        return cv
    }

    func deleteCV(id: UUID) async throws {
        storedCVs.removeValue(forKey: id)
    }

    func cvExists() async throws -> Bool {
        !storedCVs.isEmpty
    }

    func getCVsCount() async throws -> Int {
        storedCVs.count
    }
}

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
        let saved = await editor.saveCV()
        await list.loadCVs()

        #expect(saved == true)
        #expect(list.cvs.count == 1)
        #expect(list.cvs.first?.name == "iOS Developer")
    }

    @Test("Saving a new CV twice leaves one CV in the list with the latest edits")
    func savingTwiceLeavesOneCV() async {
        let useCase = makeUseCase()
        let list = CVListViewModel(cvManagementUseCase: useCase)
        let editor = CVEditorViewModel(cvId: nil, cvManagementUseCase: useCase)
        editor.cv.personalInfo.name = "John Doe"
        _ = await editor.saveCV()

        editor.cv.personalInfo.email = "john@example.com"
        _ = await editor.saveCV()
        await list.loadCVs()

        #expect(list.cvs.count == 1, "The second save must update the CV, not add a copy of it")
        #expect(list.cvs.first?.personalInfo.email == "john@example.com")
    }
}
