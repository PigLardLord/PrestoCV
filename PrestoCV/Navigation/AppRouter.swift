import SwiftUI
import PrestoCVCore

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding

    // MARK: - Private Properties
    private let isAIShipped: Bool

    // MARK: - Initialization
    init(isAIShipped: Bool = AIFeature.isShipped) {
        self.isAIShipped = isAIShipped
    }

    // MARK: - Navigation Methods

    func navigate(to route: Route) {
        // A release that does not ship AI drafting never opens it, whoever asks
        guard route != .aiGeneration || isAIShipped else { return }
        currentRoute = route
        navigationPath.append(route)
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

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    /// The person leaves the editor, with Cancel, with Done, or by discarding its edits: the list of CVs shows again,
    /// whatever screens led to the editor.
    func closeEditor() {
        navigateToRoot()
    }

    /// The screen a route of the path shows, whether `navigate(to:)` appended it or not.
    func destination(for route: Route) -> RouteDestination {
        RouteDestination.resolve(route, isAIShipped: isAIShipped)
    }
}
