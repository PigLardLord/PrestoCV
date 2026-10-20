import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
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
        // The quiet proof that the editor saves by itself, and that the CV stays on the device
        .navigationSubtitle(viewModel.showsSavedOnDevice ? "editor.saved".localized : "")
        .toolbar {
            // Leading: the standard Back button. Trailing: export, in every layout, as its symbol, which leaves the
            // title its room in every language
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingExportSheet = true
                } label: {
                    Label("export.button.title".localized, systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.canExport)
            }
        }
        .task {
            // Load CV data when the view appears
            await viewModel.loadCV()
        }
        .onChange(of: scenePhase) { _, phase in
            Task { await viewModel.sceneDidChange(isActive: phase == .active) }
        }
        // Leaving the editor stores what it shows at once
        .onDisappear {
            Task { await viewModel.saveNow() }
        }
        .onChange(of: viewModel.showsSaveFailure) { _, failed in
            if failed {
                AccessibilityNotification.Announcement("editor.save_failed".localized).post()
            }
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
            if viewModel.showsSaveFailure {
                InlineNotice(message: "editor.save_failed".localized, actionTitle: "common.retry".localized) {
                    Task { await viewModel.retrySaving() }
                }
            }

            if let notice = viewModel.notice {
                EditorNoticeBanner(notice: notice)
            }

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
                    .keepsClearOfTheKeyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.basics".localized, systemImage: "person.circle")
                    }

                ExperienceSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .keepsClearOfTheKeyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.experience".localized, systemImage: "briefcase")
                    }

                DetailsSection(viewModel: viewModel)
                    .keyboardDoneButton()
                    .keepsClearOfTheKeyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
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
    }
}
#endif
