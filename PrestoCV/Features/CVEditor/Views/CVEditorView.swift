import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: CVEditorViewModel
    private let makeExportSheet: @MainActor (CVEditorViewModel) -> CVExportSheetViewModel
    @State private var showingExportSheet = false
    @State private var deletionAnchor = RowDeletionAnchor()
    @StateObject private var keyboard = KeyboardVisibility()
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
            
            if chrome.exportsFromNavigationBar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BarButton(
                        title: "export.button.title".localized, systemImage: "square.and.arrow.up",
                        screenTextSize: dynamicTypeSize
                    ) {
                        showingExportSheet = true
                    }
                    .disabled(!viewModel.hasMeaningfulContent)
                }
            }

            // Trailing: Save button with smart state and visual indicator
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    UnsavedChangesIndicator.warning(isVisible: viewModel.hasUnsavedChanges)
                    BarButton(
                        title: "common.save".localized, systemImage: "checkmark", screenTextSize: dynamicTypeSize,
                        action: handleSaveTap
                    )
                    .disabled(!viewModel.isSaveButtonEnabled)
                    .foregroundColor(viewModel.saveButtonColor)
                    .fontWeight(.semibold)
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
            // On its way to the background the app can be ended by iOS at any moment: what is not saved is kept now
            if phase != .active {
                Task { await viewModel.keepUnsavedEdits() }
            }
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
                    emailStatus: viewModel.emailStatus,
                    phoneStatus: viewModel.phoneStatus,
                    portfolioStatus: viewModel.portfolioStatus
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

            // The tab bar and the export button give the space back to the form while someone types
            if !keyboard.isVisible && !chrome.exportsFromNavigationBar {
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

struct CVEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVEditorView(viewModel: createMockViewModel()) { editor in
                CVExportSheetViewModel(
                    cv: editor.cv,
                    exportService: CVExportService(),
                    preferencesStore: FileExportPreferencesStore(),
                    documentLanguageSink: { editor.documentLanguageSelection = $0 }
                )
            }
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
