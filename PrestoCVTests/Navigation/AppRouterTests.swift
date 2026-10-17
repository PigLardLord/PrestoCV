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
        router.navigate(to: .cvEditor(cvId: nil))

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
        router.navigate(to: .cvEditor(cvId: nil))

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
        router.navigate(to: .cvEditor(cvId: nil))

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

    @Test("navigateToEditorWithTemplate stores initialCV")
    func navigateToEditorStoresTemplate() {
        // Given
        let router = AppRouter()
        let template = CVModel(name: "Test Template")

        // When
        router.navigateToEditorWithTemplate(template)

        // Then
        #expect(router.initialCVForEditor != nil, "initialCVForEditor should be set")
        #expect(router.initialCVForEditor?.name == "Test Template", "Template should be stored")
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
        #expect(router.initialCVForEditor != nil, "initialCVForEditor should be set even for empty CV")
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
        #expect(router.initialCVForEditor == draft, "The draft should be handed to the editor")
        #expect(router.editorNotice == .aiDraft, "The editor should be told the CV came from AI")
        #expect(router.navigationPath.count == 1, "Should add editor to path")
        #expect(router.currentRoute == .cvEditor(cvId: nil), "The draft opens as a new CV, not a saved one")
    }

    @Test("navigateToEditorWithTemplate clears the notice of an earlier AI draft")
    func navigateToEditorWithTemplateClearsNotice() {
        // Given
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()

        // When
        router.navigateToEditorWithTemplate(CVModel(name: "Template"))

        // Then
        #expect(router.editorNotice == nil, "A template must not show the AI notice")
    }

    @Test("opening an existing CV clears the AI notice")
    func navigateToExistingCVClearsNotice() {
        // Given
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()

        // When
        router.navigate(to: .cvEditor(cvId: UUID().uuidString))

        // Then
        #expect(router.editorNotice == nil, "A saved CV must not show the AI notice")
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
        router.navigate(to: .cvEditor(cvId: nil))

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
        #expect(router.currentRoute == .cvEditor(cvId: nil))
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
        // In CVEditorView, handleCancelTap() calls navigateToRoot()
        router.navigateToRoot()

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
        // In CVEditorView, handleDiscardChanges() calls navigateToRoot()
        router.navigateToRoot()

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
        // In CVEditorView, handleSaveConfirmationDone() calls navigateToRoot()
        router.navigateToRoot()

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
        let edits = keptEdits(over: CVModel(name: "Stored"))

        router.navigateToEditor(restoring: restored(edits))

        #expect(router.currentRoute == .cvEditor(cvId: nil))
        #expect(router.restoringEdits == edits)
        #expect(router.navigationPath.count == 1)
    }

    @Test("Restored edits open without the notice of an AI draft")
    func restoredEditsOpenWithoutTheAINotice() {
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Draft"))
        router.navigateToRoot()
        let edits = keptEdits(over: nil)

        router.navigateToEditor(restoring: restored(edits))

        #expect(router.restoringEdits == edits)
        #expect(router.editorNotice == nil, "Restored edits are the person's own, not a draft to check")
    }

    @Test("Opening any other editor afterwards forgets the restored edits")
    func otherEditorsForgetTheRestoredEdits() {
        let router = AppRouter()
        router.navigateToEditor(restoring: restored(keptEdits(over: CVModel(name: "Stored"))))
        router.navigateToRoot()

        router.navigate(to: .cvEditor(cvId: UUID().uuidString))
        #expect(router.restoringEdits == nil, "A CV opened from the list shows what is stored")

        router.navigateToRoot()
        router.navigateToEditor(restoring: restored(keptEdits(over: nil)))
        router.navigateToEditorWithTemplate(CVModel(name: "Template"))
        #expect(router.restoringEdits == nil, "A new CV from a template starts from the template")
    }

    @Test("initialCVForEditor can be updated multiple times")
    func initialCVForEditorCanBeUpdated() {
        // Given
        let router = AppRouter()

        // When
        let cv1 = CVModel(name: "First")
        router.navigateToEditorWithTemplate(cv1)
        #expect(router.initialCVForEditor?.name == "First")

        router.navigateBack()

        let cv2 = CVModel(name: "Second")
        router.navigateToEditorWithTemplate(cv2)

        // Then
        #expect(router.initialCVForEditor?.name == "Second", "Should update to new template")
    }
}
