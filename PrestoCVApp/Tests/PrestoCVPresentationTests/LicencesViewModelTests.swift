import Synchronization
import Testing
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

/// A source of notices that gives its answers in turn, one a call.
final class NoticesFake: LicenceNoticesReading {
    struct Unreadable: Error {}
    private let answers: Mutex<[Result<[LicenceNotice], any Error>]>

    init(_ answers: [Result<[LicenceNotice], any Error>]) { self.answers = Mutex(answers) }

    func notices() async throws -> [LicenceNotice] {
        try answers.withLock { $0.isEmpty ? .failure(Unreadable()) : $0.removeFirst() }.get()
    }
}

private let apache = Licence(id: "Apache-2.0", name: "Apache License 2.0", text: "Apache License\nVersion 2.0\n\nTERMS")
private let own = LicenceNotice(id: "prestocv", title: "PrestoCV", isThirdParty: false, text: "This product includes PrestoCV.",
                                licence: apache)
private let font = LicenceNotice(id: "font", title: "Example Sans", isThirdParty: true, text: "Example Sans, by Example.",
                                 licence: Licence(id: "OFL-1.1", name: "SIL Open Font License 1.1", text: "Permission is granted."))

@MainActor
@Suite("Licences")
struct LicencesViewModelTests {

    @Test("LicencesViewModel is loading until it read the notices, then lists each with the name of its licence")
    func listsTheNotices() async {
        let licences = LicencesViewModel(reading: NoticesFake([.success([own, font])]))
        #expect(licences.state == .loading)
        #expect(licences.rows.isEmpty)

        await licences.load()

        #expect(licences.state == .loaded)
        #expect(licences.rows == [LicenceRow(id: "prestocv", title: "PrestoCV", licenceName: "Apache License 2.0"),
                                  LicenceRow(id: "font", title: "Example Sans", licenceName: "SIL Open Font License 1.1")])
        #expect(licences.detail(of: "font")?.licenceParagraphs == ["Permission is granted."])
        #expect(licences.detail(of: "other") == nil)
    }

    @Test("LicencesViewModel splits a text into paragraphs")
    func splitsIntoParagraphs() async {
        let notice = LicenceNotice(id: "prestocv", title: "PrestoCV", isThirdParty: false,
                                   text: "\nFirst line\nsecond line\r\n\n \n\n\tThird\n", licence: apache)
        let licences = LicencesViewModel(reading: NoticesFake([.success([notice])]))

        await licences.load()

        #expect(licences.detail(of: "prestocv") == LicenceDetail(
            title: "PrestoCV", noticeParagraphs: ["First line\nsecond line", "\tThird"],
            licenceParagraphs: ["Apache License\nVersion 2.0", "TERMS"]
        ))
    }

    @Test("LicencesViewModel shows the failed state when the notices cannot be read")
    func failedStateThenRetry() async {
        let licences = LicencesViewModel(reading: NoticesFake([.failure(NoticesFake.Unreadable()), .success([own])]))

        await licences.load()

        #expect(licences.state == .failed)
        #expect(licences.rows.isEmpty)
        #expect(licences.othersState == nil)

        await licences.load()

        #expect(licences.state == .loaded)
        #expect(licences.rows.map(\.id) == ["prestocv"])
    }

    @Test("a cancelled read leaves the screen loading, not failed")
    func cancelledReadIsNoFailure() async {
        let licences = LicencesViewModel(reading: NoticesFake([.failure(CancellationError())]))

        await licences.load()

        #expect(licences.state == .loading)
    }

    @Test("LicencesViewModel shows the footer only when no third-party notice exists")
    func footerOnlyWithoutOthers() async {
        let alone = LicencesViewModel(reading: NoticesFake([.success([own])]))
        let withOthers = LicencesViewModel(reading: NoticesFake([.success([own, font])]))
        #expect(alone.othersState == nil)

        await alone.load()
        await withOthers.load()

        #expect(alone.othersState == .noOthers)
        #expect(withOthers.othersState == nil)
    }
}
