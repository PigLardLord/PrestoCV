#if DEBUG
import DiagnosticLogging
import DiagnosticTrace
import DiagnosticTraceFiles
import Foundation

/// The two runs `-PrestoCVNextTraceRuns` stores: an AI draft that finished (the newer) and an import that failed, a minute
/// apart. The content is invented, so that a UI test reads a list and a summary without any real person's text.
enum InventedTraceRuns {
    static let draftID = UUID(uuid: (0x0A, 0x0A, 0x0A, 0x0A, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1))
    static let importID = UUID(uuid: (0x0B, 0x0B, 0x0B, 0x0B, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 2))

    static var runs: [TraceRun] {
        let build = TraceBuild(
            appVersion: "1.0", build: "1", distribution: "sandbox", osVersion: "iOS 26.5", deviceModel: "iPhone0,0"
        )
        let draft = TraceRun(
            id: draftID, kind: .aiDraft, started: Date(timeIntervalSince1970: 1_768_467_660), build: build,
            steps: [
                TraceStep(sequence: 1, elapsed: .zero, name: .input, fields: [.text("description", "Invented baker with five years of experience")]),
                TraceStep(sequence: 2, elapsed: .seconds(2), name: .finalDraft, fields: [.text("summary", "Invented baker, five years at a bakery")])
            ],
            outcome: .finished
        )
        let failedImport = TraceRun(
            id: importID, kind: .textImport, started: Date(timeIntervalSince1970: 1_768_467_600), build: build,
            steps: [
                TraceStep(sequence: 1, elapsed: .zero, name: .input, fields: [.text("text", "Invented pasted text of a CV")]),
                TraceStep(sequence: 2, elapsed: .seconds(1), name: .failure, fields: [.text("error", "Invented failure")])
            ],
            outcome: .failed(code: "invented")
        )
        return [draft, failedImport]
    }

    /// Writes the runs into the trace folders of the paths and waits until they are on disk.
    static func store(into paths: AppPaths) async {
        let store = TraceFileStore(directory: paths.trace, shareDirectory: paths.traceShare, logger: SilentLogger())
        for run in runs { store.save(run) }
        await store.flush()
    }
}
#endif
