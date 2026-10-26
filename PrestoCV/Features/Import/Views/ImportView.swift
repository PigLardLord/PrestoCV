import SwiftUI
import UniformTypeIdentifiers

/// The screen that brings in a CV the person already has: a text pasted from a chat assistant, Word, an e-mail or
/// LinkedIn, or a PDF from Files. The CV it reads opens in the editor, which stores it as it is, with what to check.
struct ImportView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: ImportViewModel
    @State private var showingFileImporter = false
    @FocusState private var isTextFocused: Bool

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    init(viewModel: @autoclosure @escaping () -> ImportViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                header
                textSection
                PrimaryButton(title: "import.text.button".localized, icon: "text.badge.checkmark", isDisabled: !viewModel.canImportText) {
                    isTextFocused = false
                    viewModel.importText()
                }
                .accessibilityIdentifier("import.text.button")
                pdfSection
                Label("import.privacy_note".localized, systemImage: "lock.shield")
                    .typography(.caption1)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .readableContentWidth()
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .screenTitle("import.screen_title".localized, large: true)
        .overlay {
            if viewModel.isImporting {
                LoadingView(message: "import.reading".asLoclizedKey)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignTokens.Colors.background)
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importFile(at: url)
            }
        }
        .alert(
            "import.error.title".localized,
            isPresented: Binding(get: { viewModel.failure != nil }, set: { if !$0 { viewModel.clearFailure() } })
        ) {
            Button("common.ok".localized, action: viewModel.clearFailure)
        } message: {
            Text(viewModel.failure?.messageKey.localized ?? "")
        }
        // A PDF opened in the app from the share sheet or Files: the view model's task reads it, so clearing the
        // pending file, which ends this task, does not stop the reading
        .task(id: router.pendingImportFile) {
            if let file = router.takePendingImportFile() {
                viewModel.importFile(at: file)
            }
        }
        .onDisappear(perform: viewModel.cancelImport)
        .onChange(of: viewModel.imported) { _, draft in
            if let draft {
                viewModel.draftOpened()
                router.navigateToEditorWithImport(draft)
            }
        }
    }

    // MARK: - Pasting

    /// Hands what was pasted to the view model: the bytes of a PDF, or the text.
    private func paste(_ providers: [NSItemProvider]) {
        if let pdf = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }) {
            pdf.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
                guard let data else { return }
                Task { @MainActor in viewModel.importPDF(data) }
            }
            return
        }
        for provider in providers where provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                guard let string else { return }
                Task { @MainActor in viewModel.paste([string]) }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "doc.on.clipboard")
                    .font(DesignTokens.IconSize.large.font)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .accessibilityHidden(true)
                Text("import.header_title".localized)
                    .typography(.title2)
                    .foregroundColor(DesignTokens.Colors.primary)
            }
            Text("import.header_subtitle".localized)
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("import.text.title".localized)
                    .typography(.headline)
                    .foregroundColor(DesignTokens.Colors.primary)
                Spacer()
                // The system's paste button reads the clipboard without asking the person for permission: a text, or a
                // PDF copied in Files
                PasteButton(supportedContentTypes: [.pdf, .plainText]) { providers in
                    paste(providers)
                }
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("import.paste")
            }
            // A text editor has no label of its own: VoiceOver names it by the title above it. The box keeps its height
            // and a long CV scrolls inside it: a box that grew with the text took the import far below it, and a swipe
            // on the text moved the text, not the screen
            TextEditor(text: $viewModel.text)
                .accessibilityLabel("import.text.title".localized)
                .accessibilityIdentifier("import.text")
                .frame(height: 220)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .focused($isTextFocused)
                .overlay(alignment: .topLeading) {
                    if viewModel.text.isEmpty {
                        Text("import.text.placeholder".localized)
                            .typography(.body)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .padding(DesignTokens.Spacing.md)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(isTextFocused ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                )
        }
    }

    private var pdfSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("import.pdf.title".localized)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)
            Text("import.pdf.description".localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
            SecondaryButton(title: "import.pdf.button".localized, icon: "doc.richtext") {
                isTextFocused = false
                showingFileImporter = true
            }
            .accessibilityIdentifier("import.pdf.button")
        }
    }
}
