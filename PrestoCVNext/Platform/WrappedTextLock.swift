import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Keeps a text field whose line wraps from scrolling its own text, so that a drag that starts on it scrolls the
    /// form around it. The wrapped field grows with its text, so its whole text is in sight and the lock hides none of
    /// it.
    ///
    /// On iOS 27, at the accessibility text sizes, such a field comes out a fraction of a point shorter than its text,
    /// so its text view can scroll by that fraction: it takes every vertical drag that starts on it and bounces back,
    /// and the form under the finger does not move. `scrollDisabled` does not reach that text view, so on iOS the lock
    /// turns its scrolling off itself. A Mac scrolls with the pointer and has no such drag, so there the field is left
    /// as it is.
    /// - Parameter wraps: Whether the field wraps its line. A field on one line is left as it is.
    func wrappedTextNeverScrolls(_ wraps: Bool) -> some View {
        #if os(iOS)
        background {
            if wraps {
                WrappedTextLock()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Sits behind a wrapped text field, with its frame, and turns off the scrolling of its text view: the text view whose
/// frame holds the lock's center, among the views around the lock up to the scroll view of the form.
private struct WrappedTextLock: UIViewRepresentable {
    func makeUIView(context: Context) -> Marker {
        Marker()
    }

    func updateUIView(_ marker: Marker, context: Context) {
        marker.lockAfterLayout()
    }

    final class Marker: UIView {
        private var lockIsDue = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
        }

        /// Made in code only.
        required init?(coder: NSCoder) {
            return nil
        }

        // A new text view comes with a new marker: the field is made anew, the marker with it
        override func didMoveToWindow() {
            super.didMoveToWindow()
            lockAfterLayout()
        }

        // The field grew or shrank with its text
        override func layoutSubviews() {
            super.layoutSubviews()
            lockAfterLayout()
        }

        /// Locks the field once the layout under way is done: until then its text view may not have its frame yet.
        func lockAfterLayout() {
            guard !lockIsDue else { return }
            lockIsDue = true
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }

        private func lock() {
            lockIsDue = false
            guard let window else { return }
            let center = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: window)
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) {
                if let textView = view.textView(holding: center, in: window) {
                    if textView.isScrollEnabled {
                        textView.isScrollEnabled = false
                    }
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

private extension UIView {
    /// The first text view among the views inside this one whose frame holds `point`, given in the coordinates of
    /// `window`.
    func textView(holding point: CGPoint, in window: UIWindow) -> UITextView? {
        for subview in subviews where !subview.isHidden {
            if let textView = subview as? UITextView, textView.convert(textView.bounds, to: window).contains(point) {
                return textView
            }
            if let textView = subview.textView(holding: point, in: window) {
                return textView
            }
        }
        return nil
    }
}
#endif
