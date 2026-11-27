import XCTest

/// The base class of the UI tests fails a test on a runtime issue and leaves the other issues as they come. No app is
/// launched: the issues are recorded as XCTest records those the app reports, a runtime issue as a warning.
final class RuntimeIssueTests: RuntimeIssueFailingTestCase {

    /// A runtime issue is recorded as a failure, with its description.
    func testARuntimeIssueFailsTheTest() throws {
        let runtimeIssue = try XCTUnwrap(XCTIssue.IssueType(rawValue: Self.runtimeIssueType))
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.isFailure && issue.type == .assertionFailure
                && issue.compactDescription == "Runtime issue of the app: Invalid frame dimension (negative or non-finite)."
        }

        XCTExpectFailure("A runtime issue of the app is recorded as a failure", options: options) {
            record(XCTIssue(
                type: runtimeIssue,
                compactDescription: "Invalid frame dimension (negative or non-finite).",
                severity: .warning
            ))
        }
    }

    /// An issue of another type keeps its type: a thrown error stays a thrown error.
    func testAnotherIssueKeepsItsType() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in issue.type == .thrownError }

        XCTExpectFailure("A thrown error is recorded as it came", options: options) {
            record(XCTIssue(type: .thrownError, compactDescription: "An error the test threw."))
        }
    }
}
