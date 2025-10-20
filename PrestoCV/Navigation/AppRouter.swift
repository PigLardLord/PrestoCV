import SwiftUI
import PrestoCVCore

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding
    @Published var initialCVForEditor: CVModel? = nil

    // MARK: - Navigation Methods

    func navigate(to route: Route) {
        currentRoute = route
        navigationPath.append(route)
    }

    func navigateToEditorWithTemplate(_ template: CVModel) {
        initialCVForEditor = template
        navigate(to: .cvEditor(cvId: nil))
    }
    
    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }
    
    func replace(with route: Route) {
        currentRoute = route
        navigationPath = NavigationPath()
    }
}