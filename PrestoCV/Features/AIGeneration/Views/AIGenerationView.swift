import SwiftUI
import PrestoCVCore

struct AIGenerationView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: AIGenerationViewModel
    @FocusState private var isTextEditorFocused: Bool

    init(viewModel: AIGenerationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
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
        .screenTitle("navigation.ai_generation".localized, large: true)
        .overlay(
            viewModel.isGenerating ? LoadingView.fullscreen(message: "ai.generation.loading_message".asLoclizedKey) : nil
        )
        .alert("common.error".localized, isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("common.ok".localized) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.generatedCVId) { _, cvId in
            if let cvId = cvId {
                router.replace(with: .cvEditor(cvId: cvId))
            }
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

            TextEditor(text: $viewModel.prompt)
                .frame(minHeight: 200)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .focused($isTextEditorFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(isTextEditorFocused ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                )

            Text("ai.generation.prompt_instructions".localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("ai.generation.example_section_title".localized)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)

            CardView(padding: DesignTokens.Spacing.sm) {
                Text("""
                I'm John Doe, email john@example.com, phone +1 234 567 890, from San Francisco. I'm a senior software engineer with 8 years of experience at Tech Corp building scalable web applications. I have expertise in Python, JavaScript, React, and AWS. I graduated from MIT with a Computer Science degree in 2015. My native language is English and I'm fluent in Spanish.
                """)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
            }
        }
    }

    private var generateButton: some View {
        Button(action: {
            isTextEditorFocused = false
            Task {
                await viewModel.generateCV()
            }
        }) {
            HStack {
                Image(systemName: "sparkles")
                Text("ai.generation.button_title".localized)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
        }
        .buttonStyle(PrimaryButtonStyle(isDisabled: viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
    }
}
