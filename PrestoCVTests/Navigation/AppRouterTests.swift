import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - AppRouter Navigation Tests

@MainActor
@Suite("AppRouter Navigation Tests - Bug Fix Verification")
struct AppRouterTests {

    // MARK: - Bug Fix: Navigate to Root Clears Entire Path

    @Test("navigateToRoot clears entire navigation path")
    func navigateToRootClearsPath() {
        // Given - Multiple routes in navigation path
        let router = AppRouter()
        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        // Verify path has items
        #expect(router.navigationPath.count == 2, "Should have 2 items in path")

        // When - Navigate to root
        router.navigateToRoot()

        // Then - Path should be completely empty
        #expect(router.navigationPath.count == 0, "Navigation path should be empty after navigateToRoot")
    }

    @Test("navigateToRoot from template selection returns to CV List")
    func navigateToRootFromTemplateSelection() {
        // Given - Simulate: CV List → Template Selection
        let router = AppRouter()
        router.navigate(to: .templateSelection)

        #expect(router.navigationPath.count == 1)

        // When
        router.navigateToRoot()

        // Then - Should return to CV List (empty path)
        #expect(router.navigationPath.count == 0, "Should return to root (CV List)")
    }

    @Test("navigateToRoot from CV Editor with empty CV returns to CV List")
    func navigateToRootFromEmptyCVEditor() {
        // Given - Simulate: CV List → Template Selection → CV Editor (empty)
        let router = AppRouter()
        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        #expect(router.navigationPath.count == 2, "Should have template selection + editor in path")

        // When - User cancels from empty CV
        router.navigateToRoot()

        // Then - Should return to CV List (empty path)
        #expect(router.navigationPath.count == 0, "Should return to root (CV List) after cancel")
    }

    @Test("navigateToRoot from CV Editor with template returns to CV List")
    func navigateToRootFromTemplateCVEditor() {
        // Given - Simulate: CV List → Template Selection → CV Editor (from template)
        let router = AppRouter()
        router.navigate(to: .templateSelection)

        let template = CVModel(name: "Sample Template")
        router.navigateToEditorWithTemplate(template)

        #expect(router.navigationPath.count == 2, "Should have template selection + editor in path")

        // When - User cancels/discards
        router.navigateToRoot()

        // Then - Should return to CV List (empty path)
        #expect(router.navigationPath.count == 0, "Should return to root (CV List) after discard")
    }

    @Test("navigateToRoot from deeply nested navigation returns to root")
    func navigateToRootFromDeeplyNested() {
        // Given - Multiple navigation levels
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)
        router.navigateToEditorWithTemplate(CVModel())

        #expect(router.navigationPath.count == 3)

        // When
        router.navigateToRoot()

