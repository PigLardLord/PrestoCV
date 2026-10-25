import Testing
import UIKit
@testable import PrestoCV

/// The swipe that goes back on a screen with a Back button of its own. One swipe is seen by two gestures, the edge pan and
/// the content pan, one after the other: it gets one answer, and the guard keeps both gestures until the screen is gone,
/// so that no swipe takes hold of the pop that `leave` started and takes it back.
@Suite("The guarded back swipe - one answer per swipe, kept until the screen is gone")
@MainActor
struct GuardedBackSwipeTests {

    /// A navigation controller, a screen above its root, and the guard in that screen.
    private struct Stack {
        let edge: UIGestureRecognizer
        let content: UIGestureRecognizer
        /// The delegates the navigation controller gave its gestures.
        let systemEdgeDelegate: AnyObject?
        let systemContentDelegate: AnyObject?
        let guardian: GuardedBackSwipe.Guard
        /// Kept, with the screen it holds, for as long as the test runs.
        let navigation: UINavigationController
    }

    /// The guard in a screen above the root, shown, as after the screen was pushed.
    private func shownGuard(canLeaveAtOnce: @escaping () -> Bool, leave: @escaping () -> Void = {}) throws -> Stack {
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.loadViewIfNeeded()
        let edge = try #require(navigation.interactivePopGestureRecognizer)
        let content = try #require(navigation.interactiveContentPopGestureRecognizer)
        let systemEdgeDelegate = edge.delegate as AnyObject?
        let systemContentDelegate = content.delegate as AnyObject?
        let screen = UIViewController()
        let guardian = GuardedBackSwipe.Guard(canLeaveAtOnce: canLeaveAtOnce, leave: leave)
        screen.addChild(guardian)
        screen.view.addSubview(guardian.view)
        guardian.didMove(toParent: screen)
        navigation.pushViewController(screen, animated: false)
        guardian.beginAppearanceTransition(true, animated: false)
        guardian.endAppearanceTransition()
        return Stack(
            edge: edge,
            content: content,
            systemEdgeDelegate: systemEdgeDelegate,
            systemContentDelegate: systemContentDelegate,
            guardian: guardian,
            navigation: navigation
        )
    }

    /// The first finger of a swipe lands: each gesture asks its delegate whether it takes it, as UIKit does.
    private func touchDown(on stack: Stack) {
        #expect(receives(UITouch(), stack.edge))
        #expect(receives(UITouch(), stack.content))
    }

    /// Whether the delegate of `gesture` lets it take `touch`: yes when the delegate does not answer, as in UIKit.
    private func receives(_ touch: UITouch, _ gesture: UIGestureRecognizer, delegate: UIGestureRecognizerDelegate? = nil) -> Bool {
        (delegate ?? gesture.delegate)?.gestureRecognizer?(gesture, shouldReceive: touch) ?? true
    }

    // MARK: - The gestures while the screen goes

    @Test("The guard keeps both gestures while the screen disappears, and gives them back to the system once it is gone")
    func keepsTheGesturesUntilTheScreenIsGone() throws {
        let stack = try shownGuard(canLeaveAtOnce: { true })
        #expect(stack.edge.delegate as AnyObject? === stack.guardian, "The shown screen should guard the edge swipe")
        #expect(stack.content.delegate as AnyObject? === stack.guardian, "The shown screen should guard the content swipe")

        // The pop begins: the system's delegate would let a swipe take hold of it and take it back
        stack.guardian.beginAppearanceTransition(false, animated: true)

        #expect(stack.edge.delegate as AnyObject? === stack.guardian, "The edge swipe should stay guarded during the pop")
        #expect(stack.content.delegate as AnyObject? === stack.guardian, "The content swipe should stay guarded during the pop")

        stack.guardian.endAppearanceTransition()

        #expect(stack.edge.delegate as AnyObject? === stack.systemEdgeDelegate, "The edge swipe should go back to the system")
        #expect(stack.content.delegate as AnyObject? === stack.systemContentDelegate, "The content swipe should go back to the system")
    }

