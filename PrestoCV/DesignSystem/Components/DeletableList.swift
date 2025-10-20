import SwiftUI

/// A reusable list component with optional delete functionality
/// - Note: If onDelete is nil, no default delete action will be provided.
///         Use custom swipeActions in rowContent for confirmation dialogs.
struct DeletableList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let onDelete: ((IndexSet) -> Void)?
    @ViewBuilder let rowContent: (Item) -> RowContent

    init(
        items: [Item],
        onDelete: ((IndexSet) -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.onDelete = onDelete
        self.rowContent = rowContent
    }

    var body: some View {
        List {
            ForEach(items) { item in
                rowContent(item)
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(InsetGroupedListStyle())
    }
}
