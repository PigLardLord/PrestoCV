import SwiftUI
import PrestoCVCore

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding
    @Published var initialCVForEditor: CVModel? = nil
    @Published var editorNotice: EditorNotice? = nil
    /// Edits an earlier run of the app kept, which the editor that is opened last shows.
    @Published private(set) var restoringEdits: UnsavedEdits? = nil
    /// The restored edits with the claim on them, which that editor takes. Any other route drops it, and so lets go of
    /// a claim nobody took.
    private(set) var restored: RestoredUnsavedEdits? = nil

    // MARK: - Private Properties
    private let isAIShipped: Bool

    // MARK: - Initialization
    init(isAIShipped: Bool = AIFeature.isShipped) {
        self.isAIShipped = isAIShipped
    }

    // MARK: - Navigation Methods

    func navigate(to route: Route) {
        navigate(to: route, restoring: nil)
    }

    /// Opens the editor on edits a window took to restore. The editor reads what is stored under their CV's id and
    /// shows them over it, or as a new CV.
    func navigateToEditor(restoring restored: RestoredUnsavedEdits) {
        editorNotice = nil
        navigate(to: .cvEditor(cvId: nil), restoring: restored)
    }

    /// - Parameter restored: Restored edits for the editor the route opens; any other route forgets them.
    private func navigate(to route: Route, restoring restored: RestoredUnsavedEdits?) {
        // A release that does not ship AI drafting never opens it, whoever asks
        guard route != .aiGeneration || isAIShipped else { return }
        // A notice belongs to the new CV it was set for; an existing CV never shows it.
        if case .cvEditor(let cvId) = route, cvId != nil {
            editorNotice = nil
        }
        restoringEdits = restored?.edits
        self.restored = restored
        currentRoute = route
        navigationPath.append(route)
    }

    func navigateToEditorWithTemplate(_ template: CVModel) {
        openNewCVEditor(with: template, notice: nil)
    }

    /// Opens an unsaved CV drafted by AI, with a notice asking the person to check it before saving
    func navigateToEditorWithAIDraft(_ draft: CVModel) {
        openNewCVEditor(with: draft, notice: .aiDraft)
    }

    private func openNewCVEditor(with cv: CVModel, notice: EditorNotice?) {
        initialCVForEditor = cv
        editorNotice = notice
        navigate(to: .cvEditor(cvId: nil))
    }
    
    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    /// The screen a route of the path shows, whether `navigate(to:)` appended it or not.
    func destination(for route: Route) -> RouteDestination {
        RouteDestination.resolve(route, isAIShipped: isAIShipped)
    }
}