    @Test("A pop taken back leaves the gestures with the guard, which gives the system's back when the screen goes")
    func aPopTakenBackKeepsTheGuard() throws {
        let stack = try shownGuard(canLeaveAtOnce: { true })

        stack.guardian.beginAppearanceTransition(false, animated: true)
        stack.guardian.beginAppearanceTransition(true, animated: true)
        stack.guardian.endAppearanceTransition()

        #expect(stack.edge.delegate as AnyObject? === stack.guardian, "The screen is still shown: the edge swipe should stay guarded")
        #expect(stack.content.delegate as AnyObject? === stack.guardian, "The screen is still shown: the content swipe should stay guarded")

        stack.guardian.beginAppearanceTransition(false, animated: true)
        stack.guardian.endAppearanceTransition()

        #expect(stack.edge.delegate as AnyObject? === stack.systemEdgeDelegate, "The edge swipe should go back to the system")
        #expect(stack.content.delegate as AnyObject? === stack.systemContentDelegate, "The content swipe should go back to the system")
    }

    // MARK: - One answer per swipe

    @Test("A swipe that called leave does not go back of itself once the store holds the form")
    func aSwipeThatCalledLeaveDoesNotAlsoGoBack() throws {
        var storeHoldsTheForm = false
        var leaves = 0
        // The save is quick: it is over before the content pan sees the swipe
        let stack = try shownGuard(canLeaveAtOnce: { storeHoldsTheForm }, leave: { leaves += 1; storeHoldsTheForm = true })
        touchDown(on: stack)

        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.edge), "Edits the store does not hold should not go back at once")
        #expect(leaves == 1, "The swipe should leave the way Back does")

        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.content), "The rest of the swipe should not start a pop of its own")
        #expect(leaves == 1, "One swipe should leave once")
    }

    @Test("A swipe that called leave, with an editor that stays, leaves once")
    func aSwipeLeavesOnceWhenTheEditorStays() throws {
        var leaves = 0
        // The store keeps failing: the editor stays, with its edits
        let stack = try shownGuard(canLeaveAtOnce: { false }, leave: { leaves += 1 })
        touchDown(on: stack)

        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.edge))
        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.content))

        #expect(leaves == 1, "One swipe should try to leave once")
    }

    @Test("The next swipe asks again: it goes back at once when the store holds the form, and leaves again when it does not")
    func theNextSwipeAsksAgain() throws {
        var storeHoldsTheForm = false
        var leaves = 0
        let stack = try shownGuard(canLeaveAtOnce: { storeHoldsTheForm }, leave: { leaves += 1 })
        touchDown(on: stack)
        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.edge))

        touchDown(on: stack)
        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.edge), "The edits are still not stored")
        #expect(leaves == 2, "A new swipe should leave again")

        storeHoldsTheForm = true
        touchDown(on: stack)
        #expect(stack.guardian.gestureRecognizerShouldBegin(stack.edge), "A swipe with nothing to store should go back at once")
    }

    @Test("A finger that joins a swipe is part of it")
    func aFingerThatJoinsIsPartOfTheSwipe() throws {
        var storeHoldsTheForm = false
        let stack = try shownGuard(canLeaveAtOnce: { storeHoldsTheForm }, leave: { storeHoldsTheForm = true })
        touchDown(on: stack)
        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.edge))

        // The content pan already follows the first finger when the second one lands
        #expect(receives(UITouch(), PanFollowingAFinger(), delegate: stack.guardian))

        #expect(!stack.guardian.gestureRecognizerShouldBegin(stack.content), "The swipe should keep the answer it got")
    }
}

/// A pan that follows a finger already.
private final class PanFollowingAFinger: UIPanGestureRecognizer {
    override var numberOfTouches: Int { 1 }
}
