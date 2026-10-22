import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVDomain.DesignChoice

/// The design, palette and font chosen in the export sheet of an open editor go into its form, which saves them with the
/// rest of the CV. The editor is the only writer of its CV while it is open.
@MainActor
@Suite("CVEditorViewModel Tests - Look")
struct CVEditorViewModelLookTests {

    private let modern = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
    private let minimal = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!

    private func savedCV(look: CVLook? = nil) -> CVModel {
        CVModel(name: "Backend", personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com"), documentLanguage: "it", look: look)
    }

    /// An editor open on `saved`, which the store holds
    private func openEditor(on saved: CVModel, clock: ManualClock = ManualClock()) async -> (CVEditorViewModel, MockCVManagementUseCase) {
        let useCase = MockCVManagementUseCase()
        await useCase.setGetCVResult(.success(saved))
        let viewModel = CVEditorViewModel(cvId: saved.id.uuidString, cvManagementUseCase: useCase, clock: clock)
        await viewModel.loadCV()
        return (viewModel, useCase)
    }

    // MARK: - Choosing

    @Test("Choosing a look sets it on the CV in the form, as the ids of the choice")
    func choosingSetsTheLook() async {
        let (viewModel, _) = await openEditor(on: savedCV())

        viewModel.chooseLook(modern)

        #expect(viewModel.cv.look == CVLook(design: "modern", palette: "creative", fonts: "serif"))
    }

    @Test("A look chosen is saved with the CV, and nothing else of it changes")
    func chosenLookIsSaved() async {
        let saved = savedCV()
        let (viewModel, useCase) = await openEditor(on: saved)

        viewModel.chooseLook(modern)
        #expect(viewModel.saveStatus == .pending, "A change waits for the pause, like any other")
        await viewModel.saveNow()

        var expected = saved
        expected.look = CVLook(modern)
        #expect(await useCase.updatedCVs == [expected])
        #expect(viewModel.saveStatus == .upToDate)
    }

    @Test("A look chosen is saved by itself once the pause after the last change has passed")
    func chosenLookIsSavedByItself() async {
        let clock = ManualClock()
        let saved = savedCV()
        let (viewModel, useCase) = await openEditor(on: saved, clock: clock)

        viewModel.chooseLook(modern)
        viewModel.chooseLook(minimal)
        clock.advance(by: .seconds(1))
        await viewModel.saveNow()

        #expect(await useCase.updatedCVs.map(\.look) == [CVLook(minimal)], "Two choices in a row are one write")
    }

    @Test("Choosing a look again replaces the one before")
    func laterLookReplacesTheEarlier() async {
        let (viewModel, useCase) = await openEditor(on: savedCV(look: CVLook(modern)))

        viewModel.chooseLook(minimal)
        await viewModel.saveNow()

        #expect(await useCase.updatedCVs.last?.look == CVLook(minimal))
    }

    @Test("Choosing the look the CV has already changes nothing and stores nothing")
    func sameLookStoresNothing() async {
        let (viewModel, useCase) = await openEditor(on: savedCV(look: CVLook(modern)))

        viewModel.chooseLook(modern)
        await viewModel.saveNow()

        #expect(await !useCase.updateCVCalled)
    }

    // MARK: - With the rest of the form

    @Test("A look survives the undoing of every other edit: it is still stored")
    func lookSurvivesUndoOfOtherEdits() async {
        let saved = savedCV()
        let (viewModel, useCase) = await openEditor(on: saved)

        viewModel.cv.personalInfo.title = "Staff engineer"
        viewModel.chooseLook(modern)
        viewModel.cv.personalInfo.title = saved.personalInfo.title
        await viewModel.saveNow()

        var expected = saved
        expected.look = CVLook(modern)
        #expect(await useCase.updatedCVs == [expected], "The title is back; the look is what is left to store")
    }

    @Test("A look and a language chosen in the sheet are both in the CV that is saved")
    func lookAndLanguageKeepEachOther() async {
        let saved = savedCV()
        let (viewModel, useCase) = await openEditor(on: saved)

        viewModel.chooseLook(modern)
        viewModel.documentLanguageSelection = .german
        viewModel.chooseLook(minimal)
        await viewModel.saveNow()

        let stored = await useCase.updatedCVs.last
        #expect(stored?.look == CVLook(minimal))
        #expect(stored?.documentLanguage == "de")
    }

    @Test("A language changed back before the save does not take the look with it")
    func languageUndoneKeepsTheLook() async {
        let saved = savedCV()
        let (viewModel, useCase) = await openEditor(on: saved)

        viewModel.documentLanguageSelection = .german
        viewModel.chooseLook(modern)
        viewModel.documentLanguageSelection = .italian
        await viewModel.saveNow()

        var expected = saved
        expected.look = CVLook(modern)
        #expect(await useCase.updatedCVs == [expected])
    }

    // MARK: - Opening

    @Test("A CV saved before the look existed opens with no look, and opening it stores nothing")
    func oldCVOpensWithoutALook() async {
        let (viewModel, useCase) = await openEditor(on: savedCV())

        await viewModel.saveNow()

        #expect(viewModel.cv.look == nil)
        #expect(await !useCase.updateCVCalled)
    }

    @Test("A stored look is there when the editor opens")
    func storedLookIsShown() async {
        let (viewModel, _) = await openEditor(on: savedCV(look: CVLook(modern)))

        #expect(viewModel.cv.look == CVLook(modern))
    }

    @Test("A look that the app does not know is kept by a save of something else")
    func unknownLookIsKept() async {
        let odd = CVLook(design: "retired-design", palette: "neon", fonts: "comic")
        let (viewModel, useCase) = await openEditor(on: savedCV(look: odd))

        viewModel.cv.personalInfo.title = "Staff engineer"
        await viewModel.saveNow()

        #expect(await useCase.updatedCVs.last?.look == odd)
    }

    // MARK: - A new CV

    @Test("A new CV, from whatever it starts with, starts with the standard look and never the look of another CV",
          arguments: ["blank", "example", "AI draft", "imported"])
    func newCVStartsWithTheStandardLook(start: String) async {
        let (template, notice): (CVModel, EditorNotice?) = switch start {
        case "blank": (CVModel(), nil)
        case "example": (CVModel(name: "Example", look: CVLook(modern)), nil)
        case "AI draft": (CVModel(name: "Draft", personalInfo: PersonalInfo(name: "Ada"), look: CVLook(minimal)), .aiDraft)
        default: (CVModel(personalInfo: PersonalInfo(name: "Ada")), .imported(ImportReview(items: [], notImported: "")))
        }

        let viewModel = CVEditorViewModel(cvId: nil, initialCV: template, notice: notice, cvManagementUseCase: MockCVManagementUseCase())

        #expect(viewModel.cv.look == CVLook.standard)
        #expect(viewModel.cv.id != template.id)
    }

    @Test("A draft is stored with the standard look")
    func draftIsStoredWithTheStandardLook() async {
        let useCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(
            cvId: nil,
            initialCV: CVModel(name: "Draft", personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com")),
            notice: .aiDraft,
            cvManagementUseCase: useCase
        )

        await viewModel.saveNow()

        #expect(await useCase.createdCVs.map(\.look) == [CVLook.standard])
    }

    @Test("A blank CV left untouched stores nothing: its standard look is no edit")
    func untouchedBlankCVStoresNothing() async {
        let useCase = MockCVManagementUseCase()
        let viewModel = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: useCase)

        await viewModel.saveNow()

        #expect(await !useCase.createCVCalled)
        #expect(await !useCase.updateCVCalled)
    }
}
