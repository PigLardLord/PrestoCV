import SwiftUI
import PrestoCVCore

/// The sheet of example CVs the first run and the "New CV" screen offer. Picking one hands it to `onSelect`.
struct ExampleSelectionView: View {
    let samples: [CVModel]
    let onSelect: (CVModel) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
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
            .screenTitle("onboarding.start_from_example".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BarButton(title: "common.cancel".localized, systemImage: "xmark", screenTextSize: dynamicTypeSize) {
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

// MARK: - Presenting

extension View {
    /// Presents the example CVs of `viewModel` while `isPresented` is true, and hands the draft of the one the person
    /// picks to `open` once the sheet is gone, because a screen pushed while a sheet is leaving is lost.
    func exampleSelection(
        isPresented: Binding<Bool>,
        from viewModel: NewCVChoicesViewModel,
        open: @escaping (CVModel) -> Void
    ) -> some View {
        modifier(ExampleSelectionSheet(isPresented: isPresented, viewModel: viewModel, open: open))
    }
}

private struct ExampleSelectionSheet: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: NewCVChoicesViewModel
    let open: (CVModel) -> Void
    /// The draft of the example the person picked, until the sheet is gone.
    @State private var pendingDraft: CVModel?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: openPendingDraft) {
                ExampleSelectionView(samples: viewModel.samples) { sample in
                    pendingDraft = viewModel.makeDraft(from: sample)
                    isPresented = false
                }
            }
    }

    private func openPendingDraft() {
        guard let draft = pendingDraft else { return }
        pendingDraft = nil
        open(draft)
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
