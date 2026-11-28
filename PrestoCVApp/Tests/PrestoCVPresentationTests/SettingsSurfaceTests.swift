// This file imports nothing of the domain, the application layer or the ports, and not `@testable`: what it uses is what a
// view sees.
import Foundation
import Testing
import PrestoCVPresentation

/// Every public member of the Settings sheet and of the Licences screen, each with its type spelled out. It compiles only
/// while each type is the presentation's own.
@MainActor
func useEveryPublicMember(of settings: SettingsViewModel, licences: LicencesViewModel, diagnostics: DiagnosticsViewModel, tips: TipJarViewModel) async {
    await settings.appear()
    let _: String = settings.appName + settings.supportAddress
    for group in settings.groups as [SettingsGroup] {
        switch group.kind {
        case .support, .tips, .legal, .openSource, .about, .diagnostics: break
        }
        for row in group.rows as [SettingsRow] {
            switch row {
            case .contactSupport(let link), .privacyPolicy(let link), .sourceCode(let link): let _: URL = link
            case .openSourceStatement, .licences, .tips, .diagnostics: break
            case .version(let text), .build(let text): let _: String = text
            }
        }
    }
    await tips.load()
    await tips.retry()
    switch tips.state as TipJarState {
    case .loading: break
    case .offers(let rows):
        for row in rows as [TipRow] {
            let _: String = row.price
            switch row.size as TipRow.Size {
            case .small, .medium, .large: let _: TipRow.Size = row.id
            }
        }
    case .unavailable(let reason):
        switch reason as TipUnavailability {
        case .notAllowed, .unreachable, .noOffers, .failed: break
        }
    }
    await tips.buy(.small, in: { .unknown })?.value
    switch tips.attempt as TipAttempt {
    case .idle, .thanked, .pending, .failed, .unreachable: break
    case .buying(let size): let _: TipRow.Size = size
    }
    await diagnostics.load()
    switch diagnostics.state as DiagnosticsState {
    case .loading, .empty, .listed: break
    }
    for row in diagnostics.rows as [DiagnosticsRow] {
        let _: UUID = row.id
        let _: Date = row.started
        switch row.kind as DiagnosticsRow.Kind {
        case .aiDraft, .textImport: break
        }
        switch row.outcome as DiagnosticsRow.Outcome {
        case .finished, .failed, .cancelled, .unfinished: break
        }
        await diagnostics.select(row.id)
    }
    let chosen: UUID? = diagnostics.selection
    let _: String = diagnostics.summary
    let _: [URL] = diagnostics.shareFiles
    await diagnostics.finish()
    _ = chosen
    await licences.load()
    switch licences.state as LicencesState {
    case .loading, .loaded, .failed: break
    }
    let others: LicencesOthers? = licences.othersState
    switch others {
    case .noOthers, nil: break
    }
    for row in licences.rows as [LicenceRow] {
        let _: String = row.id + row.title + row.licenceName
        let detail: LicenceDetail? = licences.detail(of: row.id)
        let _: String? = detail?.title
        let _: [String]? = detail.map { $0.noticeParagraphs + $0.licenceParagraphs }
    }
}

@MainActor
@Suite("Settings public surface")
struct SettingsSurfaceTests {

    @Test("The Settings and Licences API holds no domain or port type: this file uses all of it importing only the presentation")
    func noDomainTypeInTheSettingsAPI() async throws {
        let settings = SettingsViewModel(
            supportAddress: "help@example.org", privacyPolicy: try #require(URL(string: "https://example.org/privacy.html")),
            sourceCode: try #require(URL(string: "https://example.org/source.html")), version: "1.1", build: "140",
            appName: "PrestoCV", diagnostics: DiagnosticsFake()
        )
        let licences = LicencesViewModel(reading: NoticesFake([]))

        await useEveryPublicMember(
            of: settings, licences: licences, diagnostics: DiagnosticsViewModel(reading: DiagnosticsFake(runs: [.run(1, at: 0)])),
            tips: TipJarViewModel(selling: StubTips(canPay: true, result: .success([])))
        )

        #expect(licences.state == .failed)
    }
}
