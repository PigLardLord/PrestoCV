import SwiftUI
import PrestoCVCore
import CVPDFExporter

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
            Group {
                switch onboardingViewModel.onboardingState {
                case .loading:
                    LoadingView.fullscreen(message: "common.checking_account".asLoclizedKey)
                case .firstTime:
                    OnboardingView(viewModel: onboardingViewModel)
                case .returning:
                    CVListView(viewModel: cvListViewModel)
                case .error:
                    ErrorView.generic(
                        message: onboardingViewModel.errorMessage,
                        onRetry: onboardingViewModel.performCheckOnboardingStatus
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
        .environmentObject(router)
        .task {
            // Bootstrap bundled templates on app launch
            await bootstrapTemplates()
            // Then check onboarding status
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
        case .templateSelection:
            TemplateSelectionView(isAIGenerationAvailable: viewModelFactory.isAIGenerationAvailable())
        case .aiGeneration:
            viewWithErrorHandling {
                AIGenerationView(viewModel: try viewModelFactory.makeAIGenerationViewModel())
            }
        case .cvEditor(let cvId):
            viewWithErrorHandling {
                CVEditorView(viewModel: try viewModelFactory.makeCVEditorViewModel(cvId: cvId, initialCV: router.initialCVForEditor))
            }
        }
    }
    
    @ViewBuilder
    private func viewWithErrorHandling<Content: View>(content: () throws -> Content) -> some View {
        Group {
            if let view = try? content() {
                view
            } else {
                ErrorView.generic(
                    message: "Failed to load view. Please try again.",
                    onRetry: {
                        router.navigateBack()
                    }
                )
            }
        }
    }

    private func bootstrapTemplates() async {
        do {
            // Create bootstrap service directly to avoid circular dependency
            let bootstrapService = try TemplateBootstrapService()
            try await bootstrapService.syncBundledTemplates()
        } catch {
            // Log error but don't block app launch
            print("⚠️ Failed to bootstrap templates: \(error)")
        }
    }
}