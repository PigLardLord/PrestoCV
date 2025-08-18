import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "cv.loading",
            onRetry: viewModel.loadCV
        ) { _ in
            editorView
        }
        .navigationTitle(viewModel.cv.name.isEmpty ? String(localized: "editor.new_cv") : viewModel.cv.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading: Cancel button with confirmation if unsaved changes
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "common.cancel"), action: handleCancelTap)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            // Trailing: Save button with smart state and visual indicator
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    UnsavedChangesIndicator.warning(isVisible: viewModel.hasUnsavedChanges)
                    Button(String(localized: "common.save"), action: handleSaveTap)
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
        .alert(String(localized: "common.error"), isPresented: .constant(viewModel.isShowingError)) {
            Button(String(localized: "common.ok"), action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert(String(localized: "dialog.discard_changes.title"), isPresented: $viewModel.showingCancelConfirmation) {
            Button(String(localized: "common.discard"), role: .destructive, action: handleDiscardChanges)
            Button(String(localized: "editor.keep_editing"), role: .cancel) { }
        } message: {
            Text(String(localized: "dialog.discard_changes.message"))
        }
        .alert(String(localized: "editor.save_success"), isPresented: $viewModel.showingSaveConfirmation) {
            Button(String(localized: "editor.continue_editing"), action: viewModel.dismissSaveConfirmation)
            Button(String(localized: "common.done"), action: handleSaveConfirmationDone)
        } message: {
            Text(String(localized: "dialog.save_success.message"))
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        TabView {
            // MARK: - Basics Tab
            PersonalInfoSection(cv: $viewModel.cv)
                .tabItem {
                    Label(String(localized: "section.basics"), systemImage: "person.circle")
                }
            
            // MARK: - Experience Tab
            ExperienceSection(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "section.experience"), systemImage: "briefcase")
                }
            
            // MARK: - Details Tab
            DetailsSection(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "section.details"), systemImage: "list.bullet.circle")
                }
        }
        .background(DesignTokens.Colors.background)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "editor.title"))
        .accessibilityHint(String(localized: "accessibility.editor_hint"))
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
        router.navigateBack()
    }
    
    private func handleSaveConfirmationDone() {
        viewModel.finishEditingAndNavigateBack()
        router.navigateBack()
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
