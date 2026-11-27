import Foundation
import Synchronization

/// Whether the code that asks runs on the main actor. The main actor runs its work on the main queue: on Apple's systems
/// that is the main thread, but on Linux the test runner hands its main thread to Dispatch, which then runs the main
/// queue on a thread of its own, so `Thread.isMainThread` alone would be false there for any code (R19). A mark set on
/// the main queue is seen by the code that queue runs, on both.
enum MainActorProbe {
    private static let mark: Mutex<DispatchSpecificKey<Bool>> = {
        let mark = DispatchSpecificKey<Bool>()
        DispatchQueue.main.setSpecific(key: mark, value: true)
        return Mutex(mark)
    }()

    /// True on the main actor, false off it. Called from synchronous code only, as `Thread` asks.
    static var isOnTheMainActor: Bool {
        Thread.isMainThread || mark.withLock { DispatchQueue.getSpecific(key: $0) } == true
    }
}
