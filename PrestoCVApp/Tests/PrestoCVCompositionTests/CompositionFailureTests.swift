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
            "storeUnavailable", "contentRulesUnavailable", "launchFixturesRejected", "headingsUnavailable",
        ])
    }

    #if DEBUG
    @Test("Every launch fixture failure is launchFixturesRejected")
    func fixtures() {
        for kind in FixtureFailureKind.allCases {
            let failure = Self.sample(of: kind)
            #expect(Self.kind(of: failure) == kind)
            #expect(CompositionFailure(failure) == .launchFixturesRejected)
        }
    }

    // MARK: Every fixture failure

    /// One kind per case of `LaunchFixtures.Failure`, which cannot be `CaseIterable` because `missingValue` carries
    /// its argument. `kind(of:)` switches over the failure with no default, so a new case does not compile until it
    /// has a kind here, and `fixtures()` then checks it.
    enum FixtureFailureKind: CaseIterable {
        case conflictingStorage, missingValue, invalidFolderName, unreadableSeed, unreadableDistribution
        case unreadableTips, seedWithoutFolder, unreadableLegacySeed, legacySeedWithoutFolder, samplesWithoutFolder
        case failuresWithoutFolder, unreadableOtherWindow, otherWindowWithoutFolder, unreadableFailWrites
        case failWritesWithoutFolder, unreadableAutosavePause, unreadableOpenedFile, traceRunsWithoutFolder
        case readyDesignsWithoutFolder, seedUnwritable, unsafeFolder
    }

    private static func kind(of failure: LaunchFixtures.Failure) -> FixtureFailureKind {
        switch failure {
        case .conflictingStorage: .conflictingStorage
        case .missingValue: .missingValue
        case .invalidFolderName: .invalidFolderName
        case .unreadableSeed: .unreadableSeed
        case .unreadableDistribution: .unreadableDistribution
        case .unreadableTips: .unreadableTips
        case .seedWithoutFolder: .seedWithoutFolder
        case .unreadableLegacySeed: .unreadableLegacySeed
        case .legacySeedWithoutFolder: .legacySeedWithoutFolder
        case .samplesWithoutFolder: .samplesWithoutFolder
        case .failuresWithoutFolder: .failuresWithoutFolder
        case .unreadableOtherWindow: .unreadableOtherWindow
        case .otherWindowWithoutFolder: .otherWindowWithoutFolder
        case .unreadableFailWrites: .unreadableFailWrites
        case .failWritesWithoutFolder: .failWritesWithoutFolder
        case .unreadableAutosavePause: .unreadableAutosavePause
        case .unreadableOpenedFile: .unreadableOpenedFile
        case .traceRunsWithoutFolder: .traceRunsWithoutFolder
        case .readyDesignsWithoutFolder: .readyDesignsWithoutFolder
        case .seedUnwritable: .seedUnwritable
        case .unsafeFolder: .unsafeFolder
        }
    }

    private static func sample(of kind: FixtureFailureKind) -> LaunchFixtures.Failure {
        switch kind {
        case .conflictingStorage: .conflictingStorage
        case .missingValue: .missingValue(argument: "-PrestoCVNextSeed")
        case .invalidFolderName: .invalidFolderName
        case .unreadableSeed: .unreadableSeed
        case .unreadableDistribution: .unreadableDistribution
        case .unreadableTips: .unreadableTips
        case .seedWithoutFolder: .seedWithoutFolder
        case .unreadableLegacySeed: .unreadableLegacySeed
        case .legacySeedWithoutFolder: .legacySeedWithoutFolder
        case .samplesWithoutFolder: .samplesWithoutFolder
        case .failuresWithoutFolder: .failuresWithoutFolder
        case .unreadableOtherWindow: .unreadableOtherWindow
        case .otherWindowWithoutFolder: .otherWindowWithoutFolder
        case .unreadableFailWrites: .unreadableFailWrites
        case .failWritesWithoutFolder: .failWritesWithoutFolder
        case .unreadableAutosavePause: .unreadableAutosavePause
        case .unreadableOpenedFile: .unreadableOpenedFile
        case .traceRunsWithoutFolder: .traceRunsWithoutFolder
        case .readyDesignsWithoutFolder: .readyDesignsWithoutFolder
        case .seedUnwritable: .seedUnwritable
        case .unsafeFolder: .unsafeFolder
        }
    }
    #endif
}
