import SwiftUI
import PrestoCVCore

struct CVEditableSection<Item, RowContent: View>: View {
    let title: String
    let icon: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let addButtonTitle: String
    
    @Binding var items: [Item]
    let rowContent: (Binding<Item>) -> RowContent
    let deleteLabel: (Item) -> String
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    @State private var newRowFocus = NewRowFocus()
    
    init(
        title: String,
        icon: String,
        emptyStateTitle: String,
        emptyStateSubtitle: String,
        addButtonTitle: String,
        items: Binding<[Item]>,
        @ViewBuilder rowContent: @escaping (Binding<Item>) -> RowContent,
        deleteLabel: @escaping (Item) -> String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void
    ) {
        self.title = title
        self.icon = icon
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateSubtitle = emptyStateSubtitle
        self.addButtonTitle = addButtonTitle
        self._items = items
        self.rowContent = rowContent
        self.deleteLabel = deleteLabel
        self.onAdd = onAdd
        self.onRemove = onRemove
    }
    
    var body: some View {
        Section {
            EditableContent(
                items: $items,
                icon: icon,
                emptyStateTitle: emptyStateTitle,
                emptyStateSubtitle: emptyStateSubtitle,
                rowContent: rowContent,
                deleteLabel: deleteLabel,
                onRemove: onRemove
            )
            .environment(\.newRowFocus, newRowFocus)
            
            AddButton(
                title: addButtonTitle,
                icon: "plus.circle.fill",
                action: animatedAdd
            )
        } header: {
            SectionHeader(title: title)
        }
    }
    
    /// Adds a row, whose first field then takes the keyboard focus.
    private func animatedAdd() {
        newRowFocus.request(row: items.count)
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            onAdd()
        }
    }
}