import SwiftUI
import UIKit

extension View {
    /// Keeps the swipe that goes back working on a screen with a Back button of its own, and lets the screen decide when it
    /// may go back at once.
    ///
    /// A screen that hides the system's Back button loses the swipe with it. The swipe goes back at once when
    /// `canLeaveAtOnce` says so; otherwise it does not start, and `leave` is called instead, so that the screen can do
    /// what its Back button does before it goes back, or stay. The rest of that swipe does nothing, and no swipe takes
    /// hold of the screen while it goes.
    /// - Parameters:
    ///   - canLeaveAtOnce: Asked when a swipe starts: whether the screen may go back without any work first.
    ///   - leave: Goes back the way the Back button does. Called at most once per swipe.
    func guardsBackSwipe(canLeaveAtOnce: @escaping () -> Bool, leave: @escaping () -> Void) -> some View {
        background(GuardedBackSwipe(canLeaveAtOnce: canLeaveAtOnce, leave: leave))
    }
}

/// Sits behind a screen and takes the delegate of the gestures that go back from the time the screen is shown until it is
/// gone.
struct GuardedBackSwipe: UIViewControllerRepresentable {
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
        /// The swipe under way called `leave`: the rest of it does not go back a second way.
        private var swipeCalledLeave = false

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
            // A pop taken back shows the screen again without `viewDidDisappear`: the guard still has the gestures, and
            // taking them again would keep itself as the system's delegate
            guard navigation == nil, let navigation = navigationController else { return }
            self.navigation = navigation
            edgeDelegate = navigation.interactivePopGestureRecognizer?.delegate
            navigation.interactivePopGestureRecognizer?.delegate = self
            contentDelegate = navigation.interactiveContentPopGestureRecognizer?.delegate
            navigation.interactiveContentPopGestureRecognizer?.delegate = self
        }

        // Given back once the screen is gone, not when it starts to go: during the pop the system's delegate lets a swipe
        // take hold of it, and a swipe that ends there takes the pop back, which leaves the screen shown with the bar of the
        // screen below it and no way back
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            guard let navigation else { return }
            navigation.interactivePopGestureRecognizer?.delegate = edgeDelegate
            navigation.interactiveContentPopGestureRecognizer?.delegate = contentDelegate
            self.navigation = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // The first finger starts a swipe; a finger that joins one is part of it
            if gestureRecognizer.numberOfTouches == 0 {
                swipeCalledLeave = false
            }
            return true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Never during a transition, and never on the root, as the navigation controller itself decides
            guard let navigation, navigation.viewControllers.count > 1, navigation.transitionCoordinator == nil else { return false }
            // One swipe asks both gestures, the edge pan and the content pan. Once one has called `leave`, the other refuses
            // too, even when `leave` has stored the form by then, or the swipe would also start a pop of its own. When one
            // begins, UIKit does not let the other begin with it
            guard !swipeCalledLeave else { return false }
            if canLeaveAtOnce() {
                return true
            }
            swipeCalledLeave = true
            leave()
            return false
        }
    }
}
