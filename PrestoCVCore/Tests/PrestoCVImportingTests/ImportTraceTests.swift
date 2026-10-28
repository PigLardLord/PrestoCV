import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing
@testable import PrestoCVImporting

/// What a text import writes to the trace of a test build (ADR 0032): the text it read, what each section's rule kept and
/// dropped, the time it took and the CV it gave. The trace holds the text of the CV; the log still holds none of it.
@Suite("The trace of a text import")
struct ImportTraceTests {

    private let limits = ImportLimits(
        maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 5_000,
        maximumWords: 1_000, maximumLines: 200, maximumCells: 400, maximumAnalysisSteps: 1_000_000
    )

    private static let step = Duration.milliseconds(7)

    private func importer(tracer: any DiagnosticTracer, logger: RecordingLogger = RecordingLogger(), limits: ImportLimits? = nil) -> ImportCV {
        ImportCV(pdfReader: ScriptedPDFReader(), limits: limits ?? self.limits, logger: logger, clock: TickingClock(step: Self.step), tracer: tracer)
    }

    /// A fictional CV with a marker word, Zorblaxine, that no rule reads as anything but text.
    private static let pastedCV = """
    Curriculum Vitae
    # Giulia Bianchi
    **Infermiera**
    Torino, Italia · giulia.bianchi@example.com

    ## Esperienza
    **Infermiera** | Ospedale Zorblaxine | Torino | 03/2019 – oggi
    - Assistenza ai pazienti

    ## Lingue
    - Inglese: buono

    ## Volontariato
    Croce Rossa, dal 2015
    """

    // MARK: A run that records nothing

