import SwiftUI
import PrestoCVCore
import CVPDFExporter

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @ObservedObject private var onboardingViewModel: OnboardingViewModel
    @ObservedObject private var cvListViewModel: CVListViewModel
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let viewModelFactory: ViewModelFactory
    
    init(dependencies: RootDependencies) {
        self.onboardingViewModel = dependencies.onboardingViewModel
        self.cvListViewModel = dependencies.cvListViewModel
        self.cvManagementUseCase = dependencies.cvManagementUseCase
        self.viewModelFactory = dependencies.viewModelFactory
    }
    
    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            Group {
                switch RootDestination.resolve(onboardingViewModel.onboardingState) {
                case .loading:
                    LoadingView.fullscreen(message: "common.loading".asLoclizedKey)
                case .list:
                    listView
                case .error(let message):
                    ErrorView.generic(
                        message: message,
                        onRetry: onboardingViewModel.performCheckOnboardingStatus
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: router.destination(for: route))
            }
        }
        .environmentObject(router)
    }
    
    private var listView: some View {
        CVListView(viewModel: cvListViewModel) {
            FirstRunView(viewModel: viewModelFactory.makeNewCVChoicesViewModel())
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: RouteDestination) -> some View {
        switch destination {
        case .list:
            listView
        case .templateSelection:
            TemplateSelectionView(viewModel: viewModelFactory.makeNewCVChoicesViewModel())
        case .aiGeneration:
            AIGenerationView(viewModel: viewModelFactory.makeAIGenerationViewModel())
        case .cvEditor(let cvId):
            CVEditorView(
                viewModel: CVEditorViewModel(
                    cvId: cvId,
                    initialCV: router.initialCVForEditor,
                    cvManagementUseCase: cvManagementUseCase
                ),
                notice: router.editorNotice
            )
        }
    }
}
