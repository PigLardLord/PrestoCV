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
        .navigationTitle("AI CV Generation")
        .navigationBarTitleDisplayMode(.large)
        .overlay(
            viewModel.isGenerating ? LoadingView.fullscreen(message: "Generating your CV with AI...".asLoclizedKey) : nil
        )
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
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

                Text("AI-Powered CV Generation")
                    .typography(.title2)
                    .foregroundColor(DesignTokens.Colors.primary)
            }

            Text("Describe your professional background in detail, and AI will create a production-quality CV for you.")
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Your Professional Background")
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

            Text("Include: name, email, experience, education, skills, achievements, languages, etc.")
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Example")
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
                Text("Generate CV with AI")
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.accent)
            .foregroundColor(.white)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        .opacity(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
    }
}
