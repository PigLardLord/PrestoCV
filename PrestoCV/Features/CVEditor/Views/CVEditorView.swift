import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: CVEditorViewModel
    @State private var showingExportSheet = false
    @State private var deletionAnchor = RowDeletionAnchor()
    @StateObject private var keyboard = KeyboardVisibility()

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    init(viewModel: @autoclosure @escaping () -> CVEditorViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "cv.loading",
            onRetry: viewModel.loadCV
        ) { _ in
            editorView
        }
        .navigationTitle(viewModel.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        // Back and the edge swipe would leave without the discard confirmation that Cancel asks for
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Leading: Cancel button with confirmation if unsaved changes
            ToolbarItem(placement: .navigationBarLeading) {
                Button("common.cancel".localized, action: handleCancelTap)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            // Trailing: Save button with smart state and visual indicator
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    UnsavedChangesIndicator.warning(isVisible: viewModel.hasUnsavedChanges)
                    Button("common.save".localized, action: handleSaveTap)
                    .disabled(!viewModel.isSaveButtonEnabled)
                    .foregroundColor(viewModel.saveButtonColor)
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            // Load CV data when the view appears
            await viewModel.loadCV()
        }
        .alert("common.error".localized, isPresented: .constant(viewModel.isShowingError)) {
            Button("common.ok".localized, action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("dialog.discard_changes.title".localized, isPresented: $viewModel.showingCancelConfirmation) {
            Button("common.discard".localized, role: .destructive, action: handleDiscardChanges)
            Button("editor.keep_editing".localized, role: .cancel) { }
        } message: {
            Text("dialog.discard_changes.message".asLoclizedKey)
        }
        .alert("editor.save_success".localized, isPresented: $viewModel.showingSaveConfirmation) {
            Button("editor.continue_editing".localized, action: viewModel.dismissSaveConfirmation)
            Button("common.done".localized, action: handleSaveConfirmationDone)
        } message: {
            Text("dialog.save_success.message".asLoclizedKey)
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
            CVExportSheetView(cv: viewModel.cv)
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        VStack(spacing: 0) {
            TabView {
                PersonalInfoSection(cv: $viewModel.cv, documentLanguage: $viewModel.documentLanguageSelection)
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.basics".localized, systemImage: "person.circle")
                    }

                ExperienceSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.experience".localized, systemImage: "briefcase")
                    }

                DetailsSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.details".localized, systemImage: "list.bullet.circle")
                    }
            }
            .background(DesignTokens.Colors.background)
            .readableContentWidth()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("editor.title".localized)
            .accessibilityHint("accessibility.editor_hint".localized)

            // The tab bar and the export button give the space back to the form while someone types
            if !keyboard.isVisible {
                Divider()

                PrimaryButton.large(
                    title: String(localized: "export.button.title"),
                    icon: "square.and.arrow.up",
                    isDisabled: !viewModel.hasMeaningfulContent
                ) {
                    showingExportSheet = true
                }
                // The button keeps a readable size at the largest text sizes instead of taking a fifth of the screen
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: DesignTokens.Layout.readableContentWidth)
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(DesignTokens.Colors.background)
            }
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
        leaveEditorUnlessEditsWouldBeLost()
    }

    /// For new CVs, always go to root (CV List), not just back one level
    private func leaveEditorUnlessEditsWouldBeLost() {
        if viewModel.requestLeaving() {
            router.navigateToRoot()
        }
    }
    
    private func handleSaveTap() {
        Task {
            await viewModel.handleSaveButtonTap()
        }
    }
    
    private func handleDiscardChanges() {
        viewModel.confirmCancel()
        router.navigateToRoot()
    }
    
    private func handleSaveConfirmationDone() {
        leaveEditorUnlessEditsWouldBeLost()
    }
}

// MARK: - Previews

struct CVEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVEditorView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> CVEditorViewModel {
        let container = DependencyContainer()
        do {
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return CVEditorViewModel(
                cvId: nil,
                cvManagementUseCase: cvManagementUseCase
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}
