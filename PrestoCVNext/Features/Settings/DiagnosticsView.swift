import PrestoCVPresentation
import SwiftUI

/// The Diagnostics screen of a test build: what the app recorded of the AI drafts and the imports on this device, the
/// summary of the chosen run, and the files of that run to share. The notice about what the summary holds is always at the
/// top. It reads the runs when it opens and drops the copies it made to share when it closes.
struct DiagnosticsView: View {
    let diagnostics: DiagnosticsViewModel

    var body: some View {
        content
            .navigationTitle(Text("diagnostics.title"))
            .inlineNavigationTitle()
            .toolbar {
                if !diagnostics.shareFiles.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(items: diagnostics.shareFiles) {
                            Label("diagnostics.share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("diagnostics.share")
                    }
                }
            }
            .task { await diagnostics.load() }
            .onDisappear { Task { await diagnostics.finish() } }
    }

    @ViewBuilder
    private var content: some View {
        switch diagnostics.state {
        case .loading:
            LoadingView("diagnostics.loading")
        case .empty:
            Form {
                notice
                Section {
                    Text("diagnostics.empty")
                        .accessibilityIdentifier("diagnostics.empty")
                }
            }
            .formStyle(.grouped)
        case .listed:
            listed
        }
    }

    private var notice: some View {
        Section {
            InlineNotice(actions: []) {
                WholeWordsText("diagnostics.notice")
            }
        }
    }

    private var listed: some View {
        Form {
            notice
            Section {
                ForEach(diagnostics.rows) { row in
                    RunRow(row: row, isSelected: row.id == diagnostics.selection) {
                        Task { await diagnostics.select(row.id) }
                    }
                }
            }
            Section {
                Text(verbatim: diagnostics.summary)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("diagnostics.summary")
                if diagnostics.copiesFailed {
                    Text("diagnostics.share.failed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("diagnostics.share.failed")
                }
            } header: {
                Text("diagnostics.summary.title")
            }
        }
        .formStyle(.grouped)
        .announce(diagnostics.selection, words: { _ in "diagnostics.summary.announcement" })
    }
}

/// One run: what it was, then when it began and how it ended. The chosen run has a check mark and the selected trait.
private struct RunRow: View {
    let row: DiagnosticsRow
    let isSelected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: Spacing.small) {
                VStack(alignment: .leading) {
                    kind
                    HStack(spacing: Spacing.small) {
                        Text(row.started.formatted(date: .abbreviated, time: .shortened))
                        outcome
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: Spacing.small)
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: TapTarget.minimumHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("diagnostics.run")
    }

    private var kind: Text {
        switch row.kind {
        case .aiDraft: Text("diagnostics.run.draft")
        case .textImport: Text("diagnostics.run.import")
        }
    }

    private var outcome: Text {
        switch row.outcome {
        case .finished: Text("diagnostics.run.outcome.finished")
        case .failed: Text("diagnostics.run.outcome.failed")
        case .cancelled: Text("diagnostics.run.outcome.cancelled")
        case .unfinished: Text("diagnostics.run.outcome.unfinished")
        }
    }
}
