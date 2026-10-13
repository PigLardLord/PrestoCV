import SwiftUI
import PrestoCVCore

/// The sheet of example CVs the first-run view offers. Picking one hands it to `onSelect`.
struct ExampleSelectionView: View {
    let samples: [CVModel]
    let onSelect: (CVModel) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(samples) { sample in
                        Button {
                            onSelect(sample)
                        } label: {
                            row(for: sample)
                        }
                    }
                } footer: {
                    Text("onboarding.examples.footer".localized)
                }
            }
            .navigationTitle("onboarding.start_from_example".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func row(for sample: CVModel) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(sample.personalInfo.title.isEmpty ? "cv.untitled".localized : sample.personalInfo.title)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text(sample.personalInfo.profile)
                .typography(.subheadline)
                .foregroundColor(DesignTokens.Colors.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ExampleSelectionView(
        samples: [
            CVModel(personalInfo: PersonalInfo(title: "Senior Software Engineer", profile: "Senior engineer with 8+ years of experience building scalable systems.")),
            CVModel(personalInfo: PersonalInfo(title: "Senior UX/UI Designer", profile: "Designer with 7+ years of experience crafting intuitive digital products."))
        ],
        onSelect: { _ in }
    )
}
#endif
