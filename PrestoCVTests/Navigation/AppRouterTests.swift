import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - AppRouter Navigation Tests

@MainActor
@Suite("AppRouter Navigation Tests")
struct AppRouterTests {

    // MARK: - Navigate To Root and Back

    @Test("navigateToRoot clears the whole navigation path, and is safe on an empty one")
    func navigateToRootClearsPath() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)

        router.navigateToRoot()
        #expect(router.navigationPath.count == 0)

        router.navigateToRoot()
        #expect(router.navigationPath.count == 0)
    }

    @Test("navigateBack removes only the last screen, and does nothing on an empty path")
    func navigateBackRemovesLastItem() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)

        router.navigateBack()
        #expect(router.navigationPath.count == 1)

        router.navigateBack()
        router.navigateBack()
        #expect(router.navigationPath.count == 0)
    }

    @Test("navigate appends the route to the path")
    func navigateAppendsRoute() {
        let router = AppRouter()

        router.navigate(to: .templateSelection)

        #expect(router.navigationPath.count == 1)
        #expect(router.currentRoute == .templateSelection)
    }

    // MARK: - Opening the Editor

    @Test("A new CV opens on its template, in place of the screens that led to it, so Back returns to the list")
    func newCVReplacesTheScreensThatLedToIt() {
        let router = AppRouter()
        router.navigate(to: .templateSelection)
        let template = CVModel(name: "Sample Template")

        router.navigateToEditorWithTemplate(template)

        #expect(router.currentRoute == .cvEditor(.new(template: template, notice: nil)), "The route carries the template")
        #expect(router.navigationPath.count == 1, "Only the editor is above the list")
    }

    @Test("An AI draft opens with its notice, in place of the AI screen, so Back returns to the list")
    func draftReplacesTheAIScreen() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)
        let draft = CVModel(name: "Drafted by AI")

        router.navigateToEditorWithAIDraft(draft)

        #expect(router.currentRoute == .cvEditor(.new(template: draft, notice: .aiDraft)))
        #expect(router.navigationPath.count == 1)
    }

    @Test("Picking a CV of the list opens it as stored")
    func pickingACVOpensIt() {
        let router = AppRouter()
        let cvId = UUID().uuidString

        router.openEditor(.stored(cvId: cvId))

        #expect(router.currentRoute == .cvEditor(.stored(cvId: cvId)))
        #expect(router.navigationPath.count == 1)
    }

    @Test("Each editor opens on its own request: nothing of the one before reaches the next")
    func eachEditorOpensOnItsOwnRequest() {
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()
        let template = CVModel(name: "Template")

        router.navigateToEditorWithTemplate(template)

        #expect(router.currentRoute == .cvEditor(.new(template: template, notice: nil)), "A template must not open as a draft")
    }

    // MARK: - AI Drafting Release Switch

    @Test("With AI drafting not shipped, navigating to it leaves the path and the route unchanged")
    func aiRouteIsRefusedWhenNotShipped() {
        let router = AppRouter(isAIShipped: false)
        router.navigate(to: .templateSelection)

        router.navigate(to: .aiGeneration)

        #expect(router.navigationPath.count == 1, "The AI route must not be appended")
        #expect(router.currentRoute == .templateSelection)
    }

    @Test("With AI drafting not shipped, a path given the AI route directly does not open the generation screen")
    func aiRouteInsertedDirectlyShowsTheList() {
        let router = AppRouter(isAIShipped: false)

        router.navigationPath.append(Route.aiGeneration)

        #expect(router.destination(for: .aiGeneration) == .list)
    }

    @Test("With AI drafting not shipped, the other routes navigate as before")
    func otherRoutesNavigateWhenNotShipped() {
        let router = AppRouter(isAIShipped: false)

        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        #expect(router.navigationPath.count == 1)
        guard case .cvEditor(.new) = router.currentRoute else {
            Issue.record("The editor should open on a new CV, not \(router.currentRoute)")
            return
        }
    }

    @Test("With AI drafting shipped, navigating to it opens the generation screen")
    func aiRouteNavigatesWhenShipped() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)

        router.navigate(to: .aiGeneration)

        #expect(router.navigationPath.count == 2)
        #expect(router.currentRoute == .aiGeneration)
        #expect(router.destination(for: .aiGeneration) == .aiGeneration)
    }
}

// MARK: - Import

@MainActor
@Suite("AppRouter - the import of a CV")
struct AppRouterImportTests {

    @Test("An imported CV opens in the editor with the notice of its review, in place of the import, so Back returns to the list")
    func importedCVOpensWithItsReview() {
        let router = AppRouter(isAIShipped: false)
        let review = ImportReview(items: [ImportReview.Item(field: .name, reason: .byPosition, text: "Lena Hartmann")], notImported: "")
        let cv = CVModel(personalInfo: PersonalInfo(name: "Lena Hartmann"))
        router.navigate(to: .templateSelection)
        router.navigate(to: .importCV)

        router.navigateToEditorWithImport(ImportedDraft(cv: cv, review: review))

        #expect(router.currentRoute == .cvEditor(.new(template: cv, notice: .imported(review))))
        #expect(router.navigationPath.count == 1, "Only the editor is above the list")
    }

    @Test("A PDF opened in the app opens the import on it once; an import on screen reads it in place")
    func openedPDFGoesToTheImport() async {
        let router = AppRouter(isAIShipped: false)
        let file = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")

        await router.openImport(of: file)
        #expect(router.currentRoute == .importCV)
        #expect(router.navigationPath.count == 1)

        await router.openImport(of: file)
        #expect(router.navigationPath.count == 1, "The import on screen reads the next PDF itself")
        #expect(router.takePendingImportFile() == file)
        #expect(router.takePendingImportFile() == nil, "A PDF is given once")
    }

