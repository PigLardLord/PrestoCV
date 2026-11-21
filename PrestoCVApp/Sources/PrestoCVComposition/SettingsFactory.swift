import Foundation
import PrestoCVIntegration
import PrestoCVPresentation

/// Makes the view models of the Settings sheet (#405) and its Licences screen (#504) from what the launch read about the
/// app, so that neither reads a bundle itself (R17).
@MainActor
public struct SettingsFactory {
    /// What the sheet shows about the app, chosen by `launch`.
    struct Facts {
        let supportAddress: String
        /// Nil when the composition could not make the link: the row is then left out
        let privacyPolicy: URL?
        /// A prestocv.app page about the source, never the code host itself (#504)
        let sourceCode: URL?
        let version: String
        let build: String
        let appName: String
        /// Reads the bytes of the notices file the app bundles, each time the Licences screen asks
        let notices: @Sendable () async throws -> Data
    }

    private let facts: Facts

    init(facts: Facts) {
        self.facts = facts
    }

    public func makeSettings() -> SettingsViewModel {
        SettingsViewModel(
            supportAddress: facts.supportAddress, privacyPolicy: facts.privacyPolicy, sourceCode: facts.sourceCode,
            version: facts.version, build: facts.build, appName: facts.appName
        )
    }

    public func makeLicences() -> LicencesViewModel {
        LicencesViewModel(reading: LicenceNoticesFile(contents: facts.notices))
    }
}
