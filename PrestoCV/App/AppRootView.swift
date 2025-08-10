import SwiftUI
import PrestoCVCore

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var cvListViewModel: CVListViewModel
    
    init(dependencyContainer: DependencyContainer) {
        // Create dependencies using factory methods with error handling
        do {
            let onboardingUseCase = try dependencyContainer.makeOnboardingUseCase()
            let templateRepository = try dependencyContainer.makeTemplateRepository()
            let cvManagementUseCase = try dependencyContainer.makeCVManagementUseCase()
            
            self._onboardingViewModel = StateObject(
                wrappedValue: OnboardingViewModel(
                    onboardingUseCase: onboardingUseCase,
                    templateRepository: templateRepository
                )
            )
            
            self._cvListViewModel = StateObject(
                wrappedValue: CVListViewModel(
                    cvManagementUseCase: cvManagementUseCase
                )
            )
        } catch {
            // For simplicity in this initial implementation, we'll create a fallback
            // In production, this should be handled more robustly
            fatalError("Failed to initialize dependencies: \(error)")
        }
    }
    
    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            Group {
                switch onboardingViewModel.onboardingState {
                case .loading:
                    LoadingView.fullscreen(message: "Checking your account...")
                case .firstTime:
                    OnboardingView(viewModel: onboardingViewModel)
                case .returning:
                    CVListView(viewModel: cvListViewModel)
                case .error:
                    ErrorView.generic(
                        message: onboardingViewModel.errorMessage
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
        .environmentObject(router)
        .task {
            await onboardingViewModel.checkOnboardingStatus()
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .onboarding:
            OnboardingView(viewModel: onboardingViewModel)
        case .cvList:
            CVListView(viewModel: cvListViewModel)
        case .cvEditor(let cvId):
            CVEditorView(cvId: cvId)
        case .templateSelection:
            TemplateSelectionView()
        }
    }
}

// MARK: - Placeholder Views
// LoadingView and ErrorView are now imported from DesignSystem

// OnboardingView is now in its own file


private struct CVEditorView: View {
    let cvId: String?
    
    var body: some View {
        Text("CV Editor - Placeholder")
    }
}

private struct TemplateSelectionView: View {
    var body: some View {
        Text("Template Selection - Placeholder")
    }
}