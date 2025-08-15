import SwiftUI
import PrestoCVCore

/// Generic editable list that works with any item type
/// Uses index-based iteration, so items don't need to be Identifiable
struct EditableItemsList<Item, RowContent: View>: View {
    @Binding var items: [Item]
    let rowContent: (Binding<Item>, @escaping () -> Void) -> RowContent
    let onRemove: (Int) -> Void
    
    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            rowContent(
                $items[index],
                { animatedRemove(at: index) }
            )
        }
        .onDelete(perform: animatedDelete)
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