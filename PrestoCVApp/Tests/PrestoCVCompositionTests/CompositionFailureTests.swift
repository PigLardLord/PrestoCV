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

    @Test("The codes are distinct words")
    func rawValues() {
        #expect(CompositionFailure.allCases.map(\.rawValue) == ["storeUnavailable", "contentRulesUnavailable", "launchFixturesRejected"])
    }

    #if DEBUG
    @Test("Every launch fixture failure is launchFixturesRejected")
    func fixtures() {
        let failures: [LaunchFixtures.Failure] = [
            .conflictingStorage, .missingValue(argument: "-PrestoCVNextSeed"), .invalidFolderName, .unreadableSeed,
            .unreadableDistribution, .seedWithoutFolder, .seedUnwritable,
        ]
        for failure in failures {
            #expect(CompositionFailure(failure) == .launchFixturesRejected)
        }
    }
    #endif
}
