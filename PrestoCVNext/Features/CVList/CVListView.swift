import PrestoCVPresentation
import SwiftUI

/// The list column: the CVs of the store in the view model's order, under the notices of the list. While the first read
/// runs it waits; a store with no CV shows the ways to start. It reads the store when it appears, each time the app comes
/// back to the front and on a pull; the view model reads it again after its own changes. A change of a row that did not
/// work is said in a notice of its own that names the row and stays until the person hides it. An editor the person left
/// whose text is not stored has a notice under its CV's row, or above the rows when the list does not have that CV
/// (#402, decisions 16 and 17). Old CVs of the released app that the import did not bring in are said in a notice above
/// the others, which stays until the person hides it for this launch (#406).
struct CVListView: View {
    let list: CVListViewModel
    let report: LegacyImportReportViewModel
    let firstRun: FirstRunViewModel
    let selection: Binding<CVReference?>
    /// Opens the way to start the person chose in the empty list.
    let choose: (StartChoice) -> Void
    /// The notices of the editors the shell kept, where the list shows them
    let kept: KeptNotices
    /// Writes a kept editor's text again, by its number.
    let retryKept: (Int) -> Void
    /// Opens a kept editor, by its number.
    let openKept: (Int) -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .navigationTitle(Text("shell.sidebar.title"))
            // When the list appears and each time the app comes back: the time since each save moves on
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                list.refreshNow()
                await list.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch list.content {
        case .loading:
            LoadingView("shell.sidebar.loading")
                .accessibilityIdentifier("shell.sidebar.loading")
        case .empty:
            empty
        case .rows:
            rows
        }
    }

    private var rows: some View {
        List(selection: selection) {
            notices
            keptAbove
            ForEach(list.rows) { row in
                CVRowView(list: list, row: row, incomplete: report.isIncomplete(row.reference))
                    .tag(row.reference)
                if let notice = kept.under[row.reference] {
                    keptNotice(notice)
                }
            }
        }
        .refreshable { await list.load() }
        .accessibilityIdentifier("shell.sidebar.list")
    }

    /// A store that was used and holds no CV: a short line and the ways to start, not the welcome of a first run.
    private var empty: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                notices
                keptAbove
                ScreenTitle("shell.empty.title")
                WholeWordsText("shell.empty.message")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                StartChoicesView(firstRun: firstRun, choose: choose)
            }
            .padding(Spacing.large)
            .readableWidth()
        }
        .refreshable { await list.load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell.sidebar.empty")
    }

    // MARK: Notices

    @ViewBuilder
    private var notices: some View {
        legacyNotice
        ForEach(list.notices, id: \.self) { notice in
            switch notice {
            case .stale:
                InlineNotice(actionTitle: "list.retry", action: reload) { WholeWordsText("list.stale") }
            case .failed:
                InlineNotice(actionTitle: "list.retry", action: reload) { WholeWordsText("list.failed") }
            case .unreadable(let unreadable):
                InlineNotice(actionTitle: "list.hide", action: { list.dismissNotice() }) { unreadableMessage(unreadable) }
                    .accessibilityIdentifier("list.notice")
            case .rowFailure(let failure):
                InlineNotice(
                    actionTitle: "list.hide",
                    actionIdentifier: "list.rowFailure.hide",
                    actionLabel: "list.rowFailure.hide \(failure.label)",
                    action: { list.dismissRowFailure(failure) }
                ) { rowFailureMessage(failure) }
                    .accessibilityIdentifier("list.rowFailure")
            }
        }
    }

    /// The old CVs not imported, or an import that did not run: never an empty list as if the CVs were gone.
    @ViewBuilder
    private var legacyNotice: some View {
        if let notice = report.notice {
            InlineNotice(
                actionTitle: "list.hide", actionIdentifier: "legacyImport.notice.hide", action: { report.hideNotice() }
            ) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    switch notice {
                    case .notImported: LegacyNotImportedLines(report: report)
                    case .didNotRun: WholeWordsText("legacyImport.failed.unknown").font(.headline)
                    }
                    kindLine("legacyImport.notice")
                }
            }
            .accessibilityIdentifier("legacyImport.notice")
        }
    }

    private var keptAbove: some View {
        ForEach(kept.above) { notice in
            keptNotice(notice)
        }
    }

    private func keptNotice(_ notice: KeptNotice) -> some View {
        KeptNoticeView(notice: notice, retry: retryKept, open: openKept)
    }

    /// The name of the CV as the person wrote it, then what did not work.
    private func rowFailureMessage(_ failure: RowFailure) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(verbatim: failure.label)
                .font(.headline)
            switch failure.status {
            case .conflict: WholeWordsText("list.status.conflict")
            case .gone: WholeWordsText("list.status.gone")
            case .tooLarge: WholeWordsText("list.status.tooLarge")
            case .failed: WholeWordsText("list.status.failed")
            }
        }
    }

    /// How many CVs could not be opened and a line for each kind of file; never where the files are.
    private func unreadableMessage(_ notice: StoreNotice) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            WholeWordsText("list.notice \(notice.count)")
                .font(.headline)
                .accessibilityIdentifier("list.notice.count")
            ForEach(notice.distinctKinds, id: \.self) { kind in
                switch kind {
                case .corrupt: kindLine("list.notice.corrupt")
                case .upgradeRequired: kindLine("list.notice.upgradeRequired")
                case .unreadable: kindLine("list.notice.unreadable")
                case .tooLarge: kindLine("list.notice.tooLarge")
                case .quarantineFailed: kindLine("list.notice.quarantineFailed")
                }
            }
        }
    }

    private func kindLine(_ key: LocalizedStringResource) -> some View {
        WholeWordsText(key)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func reload() {
        Task { await list.load() }
    }
}
