import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// The wall clock, as the app's `TimeSource`.
struct SystemTimeSource: TimeSource {
    func now() -> Date { Date() }
}

/// New identities, as the app's `IDGenerator`.
struct UUIDGenerator: IDGenerator {
    func next() -> CVID { CVID(UUID()) }
}
