import SwiftUI
import UIKit

extension View {
    /// Keeps the swipe that goes back working on a screen with a Back button of its own, and lets the screen decide when it
    /// may go back at once.
    ///
    /// A screen that hides the system's Back button loses the swipe with it. The swipe goes back at once when
    /// `canLeaveAtOnce` says so; otherwise it does not start, and `leave` is called instead, so that the screen can do
    /// what its Back button does before it goes back, or stay.
    /// - Parameters:
    ///   - canLeaveAtOnce: Asked when a swipe starts: whether the screen may go back without any work first.
    ///   - leave: Goes back the way the Back button does.
    func guardsBackSwipe(canLeaveAtOnce: @escaping () -> Bool, leave: @escaping () -> Void) -> some View {
        background(GuardedBackSwipe(canLeaveAtOnce: canLeaveAtOnce, leave: leave))
    }
}

/// Sits behind a screen and takes the delegate of the gestures that go back for as long as the screen is shown.
private struct GuardedBackSwipe: UIViewControllerRepresentable {
    let canLeaveAtOnce: () -> Bool
    let leave: () -> Void

    func makeUIViewController(context: Context) -> Guard {
        Guard(canLeaveAtOnce: canLeaveAtOnce, leave: leave)
    }

    func updateUIViewController(_ controller: Guard, context: Context) {
        controller.canLeaveAtOnce = canLeaveAtOnce
        controller.leave = leave
    }

    final class Guard: UIViewController, UIGestureRecognizerDelegate {
        var canLeaveAtOnce: () -> Bool
        var leave: () -> Void
        private weak var navigation: UINavigationController?
        private var edgeDelegate: UIGestureRecognizerDelegate?
        private var contentDelegate: UIGestureRecognizerDelegate?

        init(canLeaveAtOnce: @escaping () -> Bool, leave: @escaping () -> Void) {
            self.canLeaveAtOnce = canLeaveAtOnce
            self.leave = leave
            super.init(nibName: nil, bundle: nil)
        }

        /// Made in code only.
        required init?(coder: NSCoder) {
            return nil
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard navigation == nil, let navigation = navigationController else { return }
            self.navigation = navigation
            edgeDelegate = navigation.interactivePopGestureRecognizer?.delegate
            navigation.interactivePopGestureRecognizer?.delegate = self
            contentDelegate = navigation.interactiveContentPopGestureRecognizer?.delegate
            navigation.interactiveContentPopGestureRecognizer?.delegate = self
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let navigation else { return }
            navigation.interactivePopGestureRecognizer?.delegate = edgeDelegate
            navigation.interactiveContentPopGestureRecognizer?.delegate = contentDelegate
            self.navigation = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Never during a transition, and never on the root, as the navigation controller itself decides
            guard let navigation, navigation.viewControllers.count > 1, navigation.transitionCoordinator == nil else { return false }
            if canLeaveAtOnce() {
                return true
            }
            leave()
            return false
        }
    }
}
