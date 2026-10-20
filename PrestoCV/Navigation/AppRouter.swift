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

    /// Opens the editor on `request` in place of every screen above the list, so that Back returns to the list: the
    /// screens that led to a new CV are done with once it is open, and the editor saves by itself, so nothing is lost.
    func openEditor(_ request: EditorRequest) {
        navigationPath = NavigationPath()
        navigate(to: .cvEditor(request))
    }

    func navigateToEditorWithTemplate(_ template: CVModel) {
        openEditor(.new(template: template))
    }

    /// Opens a CV drafted by AI, with a notice asking the person to check it
    func navigateToEditorWithAIDraft(_ draft: CVModel) {
        openEditor(.draft(draft))
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
