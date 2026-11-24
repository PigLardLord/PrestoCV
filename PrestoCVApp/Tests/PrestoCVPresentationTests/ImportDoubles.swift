import Foundation
import Synchronization
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

// #333: `ImportCV.importText` is synchronous, so the real port may do its work on the actor that awaits it. These fakes
// cannot show a thread; the view model awaits the port, and keeping the main actor free is the port's job.

/// The answer of a fake asked for more than its script holds.
struct NotScripted: Error {}

/// An error that is no import failure.
struct Unexpected: Error {}

/// The import port, scripted: each call takes the answer of its turn (the last answer stands for the later turns), and
/// waits at a gate a test can close. A call answers even when it was cancelled, as a late result does.
final class ImportingFake: CVImporting {
    let gate = Gate()
    let texts = Mutex<[String]>([])
    let pdfs = Mutex<[Data]>([])
    let cancellations = Mutex(0)
    private let answers: Mutex<[Result<ImportOutcome, any Error>]>
    private let turns = Mutex(0)

    init(_ answers: [Result<ImportOutcome, any Error>]) { self.answers = Mutex(answers) }

    var calls: Int { turns.withLock { $0 } }

    func importCV(fromText text: String) async throws -> ImportOutcome {
        texts.withLock { $0.append(text) }
        return try await answer()
    }

    func importCV(fromPDF data: Data) async throws -> ImportOutcome {
        pdfs.withLock { $0.append(data) }
        return try await answer()
    }

    private func answer() async throws -> ImportOutcome {
        let turn = turns.withLock { turns in
            turns += 1
            return turns - 1
        }
        await withTaskCancellationHandler { await gate.pass() } onCancel: { cancellations.withLock { $0 += 1 } }
        return try answers.withLock { $0.isEmpty ? .failure(NotScripted()) : $0[min(turn, $0.count - 1)] }.get()
    }
}

/// What happened to a file handed to the screen, in order.
enum FileEvent: Equatable, Sendable {
    case read(URL)
    case released(URL)
}

/// What the fake saw of one received file, by its id.
struct ReceivedRecord: Sendable {
    let file: ReceivedFile
    var reads = 0
    var readEnded = 0
    var releases = 0
    /// What was wrong when it was released or read, in words.
    var violations: [String] = []
}

/// The file port, scripted: every read gives the same answer after a gate a test can close. The hooks run on the main
/// actor inside a read (before its gate) and inside a release, as the caller's code can, and the release ends after its
/// hook. It records each received file
/// by its id, and what it saw go wrong: a release while the file's read runs, a read after the release.
final class FileReadingFake: ImportFileReading {
    let gate = Gate()
    let events = Mutex<[FileEvent]>([])
    let records = Mutex<[Int: ReceivedRecord]>([:])
    let whenRead = Mutex<(@MainActor @Sendable (URL) -> Void)?>(nil)
    let whenReleased = Mutex<(@MainActor @Sendable (URL) -> Void)?>(nil)
    private let answer: Mutex<Result<Data, any Error>>
    private let issued = Mutex(0)

    init(_ answer: Result<Data, any Error>) { self.answer = Mutex(answer) }

    var recorded: [FileEvent] { events.withLock { $0 } }
    var reads: Int { recorded.filter { if case .read = $0 { true } else { false } }.count }
    var received: [ReceivedRecord] { records.withLock { $0.values.sorted { $0.file.id < $1.file.id } } }

    func released(_ url: URL) -> Int { recorded.filter { $0 == .released(url) }.count }

    /// Everything wrong the fake saw, over all files: a file not released exactly once is reported when `ended` is true.
    func problems(ended: Bool) -> [String] {
        received.flatMap { record -> [String] in
            var found = record.violations.map { "file \(record.file.id): \($0)" }
            if ended && record.releases != 1 { found.append("file \(record.file.id): released \(record.releases) times") }
            return found
        }
    }

