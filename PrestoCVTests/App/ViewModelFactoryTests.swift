import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles

private struct NoSamples: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

private struct UnusedContainer: DependencyContainerProtocol {
    func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol { FirstTimeOnboarding() }
    func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol { MockCVManagementUseCase() }
    func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol { NoSamples() }
    func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol { TemplateCategoryService() }
}

private struct FirstTimeOnboarding: OnboardingUseCaseProtocol {
    func checkOnboardingRequired() async -> OnboardingState { .firstTime }
    func createFirstCV(from template: CVModel) async throws -> CVModel { template }
}

/// Hands out the ids it was given, one per call.
@MainActor
private final class EditingIDs {
    private var ids: [UUID]

    init(_ ids: [UUID]) {
        self.ids = ids
    }

    func next() -> UUID {
        ids.removeFirst()
    }
}

// MARK: - ViewModelFactory Tests

/// The factory composes each editor from the request its route carries, so that no view builds one.
@MainActor
@Suite("ViewModelFactory Tests - the editor of each request")
struct ViewModelFactoryTests {

    private let cvs = MockCVManagementUseCase()
    private let repository = InMemoryUnsavedEditsRepository()
    /// The unsaved edits of the app, which every window shares
    private let unsavedEdits: UnsavedEditsUseCase

    init() {
        unsavedEdits = UnsavedEditsUseCase(repository: repository, now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func makeFactory(editingIDs: [UUID] = [UUID(), UUID()], keepsUnsavedEdits: Bool = true) throws -> ViewModelFactory {
        let ids = EditingIDs(editingIDs)
        return try ViewModelFactory(
            dependencyContainer: UnusedContainer(),
            cvManagementUseCase: cvs,
            unsavedEditsUseCase: keepsUnsavedEdits ? unsavedEdits : nil,
            environment: .fixed(newEditingID: { ids.next() })
        )
    }

    @Test("A stored CV opens in an editor that reads it, without a notice")
    func storedCVOpensAsStored() async throws {
        let saved = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        await cvs.storeCV(saved)

        let editor = try makeFactory().makeCVEditorViewModel(for: .stored(cvId: saved.id.uuidString))
        await editor.loadCV()

        #expect(editor.cv == saved)
        #expect(editor.notice == nil)
        #expect(!editor.hasUnsavedChanges)
    }

    @Test("A new CV opens on a copy of its template, with the notice it was opened with")
    func newCVOpensOnItsTemplate() throws {
        let draft = CVModel(name: "Drafted", personalInfo: PersonalInfo(name: "Maria Rossi"))

        let editor = try makeFactory().makeCVEditorViewModel(for: .new(template: draft, notice: .aiDraft))

        #expect(editor.cv.name == "Drafted")
        #expect(editor.cv.personalInfo == draft.personalInfo)
        #expect(editor.cv.id != draft.id, "The new CV gets an id of its own")
        #expect(editor.notice == .aiDraft)
        #expect(editor.hasUnsavedChanges)
    }

    @Test("Each new editing keeps its edits under an editing id of its own")
    func newEditingsHaveTheirOwnIDs() async throws {
        let first = UUID()
        let second = UUID()
        let factory = try makeFactory(editingIDs: [first, second])

        let firstEditor = factory.makeCVEditorViewModel(for: .new(template: CVModel(), notice: nil))
        let secondEditor = factory.makeCVEditorViewModel(for: .new(template: CVModel(), notice: nil))
        firstEditor.cv.personalInfo.name = "Marta Rinaldi"
        secondEditor.cv.personalInfo.name = "Luca Ferrari"
        await firstEditor.keepUnsavedEdits()
        await secondEditor.keepUnsavedEdits()

        #expect(await repository.kept[first]?.cv.personalInfo.name == "Marta Rinaldi")
        #expect(await repository.kept[second]?.cv.personalInfo.name == "Luca Ferrari")
    }

    @Test("Restored edits go on being kept as the editing they belong to, with the claim the window took")
    func restoredEditsKeepTheirEditing() async throws {
        let editing = UUID()
        let useCase = unsavedEdits
        let earlierRun = try #require(await useCase.claimEditing(editing))
        try await useCase.keep(CVModel(name: "Kept", personalInfo: PersonalInfo(name: "Marta")), over: nil, as: earlierRun)
        await useCase.release(earlierRun)
        let offer = UnsavedEditsOfferViewModel(useCase: useCase, cvs: cvs)
        await offer.checkForEditsToRestore()
        let restored = try #require(await offer.restore())

        let editor = try makeFactory().makeCVEditorViewModel(for: .restoring(restored))

        #expect(restored.takeClaim() == nil, "The editor holds the claim the window took")
        await editor.loadCV()
        #expect(editor.cv.personalInfo.name == "Marta")
        editor.cv.personalInfo.name = "Marta Rinaldi"
        await editor.keepUnsavedEdits()
        #expect(await repository.kept[editing]?.cv.personalInfo.name == "Marta Rinaldi")
    }

    @Test("Without unsaved edits on this device, the editor keeps nothing and still saves")
    func editorWorksWithoutUnsavedEdits() async throws {
        let editor = try makeFactory(keepsUnsavedEdits: false).makeCVEditorViewModel(for: .new(template: CVModel(), notice: nil))
        editor.cv.personalInfo.name = "Marta Rinaldi"

        #expect(await editor.keepUnsavedEdits() == nil, "Nothing is kept")
        #expect(await editor.saveCV())
    }

    // MARK: - The Export Sheet

    @Test("The language chosen in the export sheet of a listed CV is stored with that CV")
    func listExportSheetStoresTheLanguage() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"), documentLanguage: "de")
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = CVListViewModel(cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()))
        let sheet = try makeFactory().makeExportSheetViewModel(exporting: cv, from: list)
        #expect(sheet.documentLanguageChoice == .german, "The sheet starts with the language chosen for the CV")

        await repository.holdNextListings(1)
        sheet.documentLanguageChoice = .french
        // Once the language is stored, the list reads the CVs again
        await repository.waitUntilListingsAreHeld(1)

        #expect(try await repository.getCV(by: cv.id)?.documentLanguage == "fr")
        await repository.releaseOldestListing()
    }

    @Test("The language chosen in the export sheet of the editor goes into the form, to be saved with it")
    func editorExportSheetSetsTheForm() throws {
        let factory = try makeFactory()
        let editor = factory.makeCVEditorViewModel(for: .new(template: CVModel(documentLanguage: "de"), notice: nil))
        let sheet = factory.makeExportSheetViewModel(editing: editor)
        #expect(sheet.documentLanguageChoice == .german, "The sheet starts with the language of the form")

        sheet.documentLanguageChoice = .french

        #expect(editor.documentLanguageSelection == .french)
        #expect(editor.cv.documentLanguage == "fr")
    }

    @Test("The description typed on the AI screen is there again when the screen is opened anew")
    func aiDescriptionOutlivesItsScreen() throws {
        let factory = try makeFactory()
        factory.makeAIGenerationViewModel().prompt = "Ward nurse with ten years in intensive care"

        let reopened = factory.makeAIGenerationViewModel()

        #expect(reopened.prompt == "Ward nurse with ten years in intensive care")
    }
}
