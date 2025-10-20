import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject var viewModel: CVEditorViewModel
    @State private var showingExportSheet = false
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "cv.loading",
            onRetry: viewModel.loadCV
        ) { _ in
            editorView
        }
        .navigationTitle(viewModel.cv.name.isEmpty ? "editor.new_cv".localized : viewModel.cv.name)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingExportSheet) {
            CVExportSheetView(cv: viewModel.cv)
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        VStack(spacing: 0) {
            TabView {
                PersonalInfoSection(cv: $viewModel.cv)
                    .tabItem {
                        Label("section.basics".localized, systemImage: "person.circle")
                    }

                ExperienceSection(viewModel: viewModel)
                    .tabItem {
                        Label("section.experience".localized, systemImage: "briefcase")
                    }

                DetailsSection(viewModel: viewModel)
                    .tabItem {
                        Label("section.details".localized, systemImage: "list.bullet.circle")
                    }
            }
            .background(DesignTokens.Colors.background)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("editor.title".localized)
            .accessibilityHint("accessibility.editor_hint".localized)

            Divider()

            PrimaryButton.large(
                title: String(localized: "export.button.title"),
                icon: "square.and.arrow.up",
                isDisabled: !viewModel.hasMeaningfulContent
            ) {
                showingExportSheet = true
            }
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.background)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleCancelTap() {
        if viewModel.handleCancelButtonTap() {
            router.navigateBack()
        }
    }
    
    private func handleSaveTap() {
        Task {
            await viewModel.handleSaveButtonTap {
                router.navigateBack()
            }
        }
    }
    
    private func handleDiscardChanges() {
        viewModel.confirmCancel()
        router.navigateToRoot()
    }
    
    private func handleSaveConfirmationDone() {
        viewModel.finishEditingAndNavigateBack()
        router.navigateToRoot()
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
