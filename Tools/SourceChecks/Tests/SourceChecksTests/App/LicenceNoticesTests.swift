import Foundation
import Testing

/// The notices file the app bundles for its Licences screen (#504) says what NOTICE and LICENSE say, so that the screen
/// never drifts from the files the repository publishes. The whitespace is compared normalised: the file joins a
/// paragraph's lines, LICENSE wraps and indents them.
@Suite("Licence notices")
struct LicenceNoticesTests {

    private static let path = "PrestoCVNext/Resources/Licences.json"

    private struct NoticesFile: Decodable {
        struct Licence: Decodable { let id: String, text: String }
        struct Notice: Decodable { let licence: String, thirdParty: Bool, text: String }
        let licences: [Licence]
        let notices: [Notice]
    }

    private static func file() throws -> NoticesFile {
        try #require(try Repository.trackedFiles().contains(path), "\(path) is not tracked")
        return try JSONDecoder().decode(NoticesFile.self, from: Data(try Repository.text(path).utf8))
    }

    private static func normalised(_ text: some StringProtocol) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("The app's own notice is the attribution of NOTICE, word for word")
    func ownNoticeIsTheAttribution() throws {
        let attribution = try Repository.text("NOTICE").split(separator: "\n", omittingEmptySubsequences: false)
            .drop { !$0.hasPrefix("    This product includes PrestoCV") }
            .prefix { $0.hasPrefix("    ") }
        let own = try Self.file().notices.filter { !$0.thirdParty }

        #expect(!attribution.isEmpty, "NOTICE has no attribution indented by four spaces")
        #expect(own.map { Self.normalised($0.text) } == [Self.normalised(attribution.joined(separator: " "))])
    }

    @Test("The bundled Apache License is LICENSE, word for word")
    func apacheTextIsLicense() throws {
        let apache = try Self.file().licences.filter { $0.id == "Apache-2.0" }

        #expect(apache.map { Self.normalised($0.text) } == [Self.normalised(try Repository.text("LICENSE"))])
    }

    @Test("Every notice names a licence the file holds, and the file holds each licence once")
    func everyNoticeNamesAHeldLicence() throws {
        let file = try Self.file()
        let held = file.licences.map(\.id)

        #expect(Set(held).count == held.count, "a licence is in the file twice: \(held)")
        #expect(file.notices.filter { !held.contains($0.licence) }.map(\.licence) == [])
        #expect(!file.notices.isEmpty)
    }
}
