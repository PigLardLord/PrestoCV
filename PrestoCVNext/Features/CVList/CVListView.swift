import PrestoCVPresentation
import SwiftUI

/// The list column: the CVs of the store in the view model's order, under the notices of the list. While the first read
/// runs it waits; a store with no CV shows the ways to start. It reads the store when it appears, each time the app comes
/// back to the front and on a pull; the view model reads it again after its own changes. A change of a row that did not
/// work is said in an alert that names the row.
struct CVListView: View {
    let list: CVListViewModel
    let firstRun: FirstRunViewModel
    let selection: Binding<CVReference?>
    /// Opens the way to start the person chose in the empty list.
    let choose: (StartChoice) -> Void
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
            .alert(Text(verbatim: list.rowAlert?.label ?? ""), isPresented: showingRowAlert, presenting: list.rowAlert) { _ in
            } message: { alert in
                switch alert.status {
                case .conflict: Text("list.status.conflict")
                case .gone: Text("list.status.gone")
                case .tooLarge: Text("list.status.tooLarge")
                case .failed: Text("list.status.failed")
                }
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
            ForEach(list.rows) { row in
                CVRowView(list: list, row: row)
                    .tag(row.reference)
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

    private var notices: some View {
        ForEach(list.notices, id: \.self) { notice in
            switch notice {
            case .stale:
                InlineNotice(actionTitle: "list.retry", action: reload) { WholeWordsText("list.stale") }
            case .failed:
                InlineNotice(actionTitle: "list.retry", action: reload) { WholeWordsText("list.failed") }
            case .unreadable(let unreadable):
                InlineNotice(actionTitle: "list.hide", action: { list.dismissNotice() }) { unreadableMessage(unreadable) }
                    .accessibilityIdentifier("list.notice")
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

    /// The alert shows while the list has one given; it stays until the person closes it, which dismisses that failure, and
    /// then the next one shows.
    private var showingRowAlert: Binding<Bool> {
        Binding(
            get: { list.rowAlert != nil },
            set: { shown in
                if !shown { list.dismissRowAlert() }
            }
        )
    }
}
