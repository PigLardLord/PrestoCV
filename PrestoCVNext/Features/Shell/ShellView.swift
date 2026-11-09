import PrestoCVPresentation
import SwiftUI

/// The frame of the app: the list of CVs in the first column and the open CV in the detail. On a compact screen it shows
/// one column at a time, the list first. A first run shows the welcome in its place until a draft is open. The models decide
/// what is open, which column shows and whether the welcome shows; this view binds to them.
struct ShellView: View {
    let shell: ShellNavigationModel
    let list: CVListViewModel
    let firstRun: FirstRunViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var addingCV = false
    /// The way to start chosen in the "+" sheet, opened when the sheet has closed.
    @State private var chosenInSheet: StartChoice?

    var body: some View {
        screen
            .task { await firstRun.load() }
    }

    @ViewBuilder
    private var screen: some View {
        switch shell.screen(for: firstRun.state) {
        case .loading:
            LoadingView("root.loading")
        case .welcome:
            FirstRunView(firstRun: firstRun, choose: start)
        case .split:
            split
        }
    }

    private var split: some View {
        NavigationSplitView(preferredCompactColumn: column) {
            CVListView(list: list, firstRun: firstRun, selection: selection, choose: start)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { addingCV = true } label: { Label("shell.add", systemImage: "plus") }
                            .accessibilityIdentifier("shell.add")
                    }
                }
        } detail: {
            detail
        }
        .onChange(of: list.rows) { _, rows in shell.reconcile(with: rows) }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $addingCV, onDismiss: startChosenInSheet) {
            NewCVSheet(firstRun: firstRun) { choice in
                chosenInSheet = choice
                addingCV = false
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch shell.detail {
        case .stored?:
            if let row = shell.selectedRow(in: list.rows) {
                OpenedCVPlaceholderView(title: Text(verbatim: row.label))
            } else {
                DetailPlaceholderView()
            }
        case .draft?, .blank?:
            OpenedCVPlaceholderView(title: Text("shell.draft.title"))
        case nil:
            DetailPlaceholderView()
        }
    }

    /// Opens the draft a way to start gives. The factory does not offer the import while the app has no import screen,
    /// so every choice gives a draft.
    private func start(_ choice: StartChoice) {
        if case .draft(let draft)? = firstRun.start(choice) {
            shell.open(.draft(draft))
        }
    }

    private func startChosenInSheet() {
        guard let chosenInSheet else { return }
        self.chosenInSheet = nil
        start(chosenInSheet)
    }

    /// The system selects a row, and clears the selection when the person goes back.
    private var selection: Binding<CVReference?> {
        Binding(
            get: { shell.selection },
            set: { reference in
                if let reference { shell.open(.stored(reference)) } else { shell.deselect() }
            }
        )
    }

    /// Going back to the list closes the open CV, when one column shows at a time (a compact width). The system also
    /// writes the sidebar while it changes between one column and two, which is not the person going back.
    private var column: Binding<NavigationSplitViewColumn> {
        Binding(
            get: { shell.preferredColumn == .detail ? .detail : .sidebar },
            set: { column in
                shell.columnChanged(to: column == .sidebar ? .sidebar : .detail, isCollapsed: horizontalSizeClass == .compact)
            }
        )
    }
}
