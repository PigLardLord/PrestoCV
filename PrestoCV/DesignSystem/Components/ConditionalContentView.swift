import SwiftUI

/// A reusable component that shows either empty state or content based on a condition
struct ConditionalContentView<Content: View, EmptyContent: View>: View {
    let isEmpty: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let emptyContent: () -> EmptyContent
    
    init(
        isEmpty: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self.isEmpty = isEmpty
        self.content = content
        self.emptyContent = emptyContent
    }
    
    var body: some View {
        if isEmpty {
            emptyContent()
        } else {
            content()
        }
    }
}