        // Then
        #expect(router.navigationPath.count == 0, "Should clear all navigation levels")
    }

    // MARK: - Navigate Back Tests

    @Test("navigateBack removes only last item from path")
    func navigateBackRemovesLastItem() {
        // Given
        let router = AppRouter()
        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        #expect(router.navigationPath.count == 2)

        // When
        router.navigateBack()

        // Then
        #expect(router.navigationPath.count == 1, "Should have only template selection left")
    }

    @Test("navigateBack does nothing when path is empty")
    func navigateBackOnEmptyPath() {
        // Given
        let router = AppRouter()
        #expect(router.navigationPath.count == 0)

        // When
        router.navigateBack()

        // Then
        #expect(router.navigationPath.count == 0, "Path should remain empty")
    }

    // MARK: - Navigate To Editor With Template Tests

    @Test("navigateToEditorWithTemplate opens the editor on the template, carried by its route")
    func navigateToEditorStoresTemplate() {
        // Given
        let router = AppRouter()
        let template = CVModel(name: "Test Template")

        // When
        router.navigateToEditorWithTemplate(template)

        // Then
        #expect(router.currentRoute == .cvEditor(.new(template: template, notice: nil)), "The route carries the template")
        #expect(router.navigationPath.count == 1, "Should add editor to path")
    }

    @Test("navigateToEditorWithTemplate with empty CV")
    func navigateToEditorWithEmptyCV() {
        // Given
        let router = AppRouter()
        let emptyCV = CVModel()

        // When
        router.navigateToEditorWithTemplate(emptyCV)

        // Then
        #expect(router.currentRoute == .cvEditor(.new(template: emptyCV, notice: nil)), "Even an empty CV is carried")
        #expect(router.navigationPath.count == 1, "Should add editor to path")
    }

    // MARK: - Navigate To Editor With AI Draft Tests

    @Test("navigateToEditorWithAIDraft opens an unsaved CV with the AI notice")
    func navigateToEditorWithAIDraftSetsDraftAndNotice() {
        // Given
        let router = AppRouter()
        let draft = CVModel(name: "Drafted by AI")

        // When
        router.navigateToEditorWithAIDraft(draft)

        // Then
        #expect(
            router.currentRoute == .cvEditor(.new(template: draft, notice: .aiDraft)),
            "The draft opens as a new CV, not a saved one, and the editor is told it came from AI"
        )
        #expect(router.navigationPath.count == 1, "Should add editor to path")
    }

    @Test("navigateToEditorWithTemplate does not carry the notice of an earlier AI draft")
    func navigateToEditorWithTemplateClearsNotice() {
        // Given
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()

        // When
        let template = CVModel(name: "Template")
        router.navigateToEditorWithTemplate(template)

        // Then
        #expect(router.currentRoute == .cvEditor(.new(template: template, notice: nil)), "A template must not show the AI notice")
    }

    @Test("opening an existing CV does not carry the AI notice")
    func navigateToExistingCVClearsNotice() {
        // Given
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()

        // When
        let cvId = UUID().uuidString
        router.navigate(to: .cvEditor(.stored(cvId: cvId)))

        // Then
        #expect(router.currentRoute == .cvEditor(.stored(cvId: cvId)), "A saved CV opens as stored, without the AI notice")
    }

    // MARK: - Navigation Path State Tests

    @Test("navigate appends route to path")
    func navigateAppendsRoute() {
        // Given
        let router = AppRouter()

        // When
        router.navigate(to: .templateSelection)

        // Then
        #expect(router.navigationPath.count == 1)
        #expect(router.currentRoute == .templateSelection)
    }

    @Test("multiple navigate calls build up path")
    func multipleNavigateBuildPath() {
        // Given
        let router = AppRouter(isAIShipped: true)

        // When
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)
        router.navigateToEditorWithTemplate(CVModel())

        // Then
        #expect(router.navigationPath.count == 3, "Each navigate should add to path")
    }

    // MARK: - AI Drafting Release Switch

    @Test("With AI drafting not shipped, navigating to it leaves the path and the route unchanged")
    func aiRouteIsRefusedWhenNotShipped() {
        // Given
        let router = AppRouter(isAIShipped: false)
        router.navigate(to: .templateSelection)

        // When
        router.navigate(to: .aiGeneration)

        // Then
        #expect(router.navigationPath.count == 1, "The AI route must not be appended")
        #expect(router.currentRoute == .templateSelection)
    }

    @Test("With AI drafting not shipped, a path given the AI route directly does not open the generation screen")
    func aiRouteInsertedDirectlyShowsTheList() {
        // Given
        let router = AppRouter(isAIShipped: false)

        // When - The route reaches the path without navigate(to:)
        router.navigationPath.append(Route.aiGeneration)

        // Then
        #expect(router.destination(for: .aiGeneration) == .list)
    }

    @Test("With AI drafting not shipped, the other routes navigate as before")
    func otherRoutesNavigateWhenNotShipped() {
        // Given
        let router = AppRouter(isAIShipped: false)

        // When
        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        // Then
        #expect(router.navigationPath.count == 2)
        guard case .cvEditor(.new) = router.currentRoute else {
            Issue.record("The editor should open on a new CV, not \(router.currentRoute)")
            return
        }
    }

    @Test("With AI drafting shipped, navigating to it opens the generation screen as before")
    func aiRouteNavigatesWhenShipped() {
        // Given
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)

        // When
        router.navigate(to: .aiGeneration)

        // Then
        #expect(router.navigationPath.count == 2)
        #expect(router.currentRoute == .aiGeneration)
        #expect(router.destination(for: .aiGeneration) == .aiGeneration)
    }

    // MARK: - Integration: Cancel Flow Tests

    @Test("Full cancel flow from empty CV returns to CV List")
    func fullCancelFlowFromEmptyCV() {
        // Given - User journey: CV List → + button → Empty CV → Cancel
        let router = AppRouter()

        // Step 1: User taps + button (navigates to template selection)
        router.navigate(to: .templateSelection)
        #expect(router.navigationPath.count == 1)

        // Step 2: User taps "Create new from blank" (navigates to editor with empty CV)
        router.navigateToEditorWithTemplate(CVModel())
        #expect(router.navigationPath.count == 2)

        // Step 3: User taps Cancel (without any changes)
        // In CVEditorView, handleCancelTap() calls closeEditor()
        router.closeEditor()

        // Then - Should be back at CV List (empty path)
        #expect(router.navigationPath.count == 0, "Should return to CV List after cancel")
    }

    @Test("Full discard flow from template returns to CV List")
    func fullDiscardFlowFromTemplate() {
        // Given - User journey: CV List → + button → Template → Make changes → Discard
        let router = AppRouter()

        // Step 1: User taps + button
        router.navigate(to: .templateSelection)

        // Step 2: User selects a template
        let template = CVModel(name: "Sample", personalInfo: PersonalInfo(name: "John Doe"))
        router.navigateToEditorWithTemplate(template)
        #expect(router.navigationPath.count == 2)

        // Step 3: User makes changes and then taps Cancel → Discard
        // In CVEditorView, handleDiscardChanges() calls closeEditor()
        router.closeEditor()

        // Then - Should be back at CV List
        #expect(router.navigationPath.count == 0, "Should return to CV List after discard")
    }

    @Test("Save and done flow returns to CV List")
    func saveAndDoneFlowReturnsToRoot() {
        // Given - User journey: CV List → + button → Create CV → Save → Done
        let router = AppRouter()

        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        // Step: User saves and taps Done
        // In CVEditorView, handleCancelTap() calls closeEditor()
        router.closeEditor()

        // Then - Should be back at CV List
        #expect(router.navigationPath.count == 0, "Should return to CV List after save + done")
    }

    // MARK: - Edge Cases

    @Test("navigateToRoot on already empty path is safe")
    func navigateToRootOnEmptyPathIsSafe() {
        // Given
        let router = AppRouter()
        #expect(router.navigationPath.count == 0)

        // When
        router.navigateToRoot()

        // Then - Should not crash or cause issues
        #expect(router.navigationPath.count == 0)
    }

    // MARK: - Restoring Unsaved Edits

    private func keptEdits(over base: CVModel?) -> UnsavedEdits {
        UnsavedEdits(id: UUID(), cv: CVModel(name: "Kept"), base: base, keptAt: Date())
    }

    private func restored(_ edits: UnsavedEdits) -> RestoredUnsavedEdits {
        RestoredUnsavedEdits(edits: edits, claim: nil, useCase: nil)
    }

    @Test("Restoring edits opens the editor with them, which reads the CV stored under their id itself")
    func restoringEditsOpensTheEditorWithThem() {
        let router = AppRouter()
        let restoredEdits = restored(keptEdits(over: CVModel(name: "Stored")))

        router.navigateToEditor(restoring: restoredEdits)

        #expect(router.currentRoute == .cvEditor(.restoring(restoredEdits)))
        #expect(router.navigationPath.count == 1)
    }

    @Test("Restored edits open without the notice of an AI draft")
    func restoredEditsOpenWithoutTheAINotice() {
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Draft"))
        router.navigateToRoot()
        let restoredEdits = restored(keptEdits(over: nil))

        router.navigateToEditor(restoring: restoredEdits)

        #expect(
            router.currentRoute == .cvEditor(.restoring(restoredEdits)),
            "Restored edits are the person's own, not a draft to check"
        )
    }

    @Test("Each editor opens on its own request: nothing of the restored edits reaches the next one")
    func otherEditorsForgetTheRestoredEdits() {
        let router = AppRouter()
        router.navigateToEditor(restoring: restored(keptEdits(over: CVModel(name: "Stored"))))
        router.navigateToRoot()

        let cvId = UUID().uuidString
        router.navigate(to: .cvEditor(.stored(cvId: cvId)))
        #expect(router.currentRoute == .cvEditor(.stored(cvId: cvId)), "A CV opened from the list shows what is stored")

        router.navigateToRoot()
        router.navigateToEditor(restoring: restored(keptEdits(over: nil)))
        let template = CVModel(name: "Template")
        router.navigateToEditorWithTemplate(template)
        #expect(
            router.currentRoute == .cvEditor(.new(template: template, notice: nil)),
            "A new CV from a template starts from the template"
        )
    }

    @Test("Each new CV opens on its own template")
    func initialCVForEditorCanBeUpdated() {
        // Given
        let router = AppRouter()

        // When
        let cv1 = CVModel(name: "First")
        router.navigateToEditorWithTemplate(cv1)
        #expect(router.currentRoute == .cvEditor(.new(template: cv1, notice: nil)))

        router.navigateBack()

        let cv2 = CVModel(name: "Second")
        router.navigateToEditorWithTemplate(cv2)

        // Then
        #expect(router.currentRoute == .cvEditor(.new(template: cv2, notice: nil)), "Should open on the new template")
    }

    @Test("Two restores of the same edits are two requests, each with its own claim")
    func restoresAreRequestsOfTheirOwn() {
        let edits = keptEdits(over: nil)
        let first = restored(edits)

        #expect(EditorRequest.restoring(first) == .restoring(first))
        #expect(EditorRequest.restoring(first) != .restoring(restored(edits)))
        #expect(EditorRequest.new(template: CVModel(), notice: nil) != .new(template: CVModel(), notice: nil), "Two blank CVs are two CVs")
    }

    // MARK: - Leaving the Editor

    @Test("closeEditor returns to the list, whatever screens led to the editor")
    func closeEditorReturnsToTheList() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)
        router.navigateToEditorWithAIDraft(CVModel(name: "Draft"))

        router.closeEditor()

        #expect(router.navigationPath.count == 0)
    }

    @Test("Picking a CV with no editor on screen opens it")
    func selectingWithoutAnEditorOpensIt() {
        let router = AppRouter()
        let cvId = UUID().uuidString

        router.select(.stored(cvId: cvId))

        #expect(router.currentRoute == .cvEditor(.stored(cvId: cvId)))
        #expect(router.navigationPath.count == 1)
        #expect(router.pendingSelection == nil)
    }

    @Test("Picking another CV while the editor has nothing unsaved opens it in place of the editor")
    func selectingReplacesAnEditorWithNothingUnsaved() {
        let router = AppRouter()
        router.select(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(leaving: .allowed)
        router.editorAppeared(editor)

        router.select(.stored(cvId: "second"))

        #expect(editor.leaveRequests == 1, "The editor is asked first")
        #expect(router.currentRoute == .cvEditor(.stored(cvId: "second")))
        #expect(router.navigationPath.count == 1, "The second editor takes the place of the first")
        #expect(router.pendingSelection == nil)
    }

    @Test("Picking another CV while the editor has unsaved edits waits for the person to discard them")
    func selectingWaitsForTheDiscard() {
        let router = AppRouter()
        router.select(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(leaving: .asksFirst)
        router.editorAppeared(editor)

        router.select(.stored(cvId: "second"))

        #expect(editor.showingCancelConfirmation, "The editor asks whether to discard the edits")
        #expect(router.currentRoute == .cvEditor(.stored(cvId: "first")), "Nothing opens before the answer")
        #expect(router.pendingSelection == .stored(cvId: "second"))

        // The person discards the edits
        router.closeEditor()

        #expect(router.currentRoute == .cvEditor(.stored(cvId: "second")))
        #expect(router.navigationPath.count == 1)
        #expect(router.pendingSelection == nil)
    }

    @Test("Keeping the edits drops the CV picked meanwhile: leaving later shows the list")
    func keepingTheEditsDropsTheSelection() {
        let router = AppRouter()
        router.select(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(leaving: .asksFirst)
        router.editorAppeared(editor)
        router.select(.stored(cvId: "second"))

        router.keepEditing()
        router.closeEditor()

        #expect(editor.leaveRequests == 1)
        #expect(router.navigationPath.count == 0)
        #expect(router.pendingSelection == nil)
    }

    @Test("Picking another CV while a save is running opens nothing, now or later")
    func selectingWhileSavingOpensNothing() {
        let router = AppRouter()
        router.select(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(leaving: .refused)
        router.editorAppeared(editor)

        router.select(.stored(cvId: "second"))
        router.closeEditor()

        #expect(editor.leaveRequests == 1)
        #expect(router.navigationPath.count == 0, "Leaving after the save shows the list, not the CV picked during it")
        #expect(router.pendingSelection == nil)
    }

    @Test("The editor asks before another CV takes its place when it has unsaved edits")
    func realEditorAsksBeforeTheSelectionChanges() {
        let router = AppRouter()
        router.select(.stored(cvId: "first"))
        let editor = CVEditorViewModel(cvId: nil, initialCV: CVModel(), cvManagementUseCase: MockCVManagementUseCase())
        editor.cv.personalInfo.name = "Marta Rinaldi"
        router.editorAppeared(editor)

        router.select(.stored(cvId: "second"))

        #expect(editor.showingCancelConfirmation)
        #expect(router.currentRoute == .cvEditor(.stored(cvId: "first")))
        #expect(router.pendingSelection == .stored(cvId: "second"))
    }
}

/// An editor that answers the request to leave it as the test says.
@MainActor
private final class LeavableEditorSpy: LeavableEditor {
    enum Leaving {
        /// Nothing would be lost
        case allowed
        /// The editor has unsaved edits and asks whether to discard them
        case asksFirst
        /// A save is running: the editor cannot be left yet
        case refused
    }

    private let leaving: Leaving
    private(set) var leaveRequests = 0
    private(set) var showingCancelConfirmation = false

    init(leaving: Leaving) {
        self.leaving = leaving
    }

    func requestLeaving() -> Bool {
        leaveRequests += 1
        showingCancelConfirmation = leaving == .asksFirst
        return leaving == .allowed
    }
}

// MARK: - Import

@MainActor
@Suite("AppRouter - the import of a CV")
struct AppRouterImportTests {

    @Test("An imported CV opens in the editor as a new CV, with the notice of its review")
    func importedCVOpensWithItsReview() {
        let router = AppRouter(isAIShipped: false)
        let review = ImportReview(items: [ImportReview.Item(field: .name, reason: .byPosition, text: "Lena Hartmann")], notImported: "")
        let cv = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann"))

        router.navigate(to: .importCV)
        router.navigateToEditorWithImport(ImportedDraft(cv: cv, review: review))

        #expect(router.currentRoute == .cvEditor(.new(template: cv, notice: .imported(review))))
        #expect(router.navigationPath.count == 2)
    }

    @Test("A PDF opened in the app opens the import on it once; an import on screen reads it in place")
    func openedPDFGoesToTheImport() {
        let router = AppRouter(isAIShipped: false)
        let file = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")

        router.openImport(of: file)
        #expect(router.currentRoute == .importCV)
        #expect(router.navigationPath.count == 1)

        router.openImport(of: file)
        #expect(router.navigationPath.count == 1, "The import on screen reads the next PDF itself")
        #expect(router.takePendingImportFile() == file)
        #expect(router.takePendingImportFile() == nil, "A PDF is given once")
    }
}
