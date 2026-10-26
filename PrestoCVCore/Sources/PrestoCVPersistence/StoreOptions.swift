import Foundation

/// The class of protection the CV store gives its files (ADR 0009).
public enum FileProtection: Sendable, Equatable {
    /// Unreadable while the device is locked (class A). What the app uses, and the default. The simulator and Linux do not apply it.
    case complete
    /// No protection class. For tests of the store's logic: a class-A write needs the user's key, and a host whose
    /// keybag is locked refuses it with `EPERM`, so those tests would depend on the host.
    case unprotected
}

/// What the composition root gives the CV store beside its location and its clock: the size cap of a file and the
/// protection class of what it writes. Grouped, so that the store's initializer keeps to three parameters.
public struct StoreOptions: Sendable, Equatable {
    public var maxFileBytes: Int
    public var protection: FileProtection

    public init(maxFileBytes: Int = 5 * 1024 * 1024, protection: FileProtection = .complete) {
        self.maxFileBytes = maxFileBytes; self.protection = protection
    }

    /// The options of every write: always atomic, so a failed write never leaves half a file; the protection class as given.
    var writing: Data.WritingOptions {
        switch protection {
        case .complete: [.atomic, .completeFileProtection]
        case .unprotected: [.atomic]
        }
    }
}
