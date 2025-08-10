import SwiftUI
import PrestoCVCore

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var onboardingViewModel: OnboardingViewModel
    
    init(dependencyContainer: DependencyContainer) {
        // Create dependencies using factory methods with error handling
        do {
            let onboardingUseCase = try dependencyContainer.makeOnboardingUseCase()
            let templateRepository = try dependencyContainer.makeTemplateRepository()
            
            self._onboardingViewModel = StateObject(
                wrappedValue: OnboardingViewModel(
                    onboardingUseCase: onboardingUseCase,
                    templateRepository: templateRepository
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
                    LoadingView()
                case .firstTime:
                    OnboardingView(viewModel: onboardingViewModel)
                case .returning:
                    CVListView()
                case .error:
                    ErrorView(message: onboardingViewModel.errorMessage)
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
            CVListView()
        case .cvEditor(let cvId):
            CVEditorView(cvId: cvId)
        case .templateSelection:
            TemplateSelectionView()
        }
    }
}

// MARK: - Placeholder Views

private struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .padding(.top)
        }
    }
}

private struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.largeTitle)
            Text("Error")
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        Text("Onboarding - Placeholder")
    }
}

private struct CVListView: View {
    var body: some View {
        Text("CV List - Placeholder")
    }
}

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