    @Test("A PDF opened in the app opens the import again after the import screen was left")
    func openedPDFReopensALeftImport() async {
        let router = AppRouter(isAIShipped: false)
        router.navigate(to: .importCV)
        router.navigateBack()

        await router.openImport(of: URL(fileURLWithPath: "/tmp/Inbox/cv.pdf"))

        #expect(router.navigationPath.count == 1)
    }

    @Test("A PDF opened in the app opens the import again after another screen was opened over the import")
    func openedPDFReopensACoveredImport() async {
        let router = AppRouter(isAIShipped: false)
        router.navigate(to: .importCV)
        router.navigate(to: .cvEditor(.stored(cvId: "first")))
        router.navigateToRoot()

        await router.openImport(of: URL(fileURLWithPath: "/tmp/Inbox/cv.pdf"))

        #expect(router.currentRoute == .importCV)
        #expect(router.navigationPath.count == 1)
    }

    @Test("A PDF opened in the app before the import read the one opened earlier lets the earlier one go")
    func openedPDFReplacesAnUnreadOne() async {
        let released = RemovedFiles()
        let router = AppRouter(isAIShipped: false, releaseFile: { released.add($0) })
        let first = URL(fileURLWithPath: "/tmp/Inbox/first.pdf")
        let second = URL(fileURLWithPath: "/tmp/Inbox/second.pdf")

        await router.openImport(of: first)
        await router.openImport(of: second)
        await router.openImport(of: second)

        #expect(released.urls == [first], "The one still to read is not let go, however often it is opened")
        #expect(router.takePendingImportFile() == second)
    }

    @Test("A PDF opened in the app over an editor saves the editor at once, then the import takes its place, without a question")
    func openedPDFSavesTheEditorThenOpens() async {
        let released = RemovedFiles()
        let router = AppRouter(isAIShipped: false, releaseFile: { released.add($0) })
        let file = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")
        router.openEditor(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(saves: true)
        router.editorAppeared(editor)

        await router.openImport(of: file)

        #expect(editor.saves == 1, "The editor is saved, as leaving it does")
        #expect(router.currentRoute == .importCV)
        #expect(router.navigationPath.count == 1, "The import takes the place of the editor")
        #expect(router.takePendingImportFile() == file)
        #expect(released.urls.isEmpty, "The import has the PDF to read")
    }

    @Test("A PDF opened in the app over an editor whose edits cannot be stored opens nothing, and is let go")
    func openedPDFOverAFailingEditorIsLetGo() async {
        let released = RemovedFiles()
        let router = AppRouter(isAIShipped: false, releaseFile: { released.add($0) })
        let file = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")
        router.openEditor(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(saves: false)
        router.editorAppeared(editor)

        await router.openImport(of: file)

        #expect(editor.saves == 1)
        #expect(router.currentRoute == .cvEditor(.stored(cvId: "first")), "The editor stays, with its failure")
        #expect(router.navigationPath.count == 1)
        #expect(router.pendingImportFile == nil)
        #expect(released.urls == [file], "Nothing of a PDF no import reads is kept")
    }

    @Test("A PDF opened in the app after the editor was left opens the import without saving the editor again")
    func openedPDFAfterTheEditorWasLeft() async {
        let router = AppRouter(isAIShipped: false)
        router.openEditor(.stored(cvId: "first"))
        let editor = LeavableEditorSpy(saves: false)
        router.editorAppeared(editor)
        router.navigateBack()
        router.editorDisappeared(editor)

        await router.openImport(of: URL(fileURLWithPath: "/tmp/Inbox/cv.pdf"))

        #expect(editor.saves == 0)
        #expect(router.currentRoute == .importCV)
        #expect(router.navigationPath.count == 1)
    }

    @Test("An editor that disappears after another appeared leaves the one on screen to be saved")
    func anotherEditorDisappearing() async {
        let router = AppRouter(isAIShipped: false)
        let left = LeavableEditorSpy(saves: true)
        let shown = LeavableEditorSpy(saves: true)
        router.editorAppeared(left)
        router.openEditor(.stored(cvId: "second"))
        router.editorAppeared(shown)
        router.editorDisappeared(left)

        await router.openImport(of: URL(fileURLWithPath: "/tmp/Inbox/cv.pdf"))

        #expect(shown.saves == 1)
        #expect(left.saves == 0)
    }

    @Test("The editor on screen stores its edits before a PDF opened in the app takes its place")
    func realEditorIsStoredBeforeTheImportOpens() async throws {
        let cvs = MockCVManagementUseCase()
        let router = AppRouter(isAIShipped: false)
        let editor = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvs)
        router.openEditor(.new(template: CVModel(), notice: nil))
        router.editorAppeared(editor)
        editor.cv.personalInfo.name = "Marta Rinaldi"

        await router.openImport(of: URL(fileURLWithPath: "/tmp/Inbox/cv.pdf"))

        #expect(await cvs.createCVCallCount == 1, "Nothing waits for the pause")
        #expect(try #require(await cvs.createdCVs.first).personalInfo.name == "Marta Rinaldi")
        #expect(router.currentRoute == .importCV)
    }
}

/// An editor on screen that counts how often it is saved before it is left.
@MainActor
private final class LeavableEditorSpy: LeavableEditor {
    private let succeeds: Bool
    private(set) var saves = 0

    init(saves succeeds: Bool) {
        self.succeeds = succeeds
    }

    func saveBeforeLeaving() async -> Bool {
        saves += 1
        return succeeds
    }
}
