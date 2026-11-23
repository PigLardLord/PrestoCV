import Foundation
import Testing
@testable import PrestoCVPresentation

@MainActor
@Suite("Settings")
struct SettingsViewModelTests {

    private func settings(address: String, version: String = "1.1", build: String = "140") throws -> SettingsViewModel {
        SettingsViewModel(
            supportAddress: address, privacyPolicy: try #require(URL(string: "https://example.org/privacy.html")),
            sourceCode: try #require(URL(string: "https://example.org/source.html")), version: version, build: build,
            appName: "PrestoCV"
        )
    }

    @Test("SettingsViewModel lists the groups in order")
    func groupsInOrder() throws {
        let settings = try settings(address: "help@example.org")

        #expect(settings.groups.map(\.kind) == [.support, .legal, .openSource, .about])
        #expect(settings.groups.map(\.rows) == [
            [.contactSupport(try #require(URL(string: "mailto:help@example.org")))],
            [.privacyPolicy(try #require(URL(string: "https://example.org/privacy.html")))],
            [.openSourceStatement, .licences, .sourceCode(try #require(URL(string: "https://example.org/source.html")))],
            [.version("1.1"), .build("140")],
        ])
    }

    @Test("SettingsViewModel passes the version and build it was given")
    func versionAndBuildAsGiven() throws {
        let settings = try settings(address: "help@example.org", version: "1.1.2", build: "152.3")

        #expect(settings.groups.last?.rows == [.version("1.1.2"), .build("152.3")])
        #expect(settings.appName == "PrestoCV")
    }

    @Test("the support row is a mail link to the address with nothing attached, and the address shows under it")
    func supportRowIsAMailLink() throws {
        let settings = try settings(address: "help+cv@example.org")

        #expect(settings.groups.first?.rows.map(\.mailLink) == ["mailto:help+cv@example.org"])
        #expect(settings.supportAddress == "help+cv@example.org")
    }

    @Test("an address that makes no mail link leaves the row out and still shows the address")
    func addressWithoutLinkKeepsTheAddress() throws {
        let settings = try settings(address: "//help")

        #expect(settings.groups.first == SettingsGroup(kind: .support, rows: []))
        #expect(settings.supportAddress == "//help")
    }

    @Test("a link the composition could not make leaves its row out, and Legal with it")
    func missingLinksLeaveTheirRowsOut() {
        let settings = SettingsViewModel(
            supportAddress: "help@example.org", privacyPolicy: nil, sourceCode: nil, version: "1.1", build: "140",
            appName: "PrestoCV"
        )

        #expect(settings.groups.map(\.kind) == [.support, .openSource, .about])
        #expect(settings.groups[1].rows == [.openSourceStatement, .licences])
    }
}

private extension SettingsRow {
    /// The link of a support row as text, nil for any other row.
    var mailLink: String? {
        if case .contactSupport(let link) = self { link.absoluteString } else { nil }
    }
}
