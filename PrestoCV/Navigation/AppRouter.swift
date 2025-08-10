import SwiftUI
import PrestoCVCore

@MainActor
final class AppRouter: ObservableObject {
    
    // MARK: - Published Properties
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: Route = .onboarding
    
    // MARK: - Navigation Methods
    
    func navigate(to route: Route) {
        currentRoute = route
        navigationPath.append(route)
    }
    
    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    func navigateToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }
    
    func replace(with route: Route) {
        currentRoute = route
        navigationPath = NavigationPath()
    }
}