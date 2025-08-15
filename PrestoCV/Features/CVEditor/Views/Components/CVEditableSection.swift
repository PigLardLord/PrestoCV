import SwiftUI
import PrestoCVCore

struct CVEditableSection<Item, RowContent: View>: View where Item: Identifiable {
    let title: String
    let icon: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let addButtonTitle: String
    
    @Binding var items: [Item]
    let rowContent: (Binding<Item>, @escaping () -> Void) -> RowContent
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    let addVerticalPadding: Bool
    
    init(
        title: String,
        icon: String,
        emptyStateTitle: String,
        emptyStateSubtitle: String,
        addButtonTitle: String,
        items: Binding<[Item]>,
        addVerticalPadding: Bool = false,
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
        self.addVerticalPadding = addVerticalPadding
        self.rowContent = rowContent
        self.onAdd = onAdd
        self.onRemove = onRemove
    }
    
    var body: some View {
        Section {
            if items.isEmpty {
                CVEmptyStateView(
                    icon: icon,
                    title: emptyStateTitle,
                    subtitle: emptyStateSubtitle
                )
            } else {
                ForEach(items.indices, id: \.self) { index in
                    let content = rowContent(
                        Binding(
                            get: { items[index] },
                            set: { items[index] = $0 }
                        ),
                        { animatedRemove(at: index) }
                    )
                    
                    if addVerticalPadding {
                        content.padding(.vertical, DesignTokens.Spacing.xs)
                    } else {
                        content
                    }
                }
                .onDelete(perform: animatedDelete)
            }
            
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
    
    private func animatedRemove(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            onRemove(index)
        }
    }
    
    private func animatedDelete(at indices: IndexSet) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            items.remove(atOffsets: indices)
        }
    }
}