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
    /// Each call that reached the port, its CV and its language recorded together under one lock: a test that sees a
    /// call sees all of it.
    private let received = Mutex<[(snapshot: CV, language: DocumentLanguage)]>([])
    /// How many calls were cancelled while they ran.
    let cancellations = Mutex(0)
    let result = Mutex<Result<ExportOutcome, any Error>>(.success(ExportingFake.onePage))

    static let onePage = ExportOutcome(pdf: Data([1, 2, 3]), pageCount: 1, requiredPages: 1)
    static let onePageDocument = ExportedDocument(pdf: Data([1, 2, 3]), pages: 1)

    func returns(_ outcome: Result<ExportOutcome, any Error>) { result.withLock { $0 = outcome } }

    /// How many calls reached the port. A call is counted once its cancellation handler is in place, so a test that
    /// waits for the count and then cancels sees the cancellation recorded.
    var calls: Int { received.withLock { $0.count } }
    var snapshots: [CV] { received.withLock { $0.map(\.snapshot) } }
    var languages: [DocumentLanguage] { received.withLock { $0.map(\.language) } }

    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome {
        await withTaskCancellationHandler {
            received.withLock { $0.append((snapshot, language)) }
            await gate.pass()
        } onCancel: {
            cancellations.withLock { $0 += 1 }
        }
        return try result.withLock { $0 }.get()
    }
}

/// The file port of the share: it records each file it wrote and each one it removed, holds its writes at a gate the
/// test closes, and fails the next writes when the test says so. Its files are not on disk: a URL only names one,
/// `/shared/<id>/<name>`.
final class SharedFilesFake: ExportFileSharing {
    struct Failure: Error, Equatable {}

    private struct State {
        var nextID = 1
        /// How many writes reached the port, the failed ones included.
        var asked = 0
        var written: [SharedFile] = []
        var names: [String] = []
        var pdfs: [Data] = []
        var removed: [SharedFile] = []
        var failing = false
    }

    let gate = Gate()
    private let state = Mutex(State())

    /// The next writes fail, until the test says otherwise.
    func fails(_ failing: Bool) { state.withLock { $0.failing = failing } }

    var asked: Int { state.withLock { $0.asked } }
    var written: [SharedFile] { state.withLock { $0.written } }
    var names: [String] { state.withLock { $0.names } }
    var pdfs: [Data] { state.withLock { $0.pdfs } }
    var removed: [SharedFile] { state.withLock { $0.removed } }
    /// The files written and not removed yet.
    var left: [SharedFile] { state.withLock { state in state.written.filter { !state.removed.contains($0) } } }

    func write(_ pdf: Data, named fileName: String) async throws -> SharedFile {
        state.withLock { $0.asked += 1 }
        await gate.pass()
        return try state.withLock { state in
            guard !state.failing else { throw Failure() }
            let id = state.nextID
            state.nextID += 1
            let file = SharedFile(id: id, url: URL(fileURLWithPath: "/shared/\(id)/\(fileName)"))
            state.written.append(file)
            state.names.append(fileName)
            state.pdfs.append(pdf)
            return file
        }
    }

    func remove(_ file: SharedFile) { state.withLock { $0.removed.append(file) } }
}

/// The reader of a CV's language: it gives the language the test set, nil by default, and records the languages it
/// was offered at each reading.
final class LanguageDetectorStub: CVLanguageDetecting {
    private struct State {
        var answer: DocumentLanguage?
        var asked: [[DocumentLanguage]] = []
    }

    private let state = Mutex(State())

    /// The language the next readings give: the one the CV's words tell, or nil when they tell none.
    func answers(_ language: DocumentLanguage?) { state.withLock { $0.answer = language } }

    /// The languages offered at each reading, in order.
    var asked: [[DocumentLanguage]] { state.withLock { $0.asked } }

    func language(of cv: CV, among languages: [DocumentLanguage]) -> DocumentLanguage? {
        state.withLock { state in
            state.asked.append(languages)
            return state.answer
        }
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
    /// The app's language, last of the languages offered: the PDF's when the CV keeps none and its words tell none.
    nonisolated static let appLanguage = language("fr")
    nonisolated static let offered = ["en", "de", "it", "fr"].map { language($0) }

    let exporter = ExportingFake()
    let files = SharedFilesFake()
    let clock = ManualClock()
    /// Reads the language of the CV's words: none until the test says.
    let detector = LanguageDetectorStub()
    /// The CV the editor shows: what the next snapshot holds.
    var cv: CV
    /// How many snapshots the sheet asked for.
    private(set) var snapshotsTaken = 0
    /// Each language the sheet took to the CV.
    private(set) var chosen: [ExportLanguage] = []
    /// Each language the sheet kept in the CV because its words told it.
    private(set) var kept: [ExportLanguage] = []

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
    func sheet(whenChosen: @escaping @MainActor (ExportLanguage) -> Void = { _ in },
               whenRead: @escaping @MainActor () -> Void = {}) -> ExportSheetViewModel {
        ExportSheetViewModel(
            exporter: exporter, files: files,
            snapshot: { self.snapshotsTaken += 1; whenRead(); return ExportSnapshot(cv: self.cv) },
            offeredLanguages: Self.offered, appLanguage: Self.appLanguage,
            fileNamePattern: { Self.patterns[$0.tag] ?? "%@" },
            onLanguageChosen: { self.chosen.append($0); whenChosen($0) },
            languageDetector: detector, onLanguageFound: { self.kept.append($0) },
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
