import SwiftUI

extension View {
    /// Tells `changed` whether the screen is narrow, when the view shows and whenever its width class changes: a compact
    /// width is narrow (an iPhone, an iPad in a narrow split). A Mac window is never narrow.
    func onNarrowScreen(_ changed: @escaping (Bool) -> Void) -> some View {
        modifier(NarrowScreenReader(changed: changed))
    }
}

private struct NarrowScreenReader: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    let changed: (Bool) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.onChange(of: horizontalSizeClass, initial: true) { _, size in changed(size == .compact) }
        #else
        content.onAppear { changed(false) }
        #endif
    }
}
