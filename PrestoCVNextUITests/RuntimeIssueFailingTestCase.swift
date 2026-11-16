import XCTest

/// The base of the new stack's UI tests: a runtime issue the app reports fails the test.
///
/// SwiftUI and UIKit report some defects only as runtime issues while the app runs, such as "Invalid frame dimension
/// (negative or non-finite)." from a view that lays itself out with a size it cannot have (#478). XCTest records such an issue
/// with the test that was running as a warning, which does not fail the test, so a new one would go unseen. This records it
/// as a failure, with the same description and the same place.
class RuntimeIssueFailingTestCase: XCTestCase {

    /// The raw value of the type XCTest gives a runtime issue. XCTest's headers declare no name for it (they list the types
    /// up to 5); 102 is the value it records for the runtime issues of the app under test.
    static let runtimeIssueType = 102

    override func record(_ issue: XCTIssue) {
        guard issue.type.rawValue == Self.runtimeIssueType else {
            super.record(issue)
            return
        }
        var failure = issue
        failure.type = .assertionFailure
        failure.severity = .error
        failure.compactDescription = "Runtime issue of the app: \(issue.compactDescription)"
        super.record(failure)
    }
}
