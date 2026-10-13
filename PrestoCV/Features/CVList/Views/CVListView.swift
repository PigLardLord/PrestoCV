import SwiftUI
import PrestoCVCore

struct CVListView: View {
    @ObservedObject var viewModel: CVListViewModel
    @EnvironmentObject var router: AppRouter
    @State private var exportTarget: CVModel?
    @State private var deleteTarget: CVModel?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = viewModel.unreadableNotice {
                InlineNotice(message: notice, actionTitle: "common.ok".localized) {
                    Task { await viewModel.dismissUnreadableNotice() }
                }
            }
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
        .sheet(item: $exportTarget) { cv in
            CVExportSheetView(cv: cv)
        }
        .confirmationDialog(
            String(localized: "cv.delete.confirmation.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let target = deleteTarget {
                Button(String(localized: "common.delete"), role: .destructive) {
                    Task { await viewModel.deleteCV(withId: target.id) }
                    showDeleteConfirmation = false
                    deleteTarget = nil
                }
                Button(String(localized: "common.cancel"), role: .cancel) {
                    showDeleteConfirmation = false
                    deleteTarget = nil
                }
            }
        } message: {
            Text(String(localized: "cv.delete.confirmation.message"))
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        EmptyStateView.noCVs {
            router.navigate(to: .templateSelection)
        }
    }
    
    private var cvListView: some View {
        DeletableList(items: viewModel.cvs) { cv in
            CVRowView(
                cv: cv,
                onTap: {
                    router.navigate(to: .cvEditor(cvId: cv.id.uuidString))
                },
                onExport: {
                    exportTarget = cv
                },
                onDelete: {
                    deleteTarget = cv
                    showDeleteConfirmation = true
                }
            )
        }
    }
}

// MARK: - CV Row View

private struct CVRowView: View {
    let cv: CVModel
    let onTap: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationRow(
            title: cv.name.isEmpty ? "cv.untitled".localized : cv.name,
            subtitle: cv.personalInfo.title.isEmpty ? nil : cv.personalInfo.title,
            caption: cv.personalInfo.location.isEmpty ? nil : cv.personalInfo.location,
            action: onTap
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .none, action: onDelete) {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
            .tint(DesignTokens.Colors.error)

            Button(action: onExport) {
                Label(String(localized: "export.swipe.action"), systemImage: "square.and.arrow.up")
            }
            .tint(DesignTokens.Colors.accent)
        }
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
