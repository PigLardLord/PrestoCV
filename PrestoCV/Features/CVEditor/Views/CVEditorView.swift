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
    /// The editor's height, and the height of the notice above the form with all its lines: where the form is short of room,
    /// `EditorChrome` gives the notice part of the editor, and the notice scrolls beyond it.
    @State private var editorHeight: CGFloat = 0
    @State private var noticeFullHeight: CGFloat = 0

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
        .navigationSubtitle(viewModel.subtitle)
        // Back is the editor's own, so that it stores what the form shows before it leaves, and stays, with the failure,
        // when that cannot be done: the system's Back would leave first, and the edits would go with the editor
        .navigationBarBackButtonHidden(true)
        // The swipe that goes back goes through the same Back when the form holds edits the store does not
        .guardsBackSwipe(
            canLeaveAtOnce: { viewModel.storeHoldsWhatTheFormShows },
            leave: { Task { await router.leaveEditor(viewModel) } }
        )
        .toolbar {
            // Leading: Back. Trailing: export, in every layout, as its symbol, which leaves the title its room in every
            // language
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task { await router.leaveEditor(viewModel) }
                } label: {
                    Label("common.back".localized, systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("BackButton")
                .accessibilityShowsLargeContentViewer {
                    Label("common.back".localized, systemImage: "chevron.backward")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
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
        // However the editor is left, what it still shows is stored at once, and the list waits for that
        .onDisappear {
            router.editorDisappeared(viewModel)
        }
        // VoiceOver hears that a change could not be saved, each time, and that it is saved once a write succeeds again
        .onChange(of: viewModel.saveAnnouncement) { _, announcement in
            if let announcement {
                AccessibilityNotification.Announcement(announcement.text).post()
            }
        }
        .environment(\.rowDeletionAnchor, deletionAnchor)
        .anchoredConfirmationDialog(
            // The question names the kind of row, and the editor keeps it while the dialog closes
            viewModel.deletionTitle,
            isPresented: isShowingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: viewModel.pendingDeletion,
            anchoredTo: deletionAnchor.rect,
            // The row has slid sideways under the swipe: the dialog points at the row, not at its button
            spanningWidth: true
        ) { deletion in
            Button("common.delete".localized, role: .destructive) {
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    viewModel.confirmDeletion(deletion)
                }
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: { deletion in
            Text(deletion.message)
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
                .accessibilityIdentifier("editor.save_failed")
            }

            if let notice = viewModel.notice {
                noticeBanner(notice)
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
                    .bringsNewRowsIntoView()
                    .keyboardDoneButton()
                    .keepsClearOfTheKeyboardDoneButton()
                    .hidesTabBar(while: keyboard.isVisible)
                    .tabItem {
                        Label("section.experience".localized, systemImage: "briefcase")
                    }

                DetailsSection(viewModel: viewModel)
                    .bringsNewRowsIntoView()
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
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { editorHeight = $0 }
    }

    /// The notice above the form: all its lines, or, where the form is short of room, the height `EditorChrome` gives it, which
    /// it scrolls in.
    @ViewBuilder
    private func noticeBanner(_ notice: EditorNotice) -> some View {
        if let height = chrome.noticeHeight(fullHeight: noticeFullHeight, editorHeight: editorHeight) {
            ScrollView {
                EditorNoticeBanner(notice: notice, onDismiss: noticeDismissal)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { noticeFullHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: height)
        } else {
            EditorNoticeBanner(notice: notice, onDismiss: noticeDismissal)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { noticeFullHeight = $0 }
        }
    }

    /// What dismissing the notice does, when the notice offers it.
    private var noticeDismissal: (() -> Void)? {
        guard viewModel.noticeIsDismissible else { return nil }
        return { Task { await viewModel.dismissNotice() } }
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
                PreviewDependencies.exportSheet(
                    for: editor.cv,
                    sink: { editor.documentLanguageSelection = $0 },
                    lookSink: { editor.chooseLook($0) }
                )
            }
        }
        .environmentObject(AppRouter())
    }
}
#endif
