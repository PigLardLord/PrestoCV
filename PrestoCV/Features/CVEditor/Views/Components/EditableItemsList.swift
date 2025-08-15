import SwiftUI
import PrestoCVCore

struct EditableItemsList<Item: Identifiable, RowContent: View>: View {
    @Binding var items: [Item]
    let verticalPadding: CGFloat
    let rowContent: (Binding<Item>, @escaping () -> Void) -> RowContent
    let onRemove: (Int) -> Void
    
    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            rowContent(
                $items[index],
                { animatedRemove(at: index) }
            )
            .padding(.vertical, verticalPadding)
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

struct EditableStringsList<RowContent: View>: View {
    @Binding var items: [String]
    let rowContent: (Binding<String>, @escaping () -> Void) -> RowContent
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