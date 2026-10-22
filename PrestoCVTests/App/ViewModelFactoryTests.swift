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

// MARK: - ViewModelFactory Tests

/// The factory composes each editor from the request its route carries, so that no view builds one.
@MainActor
@Suite("ViewModelFactory Tests - the editor of each request")
struct ViewModelFactoryTests {

    private let cvs = MockCVManagementUseCase()
    private let clock = ManualClock()

    private func makeFactory(container: URL? = nil) throws -> ViewModelFactory {
        try ViewModelFactory(
            dependencyContainer: UnusedContainer(),
            cvManagementUseCase: cvs,
            environment: container.map { .fixed(clock: clock, container: $0) } ?? .fixed(clock: clock)
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
        #expect(editor.showsSavedOnDevice)
    }

    @Test("A new CV opens on a copy of its template, without a notice, and is not stored until it changes")
    func newCVOpensOnItsTemplate() async throws {
        let example = CVModel(name: "Example", personalInfo: PersonalInfo(name: "Maria Rossi"))

        let editor = try makeFactory().makeCVEditorViewModel(for: .new(template: example, notice: nil))
        await editor.saveNow()

        #expect(editor.cv.name == "Example")
        #expect(editor.cv.personalInfo == example.personalInfo)
        #expect(editor.cv.id != example.id, "The new CV gets an id of its own")
        #expect(editor.notice == nil)
        #expect(await !cvs.createCVCalled)
    }

    @Test("A draft opens with the AI notice, and is stored as it is")
    func draftOpensWithTheNotice() async throws {
        let draft = CVModel(name: "Drafted", personalInfo: PersonalInfo(name: "Maria Rossi"))

        let editor = try makeFactory().makeCVEditorViewModel(for: .new(template: draft, notice: .aiDraft))
        await editor.saveNow()

        #expect(editor.notice == .aiDraft)
        #expect(editor.cv.id != draft.id, "The draft gets an id of its own")
        #expect(await cvs.createdCVs.map(\.personalInfo.name) == ["Maria Rossi"])
    }

    @Test("An imported CV opens with the import notice and its review, and is stored as it is")
    func importedCVOpensWithItsNotice() async throws {
        let imported = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann", title: "Pflegefachfrau"))
        let review = ImportReview(items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Pflegefachfrau")], notImported: "Geburtsdatum: 14.05.1992")

        let editor = try makeFactory().makeCVEditorViewModel(for: .new(template: imported, notice: .imported(review)))
        await editor.saveNow()

        #expect(editor.notice == .imported(review))
        #expect(editor.notice?.review == review, "The values to check and the text not imported stay with the editor")
        #expect(await cvs.createdCVs.map(\.personalInfo.name) == ["Lena Hartmann"])
    }

    @Test("The editors measure the pause before they save on the clock of the environment the factory was given")
    func editorsUseTheFactorysClock() async throws {
        let saved = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        let store = GatedCVManagementUseCase(gating: .update, storedCV: saved)
        await store.openGate()
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(),
            cvManagementUseCase: store,
            environment: .fixed(clock: clock)
        )
        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: saved.id.uuidString))
        await editor.loadCV()

        editor.cv.personalInfo.title = "Nurse"
        clock.advance(by: .seconds(1))
        await store.waitUntilGatedCallStarts()

        #expect(await store.updatedCVs.map(\.personalInfo.title) == ["Nurse"])
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

    @Test("The language chosen in the export sheet of the editor goes into the form, which saves it by itself")
    func editorExportSheetSetsTheForm() throws {
        let factory = try makeFactory()
        let editor = factory.makeCVEditorViewModel(for: .new(template: CVModel(documentLanguage: "de"), notice: nil))
        let sheet = factory.makeExportSheetViewModel(editing: editor)
        #expect(sheet.documentLanguageChoice == .german, "The sheet starts with the language of the form")

        sheet.documentLanguageChoice = .french

        #expect(editor.documentLanguageSelection == .french)
        #expect(editor.cv.documentLanguage == "fr")
    }

    @Test("The design chosen in the export sheet of a listed CV is stored with that CV, and nothing else of it changes")
    func listExportSheetStoresTheLook() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"), documentLanguage: "de")
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = CVListViewModel(cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()))
        let sheet = try makeFactory().makeExportSheetViewModel(exporting: cv, from: list)

        await repository.holdNextListings(1)
        sheet.selectedTemplateId = "minimal"
        // Once the look is stored, the list reads the CVs again
        await repository.waitUntilListingsAreHeld(1)

        var expected = cv
        expected.look = CVLook(design: "minimal", palette: "professional", fonts: "classic")
        #expect(try await repository.getCV(by: cv.id) == expected)
        await repository.releaseOldestListing()
    }

    @Test("The design chosen in the export sheet of the editor goes into the form, which saves it by itself")
    func editorExportSheetSetsTheLook() throws {
        let factory = try makeFactory()
        let editor = factory.makeCVEditorViewModel(for: .new(template: CVModel(look: CVLook(design: "modern")), notice: nil))
        let sheet = factory.makeExportSheetViewModel(editing: editor)
        #expect(editor.cv.look == CVLook.standard, "A new CV starts with the standard look, not the template's")

        sheet.selectedTemplateId = "minimal"
        sheet.selectedFontScheme = .serif

        #expect(editor.cv.look == CVLook(design: "minimal", palette: "professional", fonts: "serif"))
    }

    @Test("The description typed on the AI screen is there again when the screen is opened anew")
    func aiDescriptionOutlivesItsScreen() throws {
        let factory = try makeFactory()
        factory.makeAIGenerationViewModel().prompt = "Ward nurse with ten years in intensive care"

        let reopened = factory.makeAIGenerationViewModel()

        #expect(reopened.prompt == "Ward nurse with ten years in intensive care")
    }

    @Test("The router lets go of a PDF opened in the app that the import never read, in the app's own container")
    func routerLetsGoOfAnUnreadPDF() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let router = try makeFactory(container: fixture.container).makeAppRouter()
        let unread = try fixture.copyInTemporaryInbox(named: "unread.pdf")
        let latest = try fixture.copyInTemporaryInbox(named: "latest.pdf")

        await router.openImport(of: unread)
        await router.openImport(of: latest)

        #expect(!FileManager.default.fileExists(atPath: unread.path))
        #expect(FileManager.default.fileExists(atPath: latest.path), "The import still has to read it")
    }

    @Test("The import reads a PDF opened in the app and lets its copy go")
    func importLetsGoOfTheCopyItRead() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let viewModel = try makeFactory(container: fixture.container).makeImportViewModel()
        let copy = try fixture.copyInTemporaryInbox()

        await viewModel.importFile(at: copy)?.value

        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }
}
