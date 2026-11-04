import Foundation
import Testing
@testable import PrestoCV

// MARK: - Release Hygiene Tests

/// What the Release build must not carry, as the app bundle shows it. The scans of the code that ships and of the
/// privacy manifest read the repository, so they are in Tools/SourceChecks, which runs where the repository is.
@Suite("Release Hygiene Tests")
struct ReleaseHygieneTests {

    // MARK: Bundle

    @Test("The app bundle carries no sample data that nothing reads")
    func bundleHoldsNoUnusedSampleData() {
        let bundle = Bundle(for: AppRouter.self)

        #expect(bundle.url(forResource: "default", withExtension: "json") == nil)
        for name in ["technical", "business", "creative", "academic", "healthcare"] {
            #expect(bundle.url(forResource: "\(name).cv", withExtension: "json") == nil, "\(name).cv.json")
        }
    }
}
