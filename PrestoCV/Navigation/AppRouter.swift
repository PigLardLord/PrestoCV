import SwiftUI
import PrestoCVCore

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding
    @Published var initialCVForEditor: CVModel? = nil
    @Published var editorNotice: EditorNotice? = nil

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
        // A notice belongs to the new CV it was set for; an existing CV never shows it.
        if case .cvEditor(let cvId) = route, cvId != nil {
            editorNotice = nil
        }
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