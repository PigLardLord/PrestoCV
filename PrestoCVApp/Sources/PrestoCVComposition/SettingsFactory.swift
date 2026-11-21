import Foundation
import PrestoCVIntegration
import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// Makes the view models of the Settings sheet (#405), its Licences screen (#504) and the Diagnostics screen of a test
/// build (#405) from what the launch read about the app, so that none reads a bundle itself (R17).
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
    private let diagnostics: any DiagnosticsReading

    /// - Parameter diagnostics: The trace of a test build, over its gate (`TraceDiagnostics`).
    init(facts: Facts, diagnostics: any DiagnosticsReading) {
        self.facts = facts
        self.diagnostics = diagnostics
    }

    public func makeSettings() -> SettingsViewModel {
        SettingsViewModel(
            supportAddress: facts.supportAddress, privacyPolicy: facts.privacyPolicy, sourceCode: facts.sourceCode,
            version: facts.version, build: facts.build, appName: facts.appName, diagnostics: diagnostics
        )
    }

    public func makeLicences() -> LicencesViewModel {
        LicencesViewModel(reading: LicenceNoticesFile(contents: facts.notices))
    }

    public func makeDiagnostics() -> DiagnosticsViewModel {
        DiagnosticsViewModel(reading: diagnostics)
    }
}
