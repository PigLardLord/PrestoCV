import SwiftUI
import PrestoCVCore

/// Generic editable list that works with any item type
/// Uses index-based iteration, so items don't need to be Identifiable
///
/// A row is deleted by one deliberate gesture: a swipe opens a button that names the row ("Delete Swift"), and
/// tapping it asks to remove the row. The rows hold no delete control of their own, so a tap beside a field never
/// reaches one.
struct EditableItemsList<Item, RowContent: View>: View {
    @Binding var items: [Item]
    let rowContent: (Binding<Item>) -> RowContent
    /// What the delete button of an item says to VoiceOver, so that it names the item it deletes.
    let deleteLabel: (Item) -> String
    let onRemove: (Int) -> Void
    @Environment(\.newRowFocus) private var newRowFocus
    @Environment(\.rowDeletionAnchor) private var deletionAnchor
    @State private var frames = ScreenFrames<Int>()
    
    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            // The list can ask for a row once more after its item is gone
            if items.indices.contains(index) {
                let item = items[index]
                rowContent(Binding(element: index, of: $items))
                    .environment(\.rowIndex, index)
                    .id(newRowFocus?.identity(ofRow: index))
                    .trackingScreenFrame(of: index, in: frames)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // role .none, as on the list of CVs: .destructive makes the confirmation dialog flicker
                        Button(role: .none) {
                            deletionAnchor.rect = frames.rect(for: index)
                            animatedRemove(at: index)
                        } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                        .tint(DesignTokens.Colors.error)
                        .accessibilityLabel(deleteLabel(item))
                    }
            }
        }
    }
    
    private func animatedRemove(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            onRemove(index)
        }
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
