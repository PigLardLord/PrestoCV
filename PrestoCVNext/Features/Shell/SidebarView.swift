import PrestoCVPresentation
import SwiftUI

/// The sidebar: the CVs of the list by their labels, or what stands in their place while the list loads or has none.
struct SidebarView: View {
    let list: CVListViewModel
    let selection: Binding<CVReference?>

    var body: some View {
        content
            .navigationTitle(Text("shell.sidebar.title"))
    }

    @ViewBuilder
    private var content: some View {
        if list.rows.isEmpty, list.status == .loaded {
            EmptyStateView(symbol: "doc.text", title: "shell.empty.title", message: "shell.empty.message")
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("shell.sidebar.empty")
        } else if list.rows.isEmpty, list.status == .loading {
            LoadingView("root.loading")
                .accessibilityIdentifier("shell.sidebar.loading")
        } else {
            List(selection: selection) {
                ForEach(list.rows) { row in
                    Text(verbatim: row.label)
                        .font(.body)
                        .frame(minHeight: TapTarget.minimumHeight, alignment: .leading)
                        .tag(row.reference)
                        .accessibilityIdentifier("shell.row")
                }
            }
            .accessibilityIdentifier("shell.sidebar.list")
        }
    }
}
