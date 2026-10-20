import SwiftUI
import PrestoCVCore
import CVPDFExporter

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @ObservedObject private var onboardingViewModel: OnboardingViewModel
    @ObservedObject private var cvListViewModel: CVListViewModel
    private let viewModelFactory: ViewModelFactory
    
    init(dependencies: RootDependencies) {
        self.onboardingViewModel = dependencies.onboardingViewModel
        self.cvListViewModel = dependencies.cvListViewModel
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
        CVListView(
            viewModel: cvListViewModel,
            makeExportSheet: { viewModelFactory.makeExportSheetViewModel(exporting: $0, from: cvListViewModel) }
        ) {
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
        case .cvEditor(let request):
            CVEditorView(
                viewModel: viewModelFactory.makeCVEditorViewModel(for: request),
                makeExportSheet: viewModelFactory.makeExportSheetViewModel(editing:)
            )
        }
    }
}
