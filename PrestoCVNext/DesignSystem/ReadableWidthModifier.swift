import SwiftUI

extension View {
    /// Limits the view to the readable width and centres it in the space it is given.
    func readableWidth() -> some View {
        frame(maxWidth: ReadableWidth.maximum)
            .frame(maxWidth: .infinity)
    }
}