    @Test("A run that records nothing is handed no step: the section analysis and the JSON are never built")
    func closedRunBuildsNothing() throws {
        let tracer = RefusingTracer()

        _ = try importer(tracer: tracer).importText(Self.pastedCV)
        #expect(throws: (any Error).self) { try importer(tracer: tracer, limits: ImportLimits(
            maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 5, maximumWords: 1_000, maximumLines: 200, maximumCells: 400,
            maximumAnalysisSteps: 1_000_000
        )).importText(Self.pastedCV) }

        #expect(tracer.calls == 0)
    }

    // MARK: A finished import

    @Test("A pasted text gives its input, a check step per section, the removals, the time and the final draft, in order")
    func steps() throws {
        let tracer = RecordingTracer()
        let result = try importer(tracer: tracer).importText(Self.pastedCV)

        let run = try #require(tracer.run(.textImport))
        #expect(tracer.runs.count == 1)
        #expect(run.outcome == .finished)
        let names = run.steps.map(\.name)
        #expect(names.first == .input)
        #expect(Array(names.suffix(2)) == [.timing, .finalDraft])
        #expect(run.steps(.check).count == 4)
        #expect(run.steps(.removal).count == result.leftOut.count + result.unplaced.count + result.ungrounded.count)
        #expect(run.steps(.input).first?.text("text") == Self.pastedCV)
        #expect(run.steps(.timing).first?.value("elapsed") == .duration(Self.step))
    }

    @Test("Each section names its kind, its heading, its lines, the rule that read it and the values it kept")
    func sections() throws {
        let tracer = RecordingTracer()
        _ = try importer(tracer: tracer).importText(Self.pastedCV)

        let checks = try #require(tracer.run(.textImport)).steps(.check)
        #expect(checks.map { $0.value("section") } == ["header", "experience", "languages", "volunteering"].map { .token($0) })
        let experience = checks[1]
        #expect(experience.text("heading") == "Esperienza")
        #expect(experience.value("reader") == .token("EntryReader.experience"))
        #expect(experience.value("lineCount") == .count(2))
        #expect(experience.text("lines")?.contains("Ospedale Zorblaxine") == true)
        let kept = experience.fields.filter { $0.key == "kept" }.compactMap { field -> String? in
            if case .text(let text) = field.value { return text.text }
            return nil
        }
        #expect(experience.value("values") == .count(kept.count))
        #expect(kept.contains { $0.hasPrefix("experience[0].employer: Ospedale Zorblaxine @") })
        #expect(kept.contains { $0.hasPrefix("experience[0].period: 2019-03 – current @") })
        let header = checks[0]
        #expect(header.value("reader") == .token("HeaderReader"))
        #expect(header.fields.contains { $0.key == "kept" && $0.value == .text(TraceText("person.name: Giulia Bianchi @17-31")) })
        let languages = checks[2]
        #expect(languages.fields.contains { $0.key == "kept" && $0.value == .text(TraceText("languages[0].levelWords: buono @196-201 check=levelNotCEFR")) })
        let volunteering = checks[3]
        #expect(volunteering.value("reader") == .token("none"))
        #expect(volunteering.value("values") == .count(0))
        #expect(volunteering.value("unplaced") == .count(1))
    }

    @Test("What the import dropped is a removal: the noise with its reason, the text no rule placed with its section")
    func removals() throws {
        let tracer = RecordingTracer()
        let result = try importer(tracer: tracer).importText(Self.pastedCV)

        let removals = try #require(tracer.run(.textImport)).steps(.removal)
        let leftOut = removals.filter { $0.value("what") == .token("leftOut") }
        #expect(leftOut.count == result.leftOut.count)
        #expect(leftOut.contains { $0.value("reason") == .token("documentTitle") && $0.text("text") == "Curriculum Vitae" })
        let unplaced = removals.filter { $0.value("what") == .token("unplaced") }
        #expect(unplaced.count == result.unplaced.count)
        #expect(unplaced.contains {
            $0.value("section") == .token("volunteering") && $0.text("heading") == "Volontariato" && $0.text("text") == "Croce Rossa, dal 2015"
        })
    }

    @Test("The final draft is every field of the imported CV, as JSON, with its spans")
    func finalDraft() throws {
        let tracer = RecordingTracer()
        let result = try importer(tracer: tracer).importText(Self.pastedCV)

        let step = try #require(tracer.run(.textImport)?.steps(.finalDraft).first)
        let json = try #require(step.text("cv"))
        let fields = try JSONDecoder().decode([TracedField].self, from: Data(json.utf8))
        #expect(fields.count == result.cv.fields.count)
        #expect(fields.contains { $0.path == "person.name" && $0.value == "Giulia Bianchi" && $0.spans == [[17, 31]] && $0.check == nil })
        #expect(fields.contains { $0.path == "experience[0].period" && $0.value == "2019-03 – current" && $0.reading == "period" })
        #expect(fields.contains { $0.path == "person.email" && $0.value == "giulia.bianchi@example.com" })
        #expect(fields.contains { $0.path == "languages[0].levelWords" && $0.value == "buono" && $0.check == "levelNotCEFR" })
        #expect(step.value("unplaced") == .count(result.unplaced.count))
        #expect(step.value("leftOut") == .count(result.leftOut.count))
    }

    @Test("A word of the CV is in the trace and in no log entry")
    func marker() throws {
        let tracer = RecordingTracer()
        let logger = RecordingLogger()
        _ = try importer(tracer: tracer, logger: logger).importText(Self.pastedCV)

        #expect(try #require(tracer.run(.textImport)).allText.contains("Zorblaxine"))
        #expect(!logger.entries.isEmpty)
        #expect(!"\(logger.entries)".contains("Zorblaxine"))
    }

    // MARK: A failed import

    @Test("A failed import keeps its input and finishes as failed, with the error's code")
    func failed() throws {
        let tracer = RecordingTracer()
        #expect(throws: ImportError.empty) { try importer(tracer: tracer).importText("— 2019 —") }

        let run = try #require(tracer.run(.textImport))
        #expect(run.outcome == .failed(code: "empty"))
        #expect(run.steps.map(\.name) == [.input, .failure, .timing])
        #expect(run.steps(.failure).first?.value("error") == .token("empty"))
    }

    @Test("A reached bound finishes as the error the person is told about, and names the bound")
    func limit() throws {
        let tracer = RecordingTracer()
        let small = ImportLimits(
            maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 10,
            maximumWords: 1_000, maximumLines: 200, maximumCells: 400, maximumAnalysisSteps: 1_000_000
        )
        #expect(throws: ImportError.tooLarge) { try importer(tracer: tracer, limits: small).importText(Self.pastedCV) }

        let run = try #require(tracer.run(.textImport))
        #expect(run.outcome == .failed(code: "tooLarge"))
        let failure = try #require(run.steps(.failure).first)
        #expect(failure.value("error") == .token("tooLarge"))
        #expect(failure.value("limit") == .token("characters"))
    }

    @Test("A cancelled import finishes as cancelled")
    func cancelled() async throws {
        let tracer = RecordingTracer()
        let importer = importer(tracer: tracer)
        let outcome = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Result { try importer.importText(Self.pastedCV) }
        }.value

        #expect(throws: CancellationError.self) { try outcome.get() }
        let run = try #require(tracer.run(.textImport))
        #expect(run.outcome == .cancelled)
        #expect(run.steps.map(\.name) == [.input, .failure, .timing])
        #expect(run.steps(.failure).first?.value("error") == .token("cancelled"))
    }

    @Test("Without a trace, an import records nothing and reads the same")
    func noTracer() throws {
        let traced = try importer(tracer: RecordingTracer()).importText(Self.pastedCV)
        let silent = try ImportCV(pdfReader: ScriptedPDFReader(), limits: limits, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer())
            .importText(Self.pastedCV)
        #expect(traced == silent)
    }
}

/// A field of the final draft's JSON, as a script reads it.
private struct TracedField: Decodable {
    let path: String
    let value: String
    let spans: [[Int]]
    let reading: String?
    let check: String?
}
