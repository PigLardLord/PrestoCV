import PrestoCVPresentation
import SwiftUI

/// The frame of the app: the list of CVs in the sidebar and the open CV in the detail. On a compact screen it shows one
/// column at a time, the list first. The model decides which CV is open and which column shows; this view binds to it.
struct ShellView: View {
    let shell: ShellNavigationModel
    let list: CVListViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        if let row = shell.selectedRow(in: list.rows) {
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
