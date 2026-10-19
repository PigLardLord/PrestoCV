import SwiftUI
import PrestoCVCore
import CVPDFExporter

struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @ObservedObject private var onboardingViewModel: OnboardingViewModel
    @ObservedObject private var cvListViewModel: CVListViewModel
    @ObservedObject private var unsavedEditsOffer: UnsavedEditsOfferViewModel
    private let viewModelFactory: ViewModelFactory
    
    init(dependencies: RootDependencies) {
        self.onboardingViewModel = dependencies.onboardingViewModel
        self.cvListViewModel = dependencies.cvListViewModel
        self.unsavedEditsOffer = dependencies.unsavedEditsOfferViewModel
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
            // At launch, and each time the root shows again, edits an earlier run left unsaved are offered
            .task {
                await unsavedEditsOffer.checkForEditsToRestore()
            }
            .alert(
                "unsaved_edits.restore.title".localized,
                isPresented: $unsavedEditsOffer.isShowingOffer,
                presenting: unsavedEditsOffer.offer
            ) { _ in
                Button(restoreActionTitle, action: restoreUnsavedEdits)
                    .keyboardShortcut(.defaultAction)
                Button("common.discard".localized, role: .destructive) {
                    Task { await unsavedEditsOffer.discard() }
                }
            } message: { _ in
                Text(unsavedEditsOffer.message ?? "")
            }
        }
        // Apart from the offer: the two alerts follow one another
        .alert("unsaved_edits.unavailable.title".localized, isPresented: $unsavedEditsOffer.isShowingNoLongerAvailable) {
            Button("common.ok".localized) { }
        } message: {
            Text("unsaved_edits.unavailable.message".localized)
        }
        .environmentObject(router)
    }
    
    private var restoreActionTitle: String {
        unsavedEditsOffer.restoresAsCopy ? "unsaved_edits.restore.as_copy".localized : "unsaved_edits.restore.action".localized
    }
    
    private func restoreUnsavedEdits() {
        Task {
            if let restored = await unsavedEditsOffer.restore() {
                router.navigateToEditor(restoring: restored)
            }
        }
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
