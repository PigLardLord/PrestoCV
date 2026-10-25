import Foundation
import PrestoCVApplication

extension FailureCause {
    /// Keeps the domain and the code of a Foundation error, and the `errno` under it when it has one: codes only, because
    /// its message and its user info carry paths (R7). An error that is not an `NSError` is bridged first, so it has a
    /// code too.
    init(_ error: any Error) {
        let bridged = error as NSError
        switch bridged.domain {
        case NSPOSIXErrorDomain: self.init(domain: .posix, code: bridged.code)
        case NSCocoaErrorDomain: self.init(domain: .cocoa, code: bridged.code, underlyingPOSIX: Self.posixCode(under: bridged))
        default: self.init(domain: .other, code: bridged.code, underlyingPOSIX: Self.posixCode(under: bridged))
        }
    }

    private static func posixCode(under error: NSError) -> Int? {
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSPOSIXErrorDomain else { return nil }
        return underlying.code
    }
}
