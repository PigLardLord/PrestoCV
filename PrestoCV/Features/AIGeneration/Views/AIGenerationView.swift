import SwiftUI
import PrestoCVCore

struct AIGenerationView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: AIGenerationViewModel
    @FocusState private var isTextEditorFocused: Bool

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    init(viewModel: @autoclosure @escaping () -> AIGenerationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                headerSection

                promptInputSection

                exampleSection

                generateButton
            }
            .padding(DesignTokens.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .screenTitle("navigation.ai_generation".localized, large: true)
        .overlay {
            if viewModel.isGenerating {
                GeneratingOverlay(isWaitingForLanguageData: viewModel.isWaitingForLanguageData, onCancel: viewModel.cancel)
            }
        }
        .alert("common.error".localized, isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("common.ok".localized) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.draft) { _, draft in
            if let draft {
                router.navigateToEditorWithAIDraft(draft)
            }
        }
        .onChange(of: viewModel.imported) { _, imported in
            if let imported {
                router.navigateToEditorWithImportedDescription(imported)
            }
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(DesignTokens.IconSize.large.font)
                    .foregroundColor(DesignTokens.Colors.accent)

                Text("ai.generation.header_title".localized)
                    .typography(.title2)
                    .foregroundColor(DesignTokens.Colors.primary)
            }

            Text("ai.generation.header_subtitle".localized)
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("ai.generation.prompt_section_title".localized)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)

            // A text editor has no label of its own: VoiceOver names it by the title above it
            TextEditor(text: $viewModel.prompt)
                .accessibilityLabel("ai.generation.prompt_section_title".localized)
                .frame(minHeight: 200)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .focused($isTextEditorFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(isTextEditorFocused ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                )

            HStack(alignment: .top) {
                Text("ai.generation.prompt_instructions".localized)
                    .typography(.caption1)
                    .foregroundColor(DesignTokens.Colors.secondary)

                Spacer()

                Text("ai.generation.character_count".localizedWithArgs(viewModel.characterCount, viewModel.characterLimit))
                    .typography(.caption1)
                    .foregroundColor(viewModel.isOverCharacterLimit ? DesignTokens.Colors.error : DesignTokens.Colors.secondary)
            }
        }
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("ai.generation.example_section_title".localized)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)

            CardView(padding: DesignTokens.Spacing.sm) {
                Text("ai.generation.example_text".localized)
                    .typography(.caption1)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
        }
    }

    private var generateButton: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: {
                isTextEditorFocused = false
                viewModel.startGenerating()
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("ai.generation.button_title".localized)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !viewModel.canGenerate))
            .disabled(!viewModel.canGenerate)

            Label("ai.generation.privacy_note".localized, systemImage: "lock.shield")
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }
}

// MARK: - Generating Overlay

/// Covers the screen while the model works, or while the system gets the language data it needs, and lets the person stop it.
private struct GeneratingOverlay: View {
    /// The screen waits for the language data and not for the model, which the screen says apart from the model's minute.
    let isWaitingForLanguageData: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // The label is what VoiceOver reads: while the app waits for the data it says so, instead of only "Processing..."
            LoadingView(message: message, voiceOverLabel: isWaitingForLanguageData ? message : "common.processing".asLoclizedKey)

            // The model's minute does not hold while the app waits for the data: the system sets that pace, so there is no time here
            if !isWaitingForLanguageData {
                Text("ai.generation.time_note".localized)
                    .typography(.caption1)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }

            SecondaryButton(title: "common.cancel".localized, action: onCancel)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.background)
    }

    private var message: LocalizedStringKey {
        isWaitingForLanguageData ? "ai.generation.language_data_message".asLoclizedKey : "ai.generation.loading_message".asLoclizedKey
    }
}
