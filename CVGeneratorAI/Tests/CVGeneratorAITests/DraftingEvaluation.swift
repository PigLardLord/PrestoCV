#if canImport(FoundationModels)
import Testing
import Foundation
import FoundationModels
@testable import CVGeneratorAI

// The whole drafting path on the real on-device model (#202): the model writes a draft of each input of `DraftingInputs`, the rules
// of ADR 0023 ground it, the claim check of ADR 0028 judges its personal items, and `InventedFacts` counts what the result keeps,
// loses and invents. The use case is built as the app builds it (`ViewModelFactory.makeCVGeneratorUseCase`), with the copy of the
// app's language detector, the device lexical tagger and the input's language as the fallback.
//
// It runs only when PRESTOCV_DRAFT_EVAL is on (anything but empty, 0, false, no or off), on an Apple host with Apple Intelligence.
// Everything it records and every rule that reads it is plain code in `DraftingMeasure`, `DraftingSummary`, `DraftingReview` and
// `DraftingRunFolder`, tested everywhere; this file only runs the model.
//
// - PRESTOCV_DRAFT_EVAL_RUNS: the runs of every input, 3 by default. The model runs with greedy sampling, so the runs of an input
//   repeat each other: summary.txt says how many distinct drafts the set holds. They are still worth their times.
// - PRESTOCV_DRAFT_EVAL_OUT: the folder of this run set. It must be absent or empty: a second invocation never adds to the files of
//   the first. Without it, a new folder in the temporary one, named after the revision and the time.
// - PRESTOCV_DRAFT_EVAL_REV: the revision under test, copied into the manifest, every run record and the summary.
// - PRESTOCV_DRAFT_EVAL_ONLY: comma-separated input ids, for a re-run after a fix. The set is then partial, and never GO.
//
// The folder holds manifest.json (written first, updated after every run), one JSON per input and run, summary.json, summary.txt
// (its first line is the verdict) and review.json (the fields, and the drafts written around the facts, a person reads once per set).
// A set that stopped halfway has no summary.
//
// A pass here means NO HARD FINDING, not GO: no field the counter proves invented in any run, no run of any input that threw, was
// refused or whose claim check gave no answer, an example that keeps its name, its title and a job, and no tool of another trade
// written around the facts (ADR 0031). The thresholds of what the drafts write around the facts (`WrittenCounts`), the fields the
// counter can only send to review and the pertinence of each draft need a recorded reading (adjudication.json) before the set is GO:
// see `DraftingReadiness`.

private let environment = ProcessInfo.processInfo.environment

@Suite(
    "Drafting evaluation: ADR 0023, 0028 and 0031 on the real model (a pass is no hard finding, not GO)", .serialized,
    .enabled(if: DraftingSettings.isOn(environment["PRESTOCV_DRAFT_EVAL"]))
)
@MainActor
struct DraftingEvaluation {
    @Test("Every input, drafted PRESTOCV_DRAFT_EVAL_RUNS times: no hard finding (not GO: the review items need a reading)")
    func drafts() async throws {
        let settings = try DraftingSettings(environment: environment)
        let all = try DraftingInputs.all()
        let inputs = try settings.inputs(from: all)
        try #require(FoundationModelsService().availability() == .available, "the on-device model is not available on this host")

        let folder = settings.folder(now: Date(), temporary: URL(fileURLWithPath: NSTemporaryDirectory()))
        try RunFolder.prepare(folder)
        var manifest = RunManifest(
            revision: settings.revision, system: Self.system,
            xcode: XcodeVersion.describe(developerDirectory: XcodeVersion.developerDirectory(environment: environment)),
            started: Date(), runsPerInput: settings.runs, inputs: inputs.map(\.id), allInputs: all.map(\.id)
        )
        try RunFolder.write(manifest, to: "manifest.json", in: folder)

        var measured: [DraftMeasure] = []
        for run in 1...settings.runs {
            for input in inputs {
                let draft = try await Self.draft(input, run: run, revision: settings.revision)
                try RunFolder.write(draft, to: "\(input.id)-run\(run).json", in: folder)
                measured.append(draft)
                manifest = manifest.completed(runs: measured.count)
                try RunFolder.write(manifest, to: "manifest.json", in: folder)
            }
        }

        let detected = Dictionary(uniqueKeysWithValues: inputs.map {
            ($0.id, AppLanguageDetector.languageTag(of: $0.description) ?? "none")
        })
        let summary = try DraftSummary(manifest: manifest, detectedLanguages: detected, measured: measured)
        try RunFolder.write(summary, to: "summary.json", in: folder)
        try RunFolder.writeText(summary.text, to: "summary.txt", in: folder)
        try RunFolder.write(ReviewItem.unique(in: measured), to: "review.json", in: folder)
        print("drafting evaluation: \(folder.path)\n\(summary.text)")

        #expect(summary.invented.isEmpty, "invented: \(summary.invented)")
        #expect(summary.failures.isEmpty, "failed runs: \(summary.failures)")
        #expect(summary.exampleMisses.isEmpty, "example misses: \(summary.exampleMisses)")
        #expect(summary.offField.isEmpty, "off-field hits: \(summary.offField)")
    }

    // MARK: - One draft

    /// The use case of the app on one input, with the model's draft and the calls of the claim check recorded on the way.
    /// - Throws: `CancellationError` when the task was cancelled: the use case turns a cancelled claim check into an unchecked draft,
    ///   which would otherwise be recorded as a failure of the model.
    private static func draft(_ input: DraftingInput, run: Int, revision: String) async throws -> DraftMeasure {
        let service = RecordingService()
        let log = CheckLog()
        let sanitizer = CVDataSanitizer(
            languageOfText: { AppLanguageDetector.languageTag(of: $0) }, lexicalClasses: DeviceLexicalTagger()
        )
        let checker = CheckRecorder(wrapped: FoundationModelsClaimChecker(), log: log)
        let useCase = CVGeneratorUseCase(service: service, claimChecker: checker, sanitizer: sanitizer)
        let load = loadAverage()
        let start = ContinuousClock.now
        let result: GeneratedDraft?
        let failure: (any Error)?
        do {
            let request = CVGenerationRequest(userPrompt: input.description, fallbackLanguageCode: input.language)
            result = try await useCase.generateCV(from: request)
            failure = nil
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            result = nil
            failure = error
        }
        let seconds = seconds(since: start)
        try Task.checkCancellation()
        // The rules again on the model's draft, outside the timed path: they are deterministic, so this is the draft the check saw.
        let grounded = service.raw.flatMap { try? sanitizer.sanitize($0, against: input.description) }
        let checks = await log.events
        return DraftMeasure(
            input: input, run: run, revision: revision, seconds: seconds, load: load, raw: service.raw, grounded: grounded,
            result: result, error: failure, checks: checks
        )
    }

    private static var system: String {
        #if os(macOS)
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        return "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let (whole, attoseconds) = (ContinuousClock.now - start).components
        return Double(whole) + Double(attoseconds) / 1e18
    }

    /// The load average of the last minute, so that a slow draft on a busy host shows as such.
    private static func loadAverage() -> Double? {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) > 0 ? loads[0] : nil
    }

    // MARK: - What is recorded

    /// The model of the app, keeping the draft it wrote before the rules and the check.
    @MainActor
    final class RecordingService: CVGenerationService {
        private let model = FoundationModelsService()
        private(set) var raw: CVData?

        func availability() -> AIAvailability { model.availability() }

        func generateCV(from request: CVGenerationRequest) async throws -> CVData {
            let draft = try await model.generateCV(from: request)
            raw = draft
            return draft
        }
    }
}
#endif
