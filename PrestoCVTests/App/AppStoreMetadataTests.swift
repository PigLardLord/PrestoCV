import Foundation
import Testing

// MARK: - App Store Metadata Tests

/// What App Store Connect reads from the built app: the privacy manifest and the export compliance answer.
@Suite("App Store Metadata Tests")
struct AppStoreMetadataTests {

    @Test("The privacy manifest ships in the app bundle and declares no tracking and no collected data")
    func privacyManifestDeclaresNoTrackingAndNoData() throws {
        let manifest = try privacyManifest()

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }

    @Test("Every required-reason API in the privacy manifest names its category and at least one reason")
    func accessedAPIEntriesAreComplete() throws {
        let manifest = try privacyManifest()

        let entries = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        for entry in entries {
            #expect((entry["NSPrivacyAccessedAPIType"] as? String)?.isEmpty == false)
            #expect((entry["NSPrivacyAccessedAPITypeReasons"] as? [String])?.isEmpty == false)
        }
    }

    @Test("The app declares that it uses no encryption beyond the one the system provides")
    func appUsesNoNonExemptEncryption() {
        let declared = Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool

        #expect(declared == false)
    }

    // MARK: - Helpers

    private func privacyManifest() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }
}
