import PrestoCVPresentation
import SwiftUI

/// The frame of the app: the list of CVs in the sidebar and the open CV in the detail. On a compact screen it shows one
/// column at a time, the list first. The model decides which CV is open and which column shows; this view binds to it.
struct ShellView: View {
    let shell: ShellNavigationModel
    let list: CVListViewModel

    var body: some View {
        NavigationSplitView(preferredCompactColumn: column) {
            SidebarView(list: list, selection: selection)
        } detail: {
            detail
        }
        .task { await list.load() }
        .onChange(of: list.rows) { _, rows in shell.reconcile(with: rows) }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detail: some View {
        if let reference = shell.selection, let row = list.rows.first(where: { $0.reference == reference }) {
            OpenedCVPlaceholderView(label: row.label)
        } else {
            DetailPlaceholderView()
        }
    }

    /// The system selects a row, and clears the selection when the person goes back.
    private var selection: Binding<CVReference?> {
        Binding(
            get: { shell.selection },
            set: { reference in
                if let reference { shell.select(reference) } else { shell.deselect() }
            }
        )
    }

    /// Going back to the list on a compact screen closes the open CV.
    private var column: Binding<NavigationSplitViewColumn> {
        Binding(
            get: { shell.preferredColumn == .detail ? .detail : .sidebar },
            set: { column in
                if column == .sidebar { shell.deselect() }
            }
        )
    }
}
