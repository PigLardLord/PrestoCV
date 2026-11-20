// This file imports nothing of the domain, the application layer or the ports, and not `@testable`: what it uses is what a
// view sees.
import Foundation
import Testing
import PrestoCVPresentation

/// Every public member of the Settings sheet and of the Licences screen, each with its type spelled out. It compiles only
/// while each type is the presentation's own.
@MainActor
func useEveryPublicMember(of settings: SettingsViewModel, licences: LicencesViewModel) async {
    let _: String = settings.appName + settings.supportAddress
    for group in settings.groups as [SettingsGroup] {
        switch group.kind {
        case .support, .legal, .openSource, .about: break
        }
        for row in group.rows as [SettingsRow] {
            switch row {
            case .contactSupport(let link), .privacyPolicy(let link), .sourceCode(let link): let _: URL = link
            case .openSourceStatement, .licences: break
            case .version(let text), .build(let text): let _: String = text
            }
        }
    }
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
            appName: "PrestoCV"
        )
        let licences = LicencesViewModel(reading: NoticesFake([]))

        await useEveryPublicMember(of: settings, licences: licences)

        #expect(licences.state == .failed)
    }
}
