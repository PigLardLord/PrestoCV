import SwiftUI

/// The diagnostics screen of a TestFlight or Debug build (ADR 0032): the runs of the AI draft and of the import the trace
/// stored on this device, the summary of the chosen one, and a share button that hands its files to the share sheet.
struct DiagnosticsView: View {
    @ObservedObject var viewModel: DiagnosticsViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("diagnostics.notice".localized)
                        .typography(.footnote)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }

                if viewModel.rows.isEmpty {
                    Section {
                        Text("diagnostics.empty".localized)
                            .typography(.body)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .accessibilityIdentifier("diagnostics.empty")
                    }
                } else {
                    Section {
                        ForEach(viewModel.rows) { row in
                            runButton(row)
                        }
                    }

                    Section {
                        Text(viewModel.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("diagnostics.summary")
                    }
                }
            }
            .screenTitle("diagnostics.title".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BarButton(title: "common.done".localized, systemImage: "checkmark", screenTextSize: dynamicTypeSize) {
                        dismiss()
                    }
                }
                if !viewModel.shareFiles.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(items: viewModel.shareFiles) {
                            Label("diagnostics.share".localized, systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("diagnostics.share")
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private func runButton(_ row: DiagnosticsViewModel.Row) -> some View {
        Button {
            Task { await viewModel.select(row.id) }
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(row.title)
                    .typography(.headline)
                    .foregroundColor(DesignTokens.Colors.primary)
                Text("\(row.time) · \(row.outcome)")
                    .typography(.footnote)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.id == viewModel.selection ? .isSelected : [])
        .accessibilityIdentifier("diagnostics.run")
    }
}