    func receive(_ url: URL) async -> ReceivedFile {
        let file = ReceivedFile(id: issued.withLock { $0 += 1; return $0 }, url: url)
        records.withLock { $0[file.id] = ReceivedRecord(file: file) }
        return file
    }

    func readPDF(of file: ReceivedFile) async throws -> Data {
        events.withLock { $0.append(.read(file.url)) }
        records.withLock {
            $0[file.id]?.reads += 1
            if $0[file.id]?.releases ?? 0 > 0 { $0[file.id]?.violations.append("read after its release") }
        }
        defer { records.withLock { $0[file.id]?.readEnded += 1 } }
        if let hook = whenRead.withLock({ $0 }) { await hook(file.url) }
        await gate.pass()
        return try answer.withLock { $0 }.get()
    }

    func release(_ file: ReceivedFile) async {
        events.withLock { $0.append(.released(file.url)) }
        records.withLock {
            guard var record = $0[file.id] else { return }
            record.releases += 1
            if record.reads > record.readEnded { record.violations.append("released while its read runs") }
            $0[file.id] = record
        }
        if let hook = whenReleased.withLock({ $0 }) { await hook(file.url) }
    }
}

/// Invented values for imports: no real person, file or CV.
enum ImportValues {
    static let pdf = Data("%PDF-1.7 invented".utf8)
    static let file = URL(fileURLWithPath: "/invented/cvs/cv.pdf")
    static let otherFile = URL(fileURLWithPath: "/invented/cvs/other.pdf")

    static func cv(_ name: String) -> CV {
        CV(id: CVID(UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!), title: "",
           personal: PersonalDetails(fullName: name), design: nil, language: nil)
    }

    static func outcome(name: String = "Ada Ferro", review: [ImportReviewItem] = [], saving: SaveVerdict = .ok,
                        notImported: String = "") -> ImportOutcome {
        ImportOutcome(cv: cv(name), review: review, saving: saving, notImported: notImported)
    }

    /// Every field the import can name, with entry numbers that differ from field to field. Built with a switch that
    /// names every case, so that a new field breaks the build here.
    static let everyField: [ImportReviewField] = {
        let all: [ImportReviewField] = [.name, .title, .location, .summary, .experience(1), .experiencePeriod(2),
                                        .education(3), .educationPeriod(4), .educationLocation(5), .language(6),
                                        .languageNotKept(7), .certificationYear(8)]
        for field in all {
            switch field {
            case .name, .title, .location, .summary, .experience, .experiencePeriod, .education, .educationPeriod,
                 .educationLocation, .language, .languageNotKept, .certificationYear:
                break
            }
        }
        return all
    }()

    /// Every reason an import gives no CV. Built with a switch that names every case.
    static let everyFailure: [ImportFailure] = {
        let all: [ImportFailure] = [.empty, .tooLarge, .tooManyPages, .encrypted, .unreadable, .noText, .fileNotRead]
        for failure in all {
            switch failure {
            case .empty, .tooLarge, .tooManyPages, .encrypted, .unreadable, .noText, .fileNotRead: break
            }
        }
        return all
    }()
}

/// The import screen on its fakes.
@MainActor
final class ImportWorld {
    let importer: ImportingFake
    let files: FileReadingFake

    init(answers: [Result<ImportOutcome, any Error>] = [.success(ImportValues.outcome())],
         file: Result<Data, any Error> = .success(ImportValues.pdf)) {
        importer = ImportingFake(answers)
        files = FileReadingFake(file)
    }

    func model() -> ImportViewModel { ImportViewModel(importer: importer, files: files) }

    /// Closes both gates and waits until a call of `model` waits at one of them.
    func hold(_ model: ImportViewModel, _ start: (ImportViewModel) -> Void) async {
        await importer.gate.close()
        await files.gate.close()
        start(model)
        await waitUntil("a call at a gate") {
            await self.importer.gate.waiting + self.files.gate.waiting > 0
        }
    }
}

/// The import screen a hook of a fake reaches, and what the hook saw of it.
@MainActor
final class ModelBox {
    var model: ImportViewModel?
    var seen: [ImportStatus] = []
}
