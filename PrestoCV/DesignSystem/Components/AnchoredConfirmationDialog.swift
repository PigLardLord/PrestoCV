import SwiftUI

/// Where views are on the screen, by key, kept without drawing them again each time one of them moves: a list that
/// scrolls moves its rows all the time, and only the place of the row that was tapped is ever read.
final class ScreenFrames<Key: Hashable> {
    private var rects: [Key: CGRect] = [:]

    func rect(for key: Key) -> CGRect? {
        rects[key]
    }

    fileprivate func record(_ rect: CGRect, for key: Key) {
        rects[key] = rect
    }
}

extension View {
    /// Records where this view is on the screen in `frames`, under `key`.
    func trackingScreenFrame<Key: Hashable>(of key: Key, in frames: ScreenFrames<Key>) -> some View {
        onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { frames.record($0, for: key) }
    }

    /// A confirmation dialog that, where it is a popover, points at `anchor`, a rectangle on the screen, and not at
    /// the whole view it is attached to. Without an anchor it points at the middle of the view.
    ///
    /// - Parameter spanningWidth: Points at the full width of the view, at the height of the anchor. A row of a list
    ///   that is swiped open has slid sideways, and the dialog of its action should still point at the row.
    func anchoredConfirmationDialog<Data, Actions: View, Message: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        presenting data: Data?,
        anchoredTo anchor: CGRect?,
        spanningWidth: Bool = false,
        @ViewBuilder actions: @escaping (Data) -> Actions,
        @ViewBuilder message: @escaping (Data) -> Message
    ) -> some View {
        overlay {
            GeometryReader { proxy in
                let own = proxy.frame(in: .global)
                let target = anchor.map { spanningWidth ? CGRect(x: own.minX, y: $0.minY, width: own.width, height: $0.height) : $0 } ?? own
                // The dialog is attached to the small view, and only then is that view placed: a dialog attached to
                // the placed view would point at everything the placement fills
                Color.clear
                    .frame(width: target.width, height: target.height)
                    .confirmationDialog(
                        title,
                        isPresented: isPresented,
                        titleVisibility: titleVisibility,
                        presenting: data,
                        actions: actions,
                        message: message
                    )
                    .position(x: target.midX - own.minX, y: target.midY - own.minY)
                    // A popover keeps the place its source had when it was made: a source that slides there, as the
                    // rows of the editor do when one is removed with an animation, would be pointed at where it was
                    .transaction { $0.animation = nil }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Row Deletion Anchor

/// Where the row whose delete button was swiped open is on the screen, so that the confirmation can point at it.
final class RowDeletionAnchor {
    var rect: CGRect?
}

private struct RowDeletionAnchorKey: EnvironmentKey {
    static let defaultValue = RowDeletionAnchor()
}

extension EnvironmentValues {
    var rowDeletionAnchor: RowDeletionAnchor {
        get { self[RowDeletionAnchorKey.self] }
        set { self[RowDeletionAnchorKey.self] = newValue }
    }
}
