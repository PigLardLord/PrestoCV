import Foundation
import DiagnosticTrace
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
        let settings = SettingsFactory(facts: CompositionTests.settings, diagnostics: TraceDiagnosticsTests.reading()).makeSettings()

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
        let licences = SettingsFactory(facts: facts, diagnostics: TraceDiagnosticsTests.reading()).makeLicences()

        await licences.load()

        #expect(licences.state == .loaded)
        #expect(licences.rows.map(\.title) == ["PrestoCV"])
        #expect(licences.othersState == .noOthers)
    }

    @Test("Diagnostics lists the runs the trace stored, and Settings offers the row once the gate is open")
    func diagnosticsFromTheTrace() async {
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        let access = TraceAccess(
            isOn: { true },
            reader: TraceReaderFake(runs: [TraceRunListing(id: UUID(), kind: .aiDraft, started: started, outcome: .finished, summary: "S")])
        )
        let factory = SettingsFactory(facts: CompositionTests.settings, diagnostics: TraceDiagnostics(access: access))
        let settings = factory.makeSettings()
        let diagnostics = factory.makeDiagnostics()

        await settings.appear()
        await diagnostics.load()

        #expect(settings.groups.last?.kind == .diagnostics)
        #expect(diagnostics.rows.map(\.started) == [started])
        #expect(diagnostics.summary == "S")
    }
}
