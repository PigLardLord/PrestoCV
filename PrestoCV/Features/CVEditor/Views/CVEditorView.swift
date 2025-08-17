import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "Loading CV...",
            onRetry: viewModel.loadCV
        ) { _ in
            editorView
        }
        .navigationTitle(viewModel.cv.name.isEmpty ? String(localized: "New CV") : viewModel.cv.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading: Cancel button with confirmation if unsaved changes
            ToolbarItem(placement: .navigationBarLeading) {
                Button(String(localized: "Cancel"), action: handleCancelTap)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            // Trailing: Save button with smart state and visual indicator
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    UnsavedChangesIndicator.warning(isVisible: viewModel.hasUnsavedChanges)
                    Button(String(localized: "Save"), action: handleSaveTap)
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
        .alert(String(localized: "Error"), isPresented: .constant(viewModel.isShowingError)) {
            Button(String(localized: "OK"), action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert(String(localized: "Discard Changes?"), isPresented: $viewModel.showingCancelConfirmation) {
            Button(String(localized: "Discard"), role: .destructive, action: handleDiscardChanges)
            Button(String(localized: "Keep Editing"), role: .cancel) { }
        } message: {
            Text(String(localized: "You have unsaved changes that will be lost if you continue."))
        }
        .alert(String(localized: "CV Saved Successfully"), isPresented: $viewModel.showingSaveConfirmation) {
            Button(String(localized: "Continue Editing"), action: viewModel.dismissSaveConfirmation)
            Button(String(localized: "Done"), action: handleSaveConfirmationDone)
        } message: {
            Text(String(localized: "Your changes have been saved."))
        }
    }
    
    // MARK: - View Components
    
    private var editorView: some View {
        TabView {
            // MARK: - Basics Tab
            PersonalInfoSection(cv: $viewModel.cv)
                .tabItem {
                    Label(String(localized: "Basics"), systemImage: "person.circle")
                }
            
            // MARK: - Experience Tab
            ExperienceSection(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "Experience"), systemImage: "briefcase")
                }
            
            // MARK: - Details Tab
            DetailsSection(viewModel: viewModel)
                .tabItem {
                    Label(String(localized: "Details"), systemImage: "list.bullet.circle")
                }
        }
        .background(DesignTokens.Colors.background)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "CV Editor"))
        .accessibilityHint(String(localized: "Swipe between tabs to edit different sections of your CV"))
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
