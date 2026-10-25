import Foundation
import PrestoCVApplication

extension FailureCause {
    /// Keeps the domain and the code of a Foundation error and nothing else: its message and its user info carry paths
    /// (R7). An error that is not an `NSError` is bridged first, so it has a code too.
    init(_ error: any Error) {
        let bridged = error as NSError
        switch bridged.domain {
        case NSCocoaErrorDomain: self.init(domain: .cocoa, code: bridged.code)
        case NSPOSIXErrorDomain: self.init(domain: .posix, code: bridged.code)
        default: self.init(domain: .other, code: bridged.code)
        }
    }
}
