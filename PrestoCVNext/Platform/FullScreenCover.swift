import SwiftUI

extension View {
    /// Shows the item's screen over the whole screen while the item is set: a cover on iOS, a sheet on a Mac, which has
    /// no cover.
    ///
    /// - Parameters:
    ///   - item: The item shown; nil closes it, and closing it sets nil.
    ///   - content: The screen of the item.
    func fullScreenPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>, content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}
