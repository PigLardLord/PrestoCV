import Foundation
import Synchronization
import Testing
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The export port: it records each snapshot and each cancellation, holds its calls at a gate the test opens, and gives
/// the outcome the test set. A call held at the gate returns its outcome when the gate opens, even when cancelled, as a
/// late result does.
final class ExportingFake: CVExporting {
    let gate = Gate()
    let snapshots = Mutex<[CV]>([])
    let languages = Mutex<[DocumentLanguage]>([])
    /// How many calls were cancelled while they ran.
    let cancellations = Mutex(0)
    let result = Mutex<Result<ExportOutcome, any Error>>(.success(ExportingFake.onePage))

    static let onePage = ExportOutcome(pdf: Data([1, 2, 3]), pageCount: 1, requiredPages: 1)
    static let onePageDocument = ExportedDocument(pdf: Data([1, 2, 3]), pages: 1)

    func returns(_ outcome: Result<ExportOutcome, any Error>) { result.withLock { $0 = outcome } }

    var calls: Int { snapshots.withLock { $0.count } }

    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome {
        snapshots.withLock { $0.append(snapshot) }
        languages.withLock { $0.append(language) }
        await withTaskCancellationHandler {
            await gate.pass()
        } onCancel: {
            cancellations.withLock { $0 += 1 }
        }
        return try result.withLock { $0 }.get()
    }
}

/// The export sheet on the gated port and a clock moved by hand, over a CV the test changes between exports, as the
/// editor's form does. The pause is 250 ms, as in version 1.
@MainActor
final class SheetWorld {
    nonisolated static let pause = Duration.milliseconds(250)
    /// The patterns of the PDF's title, as the view gives them (invented words).
    nonisolated static let patterns = ["en": "%@ – CV", "de": "%@ – Lebenslauf", "it": "%@ – Curriculum"]
    nonisolated static let english = language("en")
    /// The app's language, last of the languages offered, so that a test sees it moved first.
    nonisolated static let appLanguage = language("fr")
    nonisolated static let offered = ["en", "de", "it", "fr"].map { language($0) }

    let exporter = ExportingFake()
    let clock = ManualClock()
    /// The CV the editor shows: what the next snapshot holds.
    var cv: CV
    /// How many snapshots the sheet asked for.
    private(set) var snapshotsTaken = 0
    /// Each language the sheet took to the CV.
    private(set) var chosen: [ExportLanguage?] = []

    init() { cv = Self.cv() }

    /// A CV with invented values, by default with a name and in Italian. Every CV of a world has the same identity.
    nonisolated static func cv(fullName: String = "Mara Ellison", email: String? = nil, phone: String? = nil, language: String? = "it",
                   design: String? = nil) -> CV {
        CV(id: CVID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!), title: "Design roles",
           personal: PersonalDetails(fullName: fullName, email: email.flatMap(EmailAddress.init),
                                     phone: phone.flatMap(PhoneNumber.init)),
           design: design.flatMap { DesignChoice(design: $0) }, language: language.flatMap(DocumentLanguage.init))
    }

    /// - Parameters:
    ///   - whenChosen: Runs inside the callback that takes a chosen language to the CV, as a caller's code can.
    ///   - whenRead: Runs inside the snapshot closure, as a caller's code can.
    func sheet(whenChosen: @escaping @MainActor (ExportLanguage?) -> Void = { _ in },
               whenRead: @escaping @MainActor () -> Void = {}) -> ExportSheetViewModel {
        ExportSheetViewModel(
            exporter: exporter,
            snapshot: { self.snapshotsTaken += 1; whenRead(); return ExportSnapshot(cv: self.cv) },
            offeredLanguages: Self.offered, appLanguage: Self.appLanguage,
            fileNamePattern: { Self.patterns[$0.tag] ?? "%@" },
            onLanguageChosen: { self.chosen.append($0); whenChosen($0) },
            clock: self.clock, pause: Self.pause)
    }

    func passThePause() { clock.advance(by: Self.pause) }

    /// Moves the clock past the pause and waits for the export it starts to reach the port.
    func passThePause(thenExports expected: Int) async {
        passThePause()
        await waitUntil("\(expected) exports") { exporter.calls >= expected }
    }

    /// Waits until `expected` exports wait at the closed gate.
    func held(_ expected: Int) async {
        await waitUntil("\(expected) exports held") { await exporter.gate.waiting == expected }
    }

    nonisolated static func language(_ tag: String) -> ExportLanguage {
        guard let language = ExportLanguage(tag) else { preconditionFailure("\(tag) is a language tag") }
        return language
    }
}
