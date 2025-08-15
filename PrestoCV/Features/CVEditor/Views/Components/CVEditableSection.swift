import SwiftUI
import PrestoCVCore

struct CVEditableSection<Item, RowContent: View>: View {
    let title: String
    let icon: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let addButtonTitle: String
    
    @Binding var items: [Item]
    let rowContent: (Binding<Item>, @escaping () -> Void) -> RowContent
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    
    init(
        title: String,
        icon: String,
        emptyStateTitle: String,
        emptyStateSubtitle: String,
        addButtonTitle: String,
        items: Binding<[Item]>,
        @ViewBuilder rowContent: @escaping (Binding<Item>, @escaping () -> Void) -> RowContent,
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
                onRemove: onRemove
            )
            
            AddButton(
                title: addButtonTitle,
                icon: "plus.circle.fill",
                action: animatedAdd
            )
        } header: {
            SectionHeader(title: title)
        }
    }
    
    private func animatedAdd() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            onAdd()
        }
    }
}