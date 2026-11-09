import CVRendering
import CVRenderingWebKitSupport
import Foundation
import Testing
@testable import PrestoCVComposition

/// Each construction failure is one code of the one error screen (R13).
@Suite("The failure codes of the composition")
struct CompositionFailureTests {
    @Test("A store folder that cannot be made is storeUnavailable")
    func paths() {
        #expect(CompositionFailure(AppPaths.Failure.storeUnavailable) == .storeUnavailable)
    }

    @Test("Rules that cannot be compiled are contentRulesUnavailable")
    func rules() {
        #expect(CompositionFailure(SecureWebViewConfiguration.Failure.contentRulesUnavailable) == .contentRulesUnavailable)
    }

    @Test("Headings that cannot be read are headingsUnavailable")
    func headings() {
        let failures: [HeadingsCatalog.Failure] = [
            .unsupportedLanguage("it"), .incomplete(language: "it", key: "experience"), .corruptTable("it"),
        ]
        for failure in failures {
            #expect(CompositionFailure(failure) == .headingsUnavailable)
        }
    }

    @Test("The codes are distinct words")
    func rawValues() {
        #expect(CompositionFailure.allCases.map(\.rawValue) == [
            "storeUnavailable", "contentRulesUnavailable", "launchFixturesRejected", "designStoreUnavailable",
            "bundledDesignsUnavailable", "designSyncInterrupted", "headingsUnavailable",
        ])
    }

    #if DEBUG
    @Test("Every launch fixture failure is launchFixturesRejected")
    func fixtures() {
        let failures: [LaunchFixtures.Failure] = [
            .conflictingStorage, .missingValue(argument: "-PrestoCVNextSeed"), .invalidFolderName, .unreadableSeed,
            .unreadableDistribution, .seedWithoutFolder, .seedUnwritable, .unsafeFolder,
        ]
        for failure in failures {
            #expect(CompositionFailure(failure) == .launchFixturesRejected)
        }
    }
    #endif
}
