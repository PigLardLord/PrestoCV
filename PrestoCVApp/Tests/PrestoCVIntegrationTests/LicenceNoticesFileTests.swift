import Foundation
import Testing
import PrestoCVWorkflowPorts
import PrestoCVIntegration

private let apacheLicence = #"{"id": "Apache-2.0", "name": "Apache License 2.0", "text": "Apache License\n\nTERMS"}"#
private let fontLicence = #"{"id": "OFL-1.1", "name": "SIL Open Font License 1.1", "text": "Permission is granted."}"#

/// The notices file as the app bundles it, with the notices given and, unless given, its two licences.
private func file(notices: String, licences: String = apacheLicence + "," + fontLicence) -> Data {
    Data(#"{"licences": [\#(licences)], "notices": [\#(notices)]}"#.utf8)
}

private let own = #"{"id": "prestocv", "title": "PrestoCV", "licence": "Apache-2.0", "thirdParty": false, "text": "Ours."}"#
private let font = #"{"id": "font", "title": "Example Sans", "licence": "OFL-1.1", "thirdParty": true, "text": "Theirs."}"#

private struct Unreadable: Error, Equatable {}

@Suite("The licence notices come from the bundled file")
struct LicenceNoticesFileTests {

    @Test("LicenceNoticesFile gives the notices in the file's order, each with the licence it names")
    func decodesTheNotices() async throws {
        let notices = try await LicenceNoticesFile(contents: { file(notices: own + "," + font) }).notices()

        #expect(notices == [
            LicenceNotice(id: "prestocv", title: "PrestoCV", isThirdParty: false, text: "Ours.",
                          licence: Licence(id: "Apache-2.0", name: "Apache License 2.0", text: "Apache License\n\nTERMS")),
            LicenceNotice(id: "font", title: "Example Sans", isThirdParty: true, text: "Theirs.",
                          licence: Licence(id: "OFL-1.1", name: "SIL Open Font License 1.1", text: "Permission is granted.")),
        ])
    }

    @Test("a notice that names a licence the file lacks fails with the licence's id")
    func unknownLicenceFails() async {
        let notice = #"{"id": "x", "title": "X", "licence": "MIT", "thirdParty": true, "text": "X."}"#

        await #expect(throws: LicenceNoticesFile.Failure.unknownLicence("MIT")) {
            try await LicenceNoticesFile(contents: { file(notices: own + "," + notice) }).notices()
        }
    }

    @Test("two notices with the same id fail with that id")
    func duplicateNoticeFails() async {
        await #expect(throws: LicenceNoticesFile.Failure.duplicateNotice("prestocv")) {
            try await LicenceNoticesFile(contents: { file(notices: own + "," + font + "," + own) }).notices()
        }
    }

    @Test("two licences with the same id fail with that id")
    func duplicateLicenceFails() async {
        await #expect(throws: LicenceNoticesFile.Failure.duplicateLicence("OFL-1.1")) {
            try await LicenceNoticesFile(contents: {
                file(notices: own, licences: apacheLicence + "," + fontLicence + "," + fontLicence)
            }).notices()
        }
    }

    @Test("a file that is not the notices fails as unreadable")
    func undecodableFileFails() async {
        await #expect(throws: LicenceNoticesFile.Failure.unreadable) {
            try await LicenceNoticesFile(contents: { Data(#"{"notices": 1}"#.utf8) }).notices()
        }
    }

    @Test("an error of the read and a cancellation pass through unchanged")
    func readErrorsPassThrough() async {
        await #expect(throws: Unreadable()) {
            try await LicenceNoticesFile(contents: { throw Unreadable() }).notices()
        }
        await #expect(throws: CancellationError.self) {
            try await LicenceNoticesFile(contents: { throw CancellationError() }).notices()
        }
    }
}
