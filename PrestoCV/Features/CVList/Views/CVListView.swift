import SwiftUI
import PrestoCVCore

/// The list of the user's CVs, which is the root of the app. `emptyState` is what it shows while there is no CV.
struct CVListView<EmptyState: View>: View {
    @ObservedObject var viewModel: CVListViewModel
    @EnvironmentObject var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @State private var exportTarget: CVModel?
    @State private var deleteTarget: CVModel?
    @State private var rowFrames = ScreenFrames<UUID>()
    @State private var showDeleteConfirmation = false
    /// Where the row that is being deleted is on the screen, for the confirmation to point at.
    @State private var deleteAnchor: CGRect?
    @State private var renameTarget: CVModel?
    @State private var renameText = ""
    private let emptyState: EmptyState

    init(viewModel: CVListViewModel, @ViewBuilder emptyState: () -> EmptyState) {
        self.viewModel = viewModel
        self.emptyState = emptyState()
    }
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "common.loading_cvs".asLoclizedKey,
            onRetry: viewModel.loadCVs
        ) { cvs in
            ConditionalContentView(
                isEmpty: cvs.isEmpty,
                content: { cvListView },
                emptyContent: { emptyState }
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if let notice = viewModel.staleNotice {
                    InlineNotice(message: notice, actionTitle: "common.retry".localized) {
                        Task { await viewModel.loadCVs() }
                    }
                }
                if let notice = viewModel.unreadableNotice {
                    InlineNotice(message: notice, actionTitle: "common.ok".localized) {
                        Task { await viewModel.dismissUnreadableNotice() }
                    }
                }
            }
        }
        .screenTitle("navigation.my_cvs".localized, large: true)
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
        .task {
            await viewModel.keepPresentationDateCurrent()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refreshPresentationDate()
            }
        }
        .refreshable {
            await viewModel.loadCVs()
        }
        .sheet(item: $exportTarget) { cv in
            CVExportSheetView(cv: cv)
        }
        .anchoredConfirmationDialog(
            String(localized: "cv.delete.confirmation.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: deleteTarget,
            anchoredTo: deleteAnchor,
            spanningWidth: true
        ) { target in
            Button(String(localized: "common.delete"), role: .destructive) {
                Task { await viewModel.deleteCV(withId: target.id) }
                showDeleteConfirmation = false
                deleteTarget = nil
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                showDeleteConfirmation = false
                deleteTarget = nil
            }
        } message: { target in
            Text("cv.delete.confirmation.message_named".localizedWithArgs(target.listTitle))
        }
        .alert(
            "cv.rename.title".localized,
            isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } }),
            presenting: renameTarget
        ) { target in
            TextField("field.cv_name".localized, text: $renameText)
            Button("cv.action.rename".localized) {
                Task { await viewModel.renameCV(id: target.id, to: renameText) }
            }
            Button("common.cancel".localized, role: .cancel) { }
        }
        .alert(
            "common.error".localized,
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("common.ok".localized) { }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }
    
    // MARK: - View Components
    
    private var cvListView: some View {
        DeletableList(items: viewModel.cvs) { cv in
            CVRowView(
                cv: cv,
                subtitle: viewModel.personLine(of: cv),
                caption: viewModel.lastSavedLine(of: cv),
                onTap: {
                    router.navigate(to: .cvEditor(cvId: cv.id.uuidString))
                },
                onDuplicate: {
                    Task { await viewModel.duplicateCV(withId: cv.id) }
                },
                onRename: {
                    renameText = cv.name
                    renameTarget = cv
                },
                onExport: {
                    exportTarget = cv
                },
                onDelete: {
                    deleteAnchor = rowFrames.rect(for: cv.id)
                    deleteTarget = cv
                    showDeleteConfirmation = true
                }
            )
            .trackingScreenFrame(of: cv.id, in: rowFrames)
        }
        .readableContentWidth()
    }
}

// MARK: - CV Row View

private struct CVRowView: View {
    let cv: CVModel
    let subtitle: String?
    let caption: String?
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onRename: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationRow(
            title: cv.listTitle,
            subtitle: subtitle,
            caption: caption,
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
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onDuplicate) {
                Label("cv.action.duplicate".localized, systemImage: "plus.square.on.square")
            }
            .tint(DesignTokens.Colors.accent)
        }
        .contextMenu {
            Button(action: onDuplicate) {
                Label("cv.action.duplicate".localized, systemImage: "plus.square.on.square")
            }
            Button(action: onRename) {
                Label("cv.action.rename".localized, systemImage: "pencil")
            }
            Button(action: onExport) {
                Label(String(localized: "export.swipe.action"), systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews

struct CVListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVListView(viewModel: createMockViewModel()) {
                Text("navigation.my_cvs".localized)
            }
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
