import Foundation
import Synchronization
import PrestoCVApplication
import PrestoCVDomain

/// An identity generator that counts: `00000000-0000-0000-0000-000000000001`, then `…002`, so tests are deterministic.
public final class SequentialIDGenerator: IDGenerator {
    private let issued = Mutex(0)

    public init() {}

    /// The next identity in the sequence.
    public func next() -> CVID {
        let number = String(issued.withLock { count -> Int in
            count += 1
            return count
        })
        let digits = String(repeating: "0", count: max(0, 12 - number.count)) + number
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-" + digits) else { preconditionFailure("more than 10^12 ids in a test") }
        return CVID(uuid)
    }
}
