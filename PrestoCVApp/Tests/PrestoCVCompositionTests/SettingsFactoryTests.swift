import Foundation
import PrestoCVPresentation
import Testing
@testable import PrestoCVComposition

/// The factory of the Settings sheet's view models: what the launch read about the app reaches the sheet, and the
/// Licences screen reads the notices through the file adapter.
@MainActor
@Suite("The settings factory")
struct SettingsFactoryTests {
    nonisolated private static let notices = Data("""
    {"licences": [{"id": "Apache-2.0", "name": "Apache License 2.0", "text": "The licence."}],
     "notices": [{"id": "prestocv", "title": "PrestoCV", "licence": "Apache-2.0", "thirdParty": false,
                  "text": "The notice."}]}
    """.utf8)

    @Test("Settings shows the facts the launch read")
    func settingsFromTheFacts() throws {
        let settings = SettingsFactory(facts: CompositionTests.settings).makeSettings()

        #expect(settings.supportAddress == "help@example.org")
        #expect(settings.appName == "PrestoCV")
        #expect(settings.groups.map(\.kind) == [.support, .legal, .openSource, .about])
        let source = try #require(URL(string: "https://example.org/source"))
        #expect(settings.groups[2].rows == [.openSourceStatement, .licences, .sourceCode(source)])
        #expect(settings.groups[3].rows == [.version("1.0"), .build("1")])
    }

    @Test("Licences reads the notices the launch hands over, through the file adapter")
    func licencesFromTheNotices() async {
        let facts = SettingsFactory.Facts(
            supportAddress: "help@example.org", privacyPolicy: nil, sourceCode: nil, version: "1.0", build: "1",
            appName: "PrestoCV", notices: { Self.notices }
        )
        let licences = SettingsFactory(facts: facts).makeLicences()

        await licences.load()

        #expect(licences.state == .loaded)
        #expect(licences.rows.map(\.title) == ["PrestoCV"])
        #expect(licences.othersState == .noOthers)
    }
}
