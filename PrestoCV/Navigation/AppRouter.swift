import SwiftUI
import PrestoCVCore

/// The editor on screen, as far as leaving it goes: it is saved before another screen takes its place.
@MainActor
protocol LeavableEditor: AnyObject {
    /// Stores what the editor shows at once, as leaving it does.
    /// - Returns: Whether the store holds what the editor shows, or there is nothing to store. False when the write
    ///   failed: the edits are only in the editor, which shows the failure.
    func saveBeforeLeaving() async -> Bool
}

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding

    /// A PDF the system opened in the app, from "Open in PrestoCV", that the import screen has not read yet.
    @Published private(set) var pendingImportFile: URL?

    // MARK: - Private Properties
    private let isAIShipped: Bool
    private let releaseFile: (URL) -> Void
    private weak var shownEditor: (any LeavableEditor)?
    /// The saves of the editors that were left, which the list and the editors wait for before they read the store.
    private let leftEditorSaves: LeftEditorSaves
    /// The depth of the path at which the import screen was pushed, while nothing has been pushed since. The screen can be
    /// left without the router knowing, by the back button.
    private var importDepth: Int?

    // MARK: - Initialization
    /// - Parameters:
    ///   - releaseFile: Lets go of a PDF opened in the app that no import will read, so that nothing of it is kept.
    ///   - leftEditorSaves: Keeps the saves of the editors that were left, for the screens that read the store.
    init(
        isAIShipped: Bool = AIFeature.isShipped,
        releaseFile: @escaping (URL) -> Void = { _ in },
        leftEditorSaves: LeftEditorSaves = LeftEditorSaves()
    ) {
        self.isAIShipped = isAIShipped
        self.releaseFile = releaseFile
        self.leftEditorSaves = leftEditorSaves
    }

    // MARK: - Navigation Methods

    func navigate(to route: Route) {
        // A release that does not ship AI drafting never opens it, whoever asks
        guard route != .aiGeneration || isAIShipped else { return }
        currentRoute = route
        navigationPath.append(route)
        importDepth = route == .importCV ? navigationPath.count : nil
    }

    /// Opens the editor on `request` in place of every screen above the list, so that Back returns to the list: the
    /// screens that led to a new CV are done with once it is open, and the editor saves by itself, so nothing is lost.
    func openEditor(_ request: EditorRequest) {
        navigationPath = NavigationPath()
        navigate(to: .cvEditor(request))
    }

    func navigateToEditorWithTemplate(_ template: CVModel) {
        openEditor(.new(template: template, notice: nil))
    }

    /// Opens a CV drafted by AI, which the editor stores as it is, with a notice asking the person to check it, and saying
    /// which items were left blank when the claim check gave no answer (ADR 0028)
    func navigateToEditorWithAIDraft(_ draft: AIDraft) {
        openEditor(.new(template: draft.cv, notice: draft.notice))
    }

    /// Opens a CV read from the person's text or PDF, which the editor stores as it is, with a notice that leads to what
    /// to check and to the text that was not imported
    func navigateToEditorWithImport(_ draft: ImportedDraft) {
        openEditor(.new(template: draft.cv, notice: .imported(draft.review)))
    }

    /// Opens a CV pasted in the AI screen and read by the import, in place of the AI screen, with the notice that says it
    /// was read as written and the review of any import (ADR 0034)
    func navigateToEditorWithImportedDescription(_ draft: ImportedDraft) {
        openEditor(.new(template: draft.cv, notice: .importedDescription(draft.review)))
    }

    /// Opens the import screen on a PDF the system opened in the app, from the share sheet or Files. A screen already on
    /// the import reads it there. An editor on screen is saved first, at once, as leaving it does, and the import takes
    /// its place; when its edits cannot be stored, the editor stays, with its failure, and the PDF is let go.
    func openImport(of file: URL) async {
        if let editor = shownEditor {
            guard await editor.saveBeforeLeaving() else {
                releaseFile(file)
                return
            }
            // Another request may have left the editor while it was saved
            if shownEditor === editor {
                shownEditor = nil
                navigateToRoot()
            }
        }
        showImport(of: file)
    }

    /// The PDF the import screen should read now, if any. It is given once.
    func takePendingImportFile() -> URL? {
        defer { pendingImportFile = nil }
        return pendingImportFile
    }

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    /// Leaves the editor with its Back button: what it shows is stored first, and the editor stays, with its failure,
    /// when that cannot be done, so that the edits are not lost with it.
    func leaveEditor(_ editor: any LeavableEditor) async {
        guard await editor.saveBeforeLeaving() else { return }
        // Another request may have taken the editor's place while it was saved, or another Back (the button and the swipe)
        // may have left it already
        guard shownEditor === editor else { return }
        shownEditor = nil
        navigateBack()
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    /// The screen a route of the path shows, whether `navigate(to:)` appended it or not.
    func destination(for route: Route) -> RouteDestination {
        RouteDestination.resolve(route, isAIShipped: isAIShipped)
    }

    /// The editor is on screen: a PDF opened in the app saves it first.
    func editorAppeared(_ editor: any LeavableEditor) {
        shownEditor = editor
    }

    /// The editor is no longer on screen, as after Back or the edge swipe: a PDF opened in the app has nothing to save
    /// first, and whatever the editor still shows is stored at once. The list and the editors wait for that save.
    func editorDisappeared(_ editor: any LeavableEditor) {
        if shownEditor === editor { shownEditor = nil }
        leftEditorSaves.begin { _ = await editor.saveBeforeLeaving() }
    }

    // MARK: - Private Methods

    private func showImport(of file: URL) {
        if let unread = pendingImportFile, unread != file { releaseFile(unread) }
        pendingImportFile = file
        if importDepth != navigationPath.count { navigate(to: .importCV) }
    }
}
