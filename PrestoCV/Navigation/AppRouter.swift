import SwiftUI
import PrestoCVCore

/// The editor on screen, as far as leaving it goes: it is asked before another CV takes its place.
@MainActor
protocol LeavableEditor: AnyObject {
    /// True when the editor can go at once. Otherwise it asks the person whether to discard the edits, and is left with
    /// `AppRouter.closeEditor()` once they are discarded, or it cannot be left yet, while a save is running.
    func requestLeaving() -> Bool
    /// The editor is asking the person whether to discard the edits.
    var showingCancelConfirmation: Bool { get }
}

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding

    /// The CV the person picked while the editor on screen was asking whether to discard its edits. It opens once they
    /// are discarded, and is dropped when the person keeps editing.
    var pendingSelection: EditorRequest? {
        if case .editor(let request) = waitingForEditor { request } else { nil }
    }

    /// A PDF the system opened in the app, from "Open in PrestoCV", that the import screen has not read yet.
    @Published private(set) var pendingImportFile: URL?

    // MARK: - Private Properties

    /// What opens once the editor on screen is left. The latest request replaces the one before.
    private enum Opening: Equatable {
        case editor(EditorRequest)
        case importFile(URL)
    }

    private let isAIShipped: Bool
    private let releaseFile: (URL) -> Void
    private weak var shownEditor: (any LeavableEditor)?
    /// What waits while the editor on screen asks the person whether to discard its edits.
    private var waitingForEditor: Opening?
    /// The depth of the path at which the import screen was pushed, while nothing has been pushed since. The screen can be
    /// left without the router knowing, by the back button.
    private var importDepth: Int?

    // MARK: - Initialization
    /// - Parameter releaseFile: Lets go of a PDF opened in the app that no import will read, so that nothing of it is
    ///   kept.
    init(isAIShipped: Bool = AIFeature.isShipped, releaseFile: @escaping (URL) -> Void = { _ in }) {
        self.isAIShipped = isAIShipped
        self.releaseFile = releaseFile
    }

    // MARK: - Navigation Methods

    func navigate(to route: Route) {
        // A release that does not ship AI drafting never opens it, whoever asks
        guard route != .aiGeneration || isAIShipped else { return }
        currentRoute = route
        navigationPath.append(route)
        importDepth = route == .importCV ? navigationPath.count : nil
    }

    /// Opens the editor on edits a window took to restore. The editor reads what is stored under their CV's id and
    /// shows them over it, or as a new CV.
    func navigateToEditor(restoring restored: RestoredUnsavedEdits) {
        navigate(to: .cvEditor(.restoring(restored)))
    }

    func navigateToEditorWithTemplate(_ template: CVModel) {
        navigate(to: .cvEditor(.new(template: template, notice: nil)))
    }

    /// Opens an unsaved CV drafted by AI, with a notice asking the person to check it before saving
    func navigateToEditorWithAIDraft(_ draft: CVModel) {
        navigate(to: .cvEditor(.new(template: draft, notice: .aiDraft)))
    }

    /// Opens the import screen on a PDF the system opened in the app, from the share sheet or Files. A screen already on
    /// the import reads it there. An editor on screen is asked first, as when another CV is picked: the import waits
    /// until the person discards the edits, and the PDF is let go when they keep editing.
    func openImport(of file: URL) {
        open(.importFile(file))
    }

    /// The PDF the import screen should read now, if any. It is given once.
    func takePendingImportFile() -> URL? {
        defer { pendingImportFile = nil }
        return pendingImportFile
    }

    /// Opens an unsaved CV read from the person's text or PDF, as an example opens, with a notice that leads to what to
    /// check and to the text that was not imported
    func navigateToEditorWithImport(_ draft: ImportedDraft) {
        navigate(to: .cvEditor(.new(template: draft.cv, notice: .imported(draft.review))))
    }

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    /// The person leaves the editor, with Cancel, with Done, or by discarding its edits. The CV picked meanwhile opens;
    /// otherwise the list of CVs shows again, whatever screens led to the editor.
    func closeEditor() {
        shownEditor = nil
        navigateToRoot()
        if let opening = waitingForEditor {
            waitingForEditor = nil
            show(opening)
        }
    }

    /// The screen a route of the path shows, whether `navigate(to:)` appended it or not.
    func destination(for route: Route) -> RouteDestination {
        RouteDestination.resolve(route, isAIShipped: isAIShipped)
    }

    // MARK: - Selecting a CV

    /// The editor is on screen: the next selection asks it first.
    func editorAppeared(_ editor: any LeavableEditor) {
        shownEditor = editor
    }

    /// Opens the editor on `request` in place of the editor on screen, if any. An editor that has unsaved edits is
    /// asked first, and the new one waits until they are discarded; while a save is running, nothing opens.
    func select(_ request: EditorRequest) {
        open(.editor(request))
    }

    /// The person keeps editing instead of discarding the edits: the CV picked meanwhile does not open, and the PDF
    /// opened meanwhile is let go.
    func keepEditing() {
        wait(for: nil)
    }

    // MARK: - Private Methods

    /// Shows `opening` in place of the editor on screen, if any, once the editor can be left.
    private func open(_ opening: Opening) {
        guard let shownEditor else {
            show(opening)
            return
        }
        wait(for: opening)
        if shownEditor.requestLeaving() {
            closeEditor()
        } else if !shownEditor.showingCancelConfirmation {
            wait(for: nil)
        }
    }

    private func show(_ opening: Opening) {
        switch opening {
        case .editor(let request):
            navigate(to: .cvEditor(request))
        case .importFile(let file):
            if let unread = pendingImportFile, unread != file { releaseFile(unread) }
            pendingImportFile = file
            if importDepth != navigationPath.count { navigate(to: .importCV) }
        }
    }

    /// Makes `opening` the one that waits for the editor, or none. What waited before does not open: a PDF is let go,
    /// unless it is the one that waits now.
    private func wait(for opening: Opening?) {
        if case .importFile(let file) = waitingForEditor, waitingForEditor != opening { releaseFile(file) }
        waitingForEditor = opening
    }
}
