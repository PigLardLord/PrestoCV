import SwiftUI
import PrestoCVCore

struct EditableContent<Item, RowContent: View>: View {
    @Binding var items: [Item]
    let icon: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let rowContent: (Binding<Item>) -> RowContent
    let deleteLabel: (Item) -> String
    let onRemove: (Int) -> Void
    
    var body: some View {
        if items.isEmpty {
            CVEmptyStateView(
                icon: icon,
                title: emptyStateTitle,
                subtitle: emptyStateSubtitle
            )
        } else {
            EditableItemsList(
                items: $items,
                rowContent: rowContent,
                deleteLabel: deleteLabel,
                onRemove: onRemove
            )
        }
    }
}