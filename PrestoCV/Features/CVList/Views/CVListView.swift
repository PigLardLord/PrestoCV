import SwiftUI
import PrestoCVCore

struct CVListView: View {
    @ObservedObject var viewModel: CVListViewModel
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        NavigationView {
            ViewStateContainer(
                viewState: viewModel.viewState,
                loadingMessage: "common.loading_cvs".asLoclizedKey,
                onRetry: viewModel.loadCVs
            ) { cvs in
                ConditionalContentView(
                    isEmpty: cvs.isEmpty,
                    content: { cvListView },
                    emptyContent: { emptyStateView }
                )
            }
            .navigationTitle("navigation.my_cvs".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        router.navigate(to: .templateSelection)
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadCVs()
            }
            .refreshable {
                await viewModel.loadCVs()
            }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        EmptyStateView.noCVs {
            router.navigate(to: .templateSelection)
        }
    }
    
    private var cvListView: some View {
        DeletableList(
            items: viewModel.cvs,
            onDelete: viewModel.performDeleteCVs
        ) { cv in
            CVRowView(cv: cv) {
                router.navigate(to: .cvEditor(cvId: cv.id.uuidString))
            }
        }
    }
}

// MARK: - CV Row View

private struct CVRowView: View {
    let cv: CVModel
    let onTap: () -> Void
    
    var body: some View {
        NavigationRow(
            title: cv.name.isEmpty ? "cv.untitled".localized : cv.name,
            subtitle: cv.personalInfo.title.isEmpty ? nil : cv.personalInfo.title,
            caption: cv.personalInfo.location.isEmpty ? nil : cv.personalInfo.location,
            action: onTap
        )
    }
}

// MARK: - Previews

struct CVListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVListView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> CVListViewModel {
        let container = DependencyContainer()
        do {
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return CVListViewModel(cvManagementUseCase: cvManagementUseCase)
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}
