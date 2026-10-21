import SwiftUI
import PrestoCVCore

/// Generic editable list that works with any item type
/// Uses index-based iteration, so items don't need to be Identifiable
struct EditableItemsList<Item, RowContent: View>: View {
    @Binding var items: [Item]
    let rowContent: (Binding<Item>, @escaping () -> Void) -> RowContent
    let onRemove: (Int) -> Void
    @Environment(\.newRowFocus) private var newRowFocus
    
    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            // The list can ask for a row once more after its item is gone
            if items.indices.contains(index) {
                rowContent(
                    Binding(element: index, of: $items),
                    { animatedRemove(at: index) }
                )
                .environment(\.rowIndex, index)
                .id(newRowFocus?.identity(ofRow: index))
            }
        }
        .onDelete(perform: animatedDelete)
    }
    
    private func animatedRemove(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            onRemove(index)
        }
    }
    
    /// Swipe to delete asks to remove a row like the trash button does, so a row with content is confirmed first.
    private func animatedDelete(at indices: IndexSet) {
        guard let index = indices.first else { return }
        animatedRemove(at: index)
    }
}

extension Binding {
    /// A binding to one element of an array that stays valid when the element is removed: it keeps
    /// showing the value the element had and ignores writes. Reading the array by index would
    /// crash in a row that a list still draws while its element is leaving.
    ///
    /// `index` must be valid when the binding is made.
    init(element index: Int, of elements: Binding<[Value]>) {
        let valueOnceRemoved = elements.wrappedValue[index]
        self.init(
            get: {
                elements.wrappedValue.indices.contains(index) ? elements.wrappedValue[index] : valueOnceRemoved
            },
            set: { newValue in
                guard elements.wrappedValue.indices.contains(index) else { return }
                elements.wrappedValue[index] = newValue
            }
        )
    }
}
