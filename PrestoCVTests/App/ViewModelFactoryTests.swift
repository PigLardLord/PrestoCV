import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct CVPDFExporter.Template

// MARK: - Test Doubles

private struct NoSamples: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

private struct StoreUnavailable: Error {}

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

    @Test("A draft opens with its AI notice, and is stored as it is", arguments: [EditorNotice.aiDraft, .aiDraftUnchecked])
    func draftOpensWithTheNotice(notice: EditorNotice) async throws {
        let draft = CVModel(name: "Drafted", personalInfo: PersonalInfo(name: "Maria Rossi"))

        let editor = try makeFactory().makeCVEditorViewModel(for: .new(template: draft, notice: notice))
        await editor.saveNow()

        #expect(editor.notice == notice)
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
        let list = CVListViewModel(cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()), clock: clock)
        let factory = try makeFactory()
        let sheet = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))
        #expect(sheet.documentLanguageChoice == .german, "The sheet starts with the language chosen for the CV")

        await repository.holdNextListings(1)
        sheet.documentLanguageChoice = .french
        clock.advance(by: CVListViewModel.choicePause)
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
        let list = CVListViewModel(cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()), clock: clock)
        let factory = try makeFactory()
        let sheet = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))

        await repository.holdNextListings(1)
        sheet.selectedTemplateId = "minimal"
        clock.advance(by: CVListViewModel.choicePause)
        // Once the look is stored, the list reads the CVs again
        await repository.waitUntilListingsAreHeld(1)

        var expected = cv
        expected.look = CVLook(design: "minimal", palette: "professional", fonts: "classic")
        #expect(try await repository.getCV(by: cv.id) == expected)
        await repository.releaseOldestListing()
    }

    /// A look no part of which the app knows
    private static let unknownLook = CVLook(design: "future-design", palette: "neon", fonts: "handwritten")

    @Test("Choosing a design in the export sheet of a listed CV stores the design and leaves the palette and font ids it holds as they are")
    func listExportSheetKeepsTheIdsOfTheUntouchedParts() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"), look: Self.unknownLook)
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = CVListViewModel(cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()), clock: clock)
        let factory = try makeFactory()
        let sheet = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))

        await repository.holdNextListings(1)
        sheet.selectedTemplateId = "modern"
        clock.advance(by: CVListViewModel.choicePause)
        // Once the look is stored, the list reads the CVs again
        await repository.waitUntilListingsAreHeld(1)

        #expect(try await repository.getCV(by: cv.id)?.look == CVLook(design: "modern", palette: "neon", fonts: "handwritten"))
        await repository.releaseOldestListing()
    }

    @Test("Choosing a design in the export sheet of the editor leaves the palette and font ids of its CV as they are")
    func editorExportSheetKeepsTheIdsOfTheUntouchedParts() async throws {
        let saved = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"), look: Self.unknownLook)
        await cvs.storeCV(saved)
        let factory = try makeFactory()
        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: saved.id.uuidString))
        await editor.loadCV()
        let sheet = factory.makeExportSheetViewModel(editing: editor)

        sheet.selectedTemplateId = "modern"

        #expect(editor.cv.look == CVLook(design: "modern", palette: "neon", fonts: "handwritten"))
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

    // MARK: - The List and the Editor

    /// A factory over the CVs of `repository`, so that its list and its editors store into the same place
    private func makeFactory(
        storing repository: InMemoryCVRepository,
        exportingWith service: any CVExportServiceProtocol = MockCVExportService(),
        environment: AppEnvironment? = nil
    ) throws -> ViewModelFactory {
        try ViewModelFactory(
            dependencyContainer: UnusedContainer(),
            cvManagementUseCase: CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples()),
            environment: environment ?? .fixed(clock: clock),
            makeExportService: { service }
        )
    }

    @Test("A CV opened while the look chosen for it in the list is still being stored shows that look, and its first save keeps it")
    func editorOpenedDuringAListSaveKeepsTheLook() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi", email: "marta@example.com"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let factory = try makeFactory(storing: repository)
        let list = factory.makeCVListViewModel()
        await list.loadCVs()
        let sheet = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))
        await repository.holdNextSaves(1)

        sheet.selectedTemplateId = "minimal"
        clock.advance(by: CVListViewModel.choicePause)
        await repository.waitUntilSavesAreHeld(1)
        // The sheet is closed and the CV opened at once, before the look is stored
        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: cv.id.uuidString))
        let loading = Task { await editor.loadCV() }
        await settle(repository)   // whatever the editor asks of the store has been answered by now
        #expect(editor.viewState.isLoading, "The editor waits for the look, which is on its way to the store")
        await repository.releaseOldestSave()
        await loading.value
        editor.cv.personalInfo.title = "Staff nurse"
        await editor.saveNow()

        #expect(editor.cv.look?.design == "minimal", "The editor opened on the CV with the look that was on its way")
        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.look?.design == "minimal", "Its first save did not undo the look")
        #expect(stored.personalInfo.title == "Staff nurse", "And the look did not undo the edit")
    }

    @Test("A CV opened while the look chosen for it is waiting for its pause shows that look, and its first save keeps it")
    func editorOpenedDuringThePauseKeepsTheLook() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi", email: "marta@example.com"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let factory = try makeFactory(storing: repository)
        let list = factory.makeCVListViewModel()
        await list.loadCVs()
        let sheet = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))

        sheet.selectedTemplateId = "minimal"
        // The CV is opened at once, before anything is stored
        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: cv.id.uuidString))
        let loading = Task { await editor.loadCV() }
        await settle(repository)   // whatever the editor asks of the store has been answered by now
        #expect(editor.viewState.isLoading, "The editor waits for the look, which is not stored yet")
        clock.advance(by: CVListViewModel.choicePause)
        await loading.value
        editor.cv.personalInfo.title = "Staff nurse"
        await editor.saveNow()

        #expect(editor.cv.look?.design == "minimal", "The editor opened on the CV with the look that was on its way")
        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.look?.design == "minimal", "Its first save did not undo the look")
        #expect(stored.personalInfo.title == "Staff nurse", "And the look did not undo the edit")
    }

    @Test("An export sheet opened again before the choices of the last one are stored starts from them, and the next choice is added")
    func reopenedSheetStartsFromTheChoicesNotStoredYet() async throws {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"), documentLanguage: "de")
        let repository = InMemoryCVRepository(cvs: [cv])
        let factory = try makeFactory(storing: repository)
        let list = factory.makeCVListViewModel()
        await list.loadCVs()
        await repository.holdNextSaves(1)

        // A design and a language are chosen, and the sheet is closed while their write is held up
        let first = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))
        first.selectedTemplateId = "minimal"
        first.documentLanguageChoice = .french
        list.storeChoicesNow()
        await repository.waitUntilSavesAreHeld(1)

        // The next sheet is opened while the row still shows the CV as it was, and the store does too. The sheets of these
        // tests are not started, so a sheet shows its look only after one is chosen: the look it starts from is the list's
        // (CVListViewModelCurrentCVTests), the language is the sheet's own
        let row = try #require(list.cvs.first)
        #expect(row.look == nil && row.documentLanguage == "de")
        let second = try #require(await factory.makeExportSheetViewModel(exportingCVWithId: cv.id, from: list))
        #expect(second.documentLanguageChoice == .french, "The language chosen in the sheet before, not the row's")
        second.documentLanguageChoice = .english
        list.storeChoicesNow()
        await repository.releaseOldestSave()

        // The editor waits for both, and shows what was chosen last, with the design chosen before
        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: cv.id.uuidString))
        await editor.loadCV()
        #expect(editor.cv.look?.design == "minimal")
        #expect(editor.cv.documentLanguage == "en")
    }

    // MARK: - A Row That Is a Read Behind

    private static let designs = ["professional", "modern", "minimal"].map {
        Template(id: $0, name: $0.capitalized, htmlContent: "<html></html>")
    }

    /// A CV that an editor changed to the Modern design with the creative colors and a French PDF, and saved, and a list
    /// whose row of it is still as it was read before: the list is reading the CVs again, or could not.
    private struct SavedInTheEditor {
        let cv: CVModel
        let repository: InMemoryCVRepository
        let factory: ViewModelFactory
        let list: CVListViewModel
        let service: MockCVExportService
    }

    private func savedInTheEditor() async throws -> SavedInTheEditor {
        let cv = CVModel(
            name: "Ward nurse",
            personalInfo: PersonalInfo(name: "Marta Rinaldi", email: "marta@example.com"),
            documentLanguage: "de",
            look: .standard
        )
        let repository = InMemoryCVRepository(cvs: [cv])
        let service = MockCVExportService()
        await service.setAvailableTemplatesResult(.success(Self.designs))
        let factory = try makeFactory(storing: repository, exportingWith: service)
        let list = factory.makeCVListViewModel()
        await list.loadCVs()

        let editor = factory.makeCVEditorViewModel(for: .stored(cvId: cv.id.uuidString))
        await editor.loadCV()
        editor.chooseLook(lookChange([.design, .palette], design: "modern", palette: "creative"))
        editor.documentLanguageSelection = .french
        #expect(await editor.saveNow(), "The editor stored the CV")
        #expect(list.cvs.first?.look == .standard && list.cvs.first?.documentLanguage == "de", "The row is as it was read")
        return SavedInTheEditor(cv: cv, repository: repository, factory: factory, list: list, service: service)
    }

    /// What the sheet shows once it is on screen, and the options the PDF is made with
    private func expectSheetShowsTheEditorsChoices(_ sheet: CVExportSheetViewModel) async {
        await sheet.start()
        #expect(sheet.selectedTemplateId == "modern")
        #expect(sheet.selectedColorPalette == .creative)
        #expect(sheet.documentLanguageChoice == .french)
        let options = sheet.currentExportOptions()
        #expect(options.templateId == "modern" && options.customization.colorPalette == .creative, "The PDF is made with them")
        await sheet.stop().value
    }

    @Test("The export sheet of a CV the editor just saved starts from what the editor saved while the list is still reading the CVs again")
    func exportSheetOfACVSavedWhileTheListReloads() async throws {
        let saved = try await savedInTheEditor()
        await saved.repository.holdNextListings(1)
        let reloading = Task { await saved.list.loadCVs() }
        await saved.repository.waitUntilListingsAreHeld(1)
        #expect(saved.list.cvs.first?.look == .standard, "The row is still the old one")

        let sheet = try #require(await saved.factory.makeExportSheetViewModel(exportingCVWithId: saved.cv.id, from: saved.list))

        await expectSheetShowsTheEditorsChoices(sheet)
        await saved.repository.releaseOldestListing()
        await reloading.value
    }

    @Test("The export sheet of a CV the editor just saved starts from what the editor saved after the list could not read the CVs again")
    func exportSheetOfACVSavedWhenTheListReloadFailed() async throws {
        let saved = try await savedInTheEditor()
        await saved.repository.fail(.listing, with: StoreUnavailable())
        await saved.list.loadCVs()
        saved.list.actionError = nil   // the failed read told the person; the sheet is asked for after
        #expect(saved.list.cvs.first?.look == .standard, "The row stays as it was")

        let sheet = try #require(await saved.factory.makeExportSheetViewModel(exportingCVWithId: saved.cv.id, from: saved.list))

        await expectSheetShowsTheEditorsChoices(sheet)
        #expect(saved.list.actionError == nil)
    }

    @Test("The sheet of a CV that cannot be read is not made from its row, and the person is told")
    func noExportSheetForACVThatCannotBeRead() async throws {
        let saved = try await savedInTheEditor()
        await saved.repository.fail(.get, with: StoreUnavailable())

        let sheet = await saved.factory.makeExportSheetViewModel(exportingCVWithId: saved.cv.id, from: saved.list)

        #expect(sheet == nil)
        #expect(saved.list.actionError != nil)
    }

    @Test("A CV opened from a row that is a read behind opens as the editor saved it")
    func editorOpenedFromARowThatIsBehind() async throws {
        let saved = try await savedInTheEditor()
        await saved.repository.fail(.listing, with: StoreUnavailable())
        await saved.list.loadCVs()

        let editor = saved.factory.makeCVEditorViewModel(for: .stored(cvId: saved.cv.id.uuidString))
        await editor.loadCV()

        #expect(editor.cv.look?.design == "modern" && editor.cv.documentLanguage == "fr")
    }

    @Test("A copy made from a row that is a read behind is a copy of the CV as the editor saved it")
    func copyOfARowThatIsBehind() async throws {
        let saved = try await savedInTheEditor()
        await saved.repository.fail(.listing, with: StoreUnavailable())
        await saved.list.loadCVs()
        saved.list.actionError = nil

        await saved.list.duplicateCV(withId: saved.cv.id)

        await saved.repository.fail(.listing, with: nil)   // the store lists again, for the test to read the copy
        let copies = try await saved.repository.getAllCVs().filter { $0.id != saved.cv.id }
        #expect(copies.map(\.look?.design) == ["modern"] && copies.map(\.documentLanguage) == ["fr"])
    }

    @Test("The description typed on the AI screen is there again when the screen is opened anew")
    func aiDescriptionOutlivesItsScreen() throws {
        let factory = try makeFactory()
        factory.makeAIGenerationViewModel().prompt = "Ward nurse with ten years in intensive care"

        let reopened = factory.makeAIGenerationViewModel()

        #expect(reopened.prompt == "Ward nurse with ten years in intensive care")
    }

    @Test("The import writes what it read to the log of the environment the factory was given (ADR 0030)")
    func importLogsToTheEnvironmentsLog() throws {
        let log = LogSpy()
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs, environment: .fixed(clock: clock, diagnostics: log)
        )
        let viewModel = factory.makeImportViewModel()
        viewModel.paste(["Lena Hartmann", "Pflegefachfrau", "", "## Berufserfahrung", "Pflegefachfrau | Klinik Beispiel | 2019 – heute"])

        viewModel.importText()

        #expect(viewModel.imported != nil)
        #expect(log.events.contains("import.finished"))
        #expect(log.lines.allSatisfy { !$0.contains("Hartmann") }, "No word of the CV reaches the log")
    }

    @Test("A CV pasted in the AI screen is read by the app's import, which logs to the environment's log, and the model is never asked (ADR 0034)")
    func pastedCVIsReadByTheImport() async throws {
        let log = LogSpy()
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs, environment: .fixed(clock: clock, diagnostics: log)
        )
        let screen = factory.makeAIGenerationViewModel()
        screen.prompt = """
        Priya Nair
        Florist

        Experience
        Florist, Petal & Stem, Bristol
        2018 – Present
        • Made bridal bouquets

        Shop Assistant, Green Corner, Bath
        2015 – 2018
        • Watered the plants

        Languages
        English – Native
        """

        await screen.generateCV()

        #expect(screen.imported?.cv.relevant_experience.map(\.company) == ["Petal & Stem", "Green Corner"])
        #expect(screen.draft == nil)
        #expect(screen.errorMessage.isEmpty)
        #expect(log.events.contains("import.finished"))
        let draftEvents = log.events.filter { $0.hasPrefix("draft.") }
        #expect(draftEvents.isEmpty, "No step of the AI draft runs")
        #expect(log.lines.allSatisfy { !$0.contains("Nair") }, "No word of the CV reaches the log")
    }

    #if DEBUG
    @Test("The AI draft writes its steps to the log of the environment the factory was given (ADR 0030)")
    func draftLogsToTheEnvironmentsLog() async throws {
        let log = LogSpy()
        let arguments = ["PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse", AIDraftScript.claimCheckArgument, "fail"]
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs,
            environment: .fixed(clock: clock, arguments: arguments, diagnostics: log)
        )
        let screen = factory.makeAIGenerationViewModel()
        screen.prompt = AIDraftScript.nurseDescription

        await screen.generateCV()

        #expect(screen.draft != nil)
        #expect(log.events.suffix(5) == ["draft.language", "draft.started", "draft.written", "draft.claims", "draft.finished"])
    }

    @Test("A debug launch that scripts the model and a claim check with no answer gives the unchecked AI draft (ADR 0028)")
    func scriptedLaunchGivesTheUncheckedDraft() async throws {
        let arguments = ["PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse", AIDraftScript.claimCheckArgument, "fail"]
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs, environment: .fixed(clock: clock, arguments: arguments)
        )
        let screen = factory.makeAIGenerationViewModel()
        screen.prompt = AIDraftScript.nurseDescription

        await screen.generateCV()

        #expect(screen.errorMessage.isEmpty)
        #expect(screen.draft?.notice == .aiDraftUnchecked)
        #expect(screen.draft?.cv.relevant_experience.map(\.company) == ["San Camillo"], "The device's rules keep the job")
        #expect(screen.draft?.cv.skills.isEmpty == true)
    }

    @Test("An AI draft of an Italian description ends the current job with the Italian word, with the app in English (#363)")
    func draftEndsTheCurrentJobInTheLanguageOfTheCV() async throws {
        let arguments = ["PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse", AIDraftScript.claimCheckArgument, "fail"]
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs, environment: .fixed(clock: clock, arguments: arguments)
        )
        let screen = factory.makeAIGenerationViewModel()
        screen.prompt = AIDraftScript.nurseDescription

        await screen.generateCV()

        #expect(screen.draft?.cv.documentLanguage == "it")
        #expect(screen.draft?.cv.relevant_experience.map(\.period) == ["2015 – Presente"])
    }

    @Test("A debug launch whose language data arrives when the app asks drafts an English description with one tap (#270)")
    func scriptedLanguageDataArrivesForTheDraft() async throws {
        let arguments = [
            "PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse", AIDraftScript.claimCheckArgument, "fail",
            LanguageDataOverride.launchArgument, "arrives",
        ]
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs, environment: .fixed(clock: clock, arguments: arguments)
        )
        let screen = factory.makeAIGenerationViewModel()
        // As the UI test of the wait types it
        screen.prompt = "I have worked at San Camillo in Roma since 2015. I use Excel every day."

        await screen.generateCV()

        #expect(screen.errorMessage.isEmpty, "The grounding reads the data the system gave")
        #expect(screen.draft?.notice == .aiDraftUnchecked)
        #expect(screen.draft?.cv.relevant_experience.map(\.company) == ["San Camillo"])
    }

    @Test("A debug launch whose language data never arrives ends the wait at the short bound it scripts, with the message, and no draft (#270)")
    func scriptedSilentLanguageDataEndsAtTheShortBound() async throws {
        let sleeps = HeldSleeps()
        let arguments = [
            "PrestoCV", AIDraftScript.scriptedDraftArgument, "nurse", LanguageDataOverride.launchArgument, "neverArrives",
        ]
        let factory = try ViewModelFactory(
            dependencyContainer: UnusedContainer(), cvManagementUseCase: cvs,
            environment: .fixed(clock: clock, sleep: { try await sleeps.sleep(for: $0) }, arguments: arguments)
        )
        let screen = factory.makeAIGenerationViewModel()
        screen.prompt = "I have worked at San Camillo in Roma since 2015. I use Excel every day."

        screen.startGenerating()
        await sleeps.waitUntilStarted(1)

        #expect(await sleeps.durations == [LanguageDataOverride.silentBound], "The wait of the app is the one the launch scripts")
        #expect(screen.isGenerating)
        #expect(screen.isWaitingForLanguageData)

        await sleeps.endAll()
        await screen.generationTask?.value

        #expect(screen.errorMessage == "ai.unavailable.language_data_not_ready".localized)
        #expect(screen.draft == nil)
        #expect(!screen.isGenerating)
    }
    #endif

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
