import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: CVEditorViewModel
    private let makeExportSheet: @MainActor (CVEditorViewModel) -> CVExportSheetViewModel
    @State private var showingExportSheet = false
    @State private var deletionAnchor = RowDeletionAnchor()
    @StateObject private var keyboard = KeyboardVisibility(notificationCenter: .default)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    private var chrome: EditorChrome {
        EditorChrome(verticalSizeClass: verticalSizeClass, dynamicTypeSize: dynamicTypeSize)
    }

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    /// - Parameter makeExportSheet: Gives the export sheet of the CV as the editor shows it.
    init(
        viewModel: @autoclosure @escaping () -> CVEditorViewModel,
        makeExportSheet: @escaping @MainActor (CVEditorViewModel) -> CVExportSheetViewModel
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.makeExportSheet = makeExportSheet
    }
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "cv.loading",
            onRetry: viewModel.loadCV
        ) { _ in
            editorView
        }
        .screenTitle(viewModel.screenTitle)
        // Back and the edge swipe would leave without the discard confirmation that Cancel asks for
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Leading: Cancel, with confirmation if there are unsaved changes, or Done once everything is saved
            ToolbarItem(placement: .navigationBarLeading) {
                BarButton(
                    title: exitTitle, systemImage: "xmark", screenTextSize: dynamicTypeSize,
                    action: handleCancelTap
                )
                .foregroundColor(DesignTokens.Colors.accent)
            }
            
            // Trailing, in one capsule: export, in every layout, then Save with its unsaved-changes dot. Both show their
            // symbols, which leave the title its room in every language, also in portrait on an iPhone
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("export.button.title".localized, systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!viewModel.canExport)
                    .accessibilityShowsLargeContentViewer {
                        Label("export.button.title".localized, systemImage: "square.and.arrow.up")
                    }

                    UnsavedChangesIndicator.warning(isVisible: viewModel.hasUnsavedChanges)
                    Button(action: handleSaveTap) {
                        Label("common.save".localized, systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!viewModel.isSaveButtonEnabled)
                    .foregroundColor(saveButtonColor)
                    .fontWeight(.semibold)
                    .accessibilityShowsLargeContentViewer {
                        Label("common.save".localized, systemImage: "checkmark")
                    }
                }
            }
        }
        .onAppear {
            router.editorAppeared(viewModel)
        }
        .task {
            // Load CV data when the view appears
            await viewModel.loadCV()
        }
        .onChange(of: scenePhase) { _, phase in
            Task { await viewModel.sceneDidChange(isActive: phase == .active) }
        }
        .onChange(of: viewModel.showsSavedConfirmation) { _, isShown in
            if isShown {
                AccessibilityNotification.Announcement("editor.saved".localized).post()
            }
        }
        .alert("common.error".localized, isPresented: .constant(viewModel.isShowingError)) {
            Button("common.ok".localized, action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("dialog.discard_changes.title".localized, isPresented: $viewModel.showingCancelConfirmation) {
            Button("common.discard".localized, role: .destructive, action: handleDiscardChanges)
            Button("editor.keep_editing".localized, role: .cancel) { router.keepEditing() }
        } message: {
            Text("dialog.discard_changes.message".asLoclizedKey)
        }
        .environment(\.rowDeletionAnchor, deletionAnchor)
        .anchoredConfirmationDialog(
            "editor.delete_row.title".localized,
            isPresented: isShowingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: viewModel.pendingDeletion,
            anchoredTo: deletionAnchor.rect
        ) { deletion in
            Button("common.delete".localized, role: .destructive) {
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    viewModel.confirmDeletion(deletion)
                }
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: { deletion in
            Text("editor.delete_row.message".localizedWithArgs(deletion.rowName))
        }
        .sheet(isPresented: $showingExportSheet) {
            CVExportSheetView(viewModel: makeExportSheet(viewModel))
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        VStack(spacing: 0) {
            if let notice = viewModel.notice {
                EditorNoticeBanner(notice: notice)
            }

            // Each tab shows the confirmation of a save itself, below the tab bar that iPad shows at the top
            TabView {
                PersonalInfoSection(
                    cv: $viewModel.cv,
                    documentLanguage: $viewModel.documentLanguageSelection,
                    automaticLanguageTitle: viewModel.automaticDocumentLanguageTitle,
                    documentLanguageTitle: viewModel.documentLanguageTitle,
                    nameStatus: viewModel.nameStatus,
                    emailStatus: viewModel.emailStatus,
                    phoneStatus: viewModel.phoneStatus,
                    portfolioStatus: viewModel.portfolioStatus,
                    onLeave: { viewModel.fieldWasLeft($0) }
                )
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .savedConfirmation(isShown: viewModel.showsSavedConfirmation)
                    .tabItem {
                        Label("section.basics".localized, systemImage: "person.circle")
                    }

                ExperienceSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .savedConfirmation(isShown: viewModel.showsSavedConfirmation)
                    .tabItem {
                        Label("section.experience".localized, systemImage: "briefcase")
                    }

                DetailsSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .savedConfirmation(isShown: viewModel.showsSavedConfirmation)
                    .tabItem {
                        Label("section.details".localized, systemImage: "list.bullet.circle")
                    }
            }
            .tabBarMinimizeBehavior(chrome.minimizesTabBar ? .onScrollDown : .never)
            .background(DesignTokens.Colors.background)
            .readableContentWidth()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("editor.title".localized)
            .accessibilityHint("accessibility.editor_hint".localized)
        }
    }
    
    private var saveButtonColor: Color {
        viewModel.isSaveButtonEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.disabledButtonForeground
    }
    
    private var exitTitle: String {
        switch viewModel.exit {
        case .cancel: return "common.cancel".localized
        case .done: return "common.done".localized
        }
    }
    
    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeletion != nil },
            set: { isShowing in
                if !isShowing {
                    deletionAnchor.rect = nil
                    viewModel.cancelDeletion()
                }
            }
        )
    }
    
    // MARK: - Action Handlers
    
    private func handleCancelTap() {
        if viewModel.requestLeaving() {
            router.closeEditor()
        }
    }
    
    private func handleSaveTap() {
        Task {
            await viewModel.handleSaveButtonTap()
        }
    }
    
    private func handleDiscardChanges() {
        viewModel.confirmCancel()
        router.closeEditor()
    }
}

// MARK: - Previews

#if DEBUG
struct CVEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVEditorView(viewModel: PreviewDependencies.editor()) { editor in
                PreviewDependencies.exportSheet(for: editor.cv, sink: { editor.documentLanguageSelection = $0 })
            }
        }
        .environmentObject(AppRouter())
    }
}
#endif
