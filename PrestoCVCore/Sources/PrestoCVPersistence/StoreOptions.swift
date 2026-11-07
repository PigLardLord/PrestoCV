import Foundation

/// The class of protection the CV store gives its files (ADR 0009).
public enum FileProtection: Sendable, Equatable {
    /// Unreadable while the device is locked (class A). What the app uses, and the default. The simulator and Linux do not apply it.
    case complete
    /// No protection class. For tests of the store's logic: a class-A write needs the user's key, and a host whose
    /// keybag is locked refuses it with `EPERM`, so those tests would depend on the host.
    case unprotected
}

/// What the composition root gives the CV store beside its location and its clock: the size cap of a file, the
/// protection class of what it writes and how long it waits for the store's lock. Grouped, so that the store's
/// initializer keeps to three parameters.
public struct StoreOptions: Sendable {
    public var maxFileBytes: Int
    public var protection: FileProtection
    public var lockWait: LockWait

    public init(maxFileBytes: Int = 5 * 1024 * 1024, protection: FileProtection = .complete, lockWait: LockWait = .standard) {
        self.maxFileBytes = maxFileBytes; self.protection = protection; self.lockWait = lockWait
    }

    /// The options of every write: always atomic, so a failed write never leaves half a file; the protection class as given.
    var writing: Data.WritingOptions {
        switch protection {
        case .complete: [.atomic, .completeFileProtection]
        case .unprotected: [.atomic]
        }
    }

    /// How the store waits while its lock is held elsewhere (ADR 0009): it tries again after each pause, and gives up
    /// with `storeUnavailable(.lockTimeout)` once the pauses add up to the deadline. The pause suspends the caller; it
    /// never holds a thread.
    public struct LockWait: Sendable {
        public let deadline: Duration, interval: Duration
        let pause: @Sendable (Duration) async -> Void

        /// `pause` waits for about the duration it is given. Tests pass one that does not wait.
        public init(deadline: Duration, interval: Duration, pause: @escaping @Sendable (Duration) async -> Void) {
            self.deadline = deadline; self.interval = interval; self.pause = pause
        }

        /// What the app uses: ten seconds, in pauses of 25 milliseconds on the real clock. The pause sleeps in a task of
        /// its own, which does not inherit the caller's cancellation: a cancelled call keeps waiting until the deadline
        /// (R3), and its only failure, a cancellation, cannot happen.
        public static let standard = LockWait(deadline: .seconds(10), interval: .milliseconds(25)) { interval in
            let sleeping = Task { try await Task.sleep(for: interval) }
            _ = await sleeping.result
        }
    }
}
