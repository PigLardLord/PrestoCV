import SwiftUI
import PrestoCVCore

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var cvListViewModel: CVListViewModel
    private let dependencyContainer: DependencyContainer
    private let viewModelFactory: ViewModelFactory
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        self.viewModelFactory = ViewModelFactory(dependencyContainer: dependencyContainer)
        
        // Create dependencies using factory methods with error handling
        do {
            let onboardingUseCase = try dependencyContainer.makeOnboardingUseCase()
            let sampleRepository = try dependencyContainer.makeSampleCVRepository()
            let cvManagementUseCase = try dependencyContainer.makeCVManagementUseCase()
            
            self._onboardingViewModel = StateObject(
                wrappedValue: OnboardingViewModel(
                    onboardingUseCase: onboardingUseCase,
                    sampleRepository: sampleRepository
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
            VStack {
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
                            message: onboardingViewModel.errorMessage,
                            onRetry: {
                                Task {
                                    await onboardingViewModel.checkOnboardingStatus()
                                }
                            }
                        )
                    }
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
            templateSelectionView(route: .cvEditor(cvId: cvId))
        case .templateSelection:
            templateSelectionView(route: .templateSelection)
        }
    }
    
    @ViewBuilder
    @MainActor
    private func templateSelectionView(route: Route) -> some View {
        // Try to create the view model, fallback to error view if it fails
        switch route {
        case .templateSelection:
            if let viewModel = try? viewModelFactory.makeTemplateSelectionViewModel() {
                TemplateSelectionView(viewModel: viewModel)
            } else {
                ErrorView.generic(
                    message: "Failed to load template selection. Please try again.",
                    onRetry: {}
                )
            }
        case .cvEditor(let cvId):
            if let viewModel = try? viewModelFactory.makeCVEditorViewModel(cvId: cvId) {
                CVEditorView(viewModel: viewModel)
            } else {
                ErrorView.generic(
                    message: "Failed to load CV editor. Please try again.",
                    onRetry: {}
                )
            }
        default:
            Text("Unknown route")
        }
    }
}