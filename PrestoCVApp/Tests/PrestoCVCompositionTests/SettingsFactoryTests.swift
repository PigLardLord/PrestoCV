import DiagnosticLogging
import DiagnosticTrace
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

    @Test("The tip jar asks the tips the launch made")
    func tipJarFromTheLaunch() async {
        let factory = SettingsFactory(facts: CompositionTests.settings, trace: TraceDiagnosticsTests.closedTrace(), tips: NoTips())
        let tips = factory.makeTips()
        #expect(tips.state == .loading)
        await tips.load()
        #expect(tips.state == .unavailable(.notAllowed))
    }

    @Test("Settings shows the facts the launch read")
    func settingsFromTheFacts() throws {
        let settings = SettingsFactory(facts: CompositionTests.settings, trace: TraceDiagnosticsTests.closedTrace(), tips: NoTips()).makeSettings()

        #expect(settings.supportAddress == "help@example.org")
        #expect(settings.appName == "PrestoCV")
        #expect(settings.groups.map(\.kind) == [.support, .tips, .legal, .openSource, .about])
        let source = try #require(URL(string: "https://example.org/source"))
        #expect(settings.groups[3].rows == [.openSourceStatement, .licences, .sourceCode(source)])
        #expect(settings.groups[4].rows == [.version("1.0"), .build("1")])
    }

    @Test("Licences reads the notices the launch hands over, through the file adapter")
    func licencesFromTheNotices() async {
        let facts = SettingsFactory.Facts(
            supportAddress: "help@example.org", privacyPolicy: nil, sourceCode: nil, version: "1.0", build: "1",
            appName: "PrestoCV", notices: { Self.notices }
        )
        let licences = SettingsFactory(facts: facts, trace: TraceDiagnosticsTests.closedTrace(), tips: NoTips()).makeLicences()

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
        let factory = SettingsFactory(facts: CompositionTests.settings, trace: access, tips: NoTips())
        let settings = factory.makeSettings()
        let diagnostics = factory.makeDiagnostics()

        await settings.appear()
        await diagnostics.load()

        #expect(settings.groups.last?.kind == .diagnostics)
        #expect(diagnostics.rows.map(\.started) == [started])
        #expect(diagnostics.summary == "S")
    }

    @Test("Two Diagnostics screens, one in each window, over the composition's trace: neither removes the files the other offers")
    func diagnosticsScreensKeepTheirOwnCopies() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SettingsFactoryTests-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: base.appendingPathComponent("Root", isDirectory: true), temporary: base)
        defer { try? FileManager.default.removeItem(at: base) }
        await InventedTraceRuns.store(into: paths)
        let device = TraceDevice(appVersion: "1.0", build: "1", osVersion: "iOS 26.5", model: "iPhone17,1")
        let chain = TraceChain(
            directory: paths.trace, shareDirectory: paths.traceShare, gate: .debug, device: device, log: SilentLogger(), after: nil
        )
        await chain.settle()
        let factory = SettingsFactory(facts: CompositionTests.settings, trace: chain.access, tips: NoTips())
        let window = factory.makeDiagnostics()
        let otherWindow = factory.makeDiagnostics()
        func offered(_ files: [URL]) -> Bool { !files.isEmpty && files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) } }

        await window.load()
        await otherWindow.load()
        let files = window.shareFiles
        #expect(window.selection == InventedTraceRuns.draftID)
        #expect(offered(files))

        await otherWindow.select(InventedTraceRuns.importID)
        #expect(offered(files), "Another window's choice leaves these files")
        #expect(offered(otherWindow.shareFiles))
        await otherWindow.finish()
        #expect(offered(files), "Another window's close leaves these files")

        await window.finish()
        #expect(!files.contains { FileManager.default.fileExists(atPath: $0.path) })
    }
}
