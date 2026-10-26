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
// It runs only when PRESTOCV_DRAFT_EVAL is set, on an Apple host with Apple Intelligence, and writes what it measured as JSON to the
// folder PRESTOCV_DRAFT_EVAL_OUT: one file per input and run with the model's draft, the grounded draft, the final draft and the
// class of every field; `summary.json` with the counts; `review.json` with the fields a person reads once per run set.
//
// - PRESTOCV_DRAFT_EVAL_RUNS: the runs of every input, 3 by default.
// - PRESTOCV_DRAFT_EVAL_REV: the revision under test, copied into the summary.
// - PRESTOCV_DRAFT_EVAL_ONLY: comma-separated input ids, for a re-run after a fix.
//
// The verdict: no invented field in any run, and every run of an example keeps the name, the title and at least one employer. A run
// that threw or whose check gave no answer keeps nothing, so on an example it is a miss of its own.

private let environment = ProcessInfo.processInfo.environment
private let evaluation = environment["PRESTOCV_DRAFT_EVAL"] ?? ""
private let outputFolder = URL(fileURLWithPath: environment["PRESTOCV_DRAFT_EVAL_OUT"] ?? NSTemporaryDirectory())
private let runs = environment["PRESTOCV_DRAFT_EVAL_RUNS"].flatMap(Int.init) ?? 3
private let revisionUnderTest = environment["PRESTOCV_DRAFT_EVAL_REV"] ?? "unknown"
private let only = Set((environment["PRESTOCV_DRAFT_EVAL_ONLY"] ?? "").split(separator: ",").map {
    $0.trimmingCharacters(in: .whitespaces)
}.filter { !$0.isEmpty })

@Suite("Drafting evaluation: ADR 0023 and 0028 on the real model", .serialized, .enabled(if: !evaluation.isEmpty))
@MainActor
struct DraftingEvaluation {
    @Test("Every input, drafted PRESTOCV_DRAFT_EVAL_RUNS times: nothing invented, each example keeps its name, title and a job")
    func drafts() async throws {
        let all = try DraftingInputs.all()
        let unknown = only.subtracting(all.map(\.id))
        try #require(unknown.isEmpty, "PRESTOCV_DRAFT_EVAL_ONLY names inputs that do not exist: \(unknown.sorted())")
        let inputs = all.filter { only.isEmpty || only.contains($0.id) }
        try #require(runs > 0)
        try #require(FoundationModelsService().availability() == .available, "the on-device model is not available on this host")

        var measured: [Measured] = []
        for run in 1...runs {
            for input in inputs {
                let draft = await Self.draft(input, run: run)
                try write(draft, to: "\(input.id)-run\(run).json")
                measured.append(draft)
            }
        }
        let summary = Summary(inputs: inputs, measured: measured)
        try write(summary, to: "summary.json")
        try write(ReviewItem.unique(in: measured), to: "review.json")

        #expect(summary.invented.isEmpty, "invented: \(summary.invented)")
        #expect(summary.exampleMisses.isEmpty, "example misses: \(summary.exampleMisses)")
    }

    // MARK: - One draft

    /// The use case of the app on one input, with the model's draft recorded on the way.
    private static func draft(_ input: DraftingInput, run: Int) async -> Measured {
        let service = RecordingService()
        let sanitizer = CVDataSanitizer(
            languageOfText: { AppLanguageDetector.languageTag(of: $0) }, lexicalClasses: DeviceLexicalTagger()
        )
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FoundationModelsClaimChecker(), sanitizer: sanitizer)
        let load = loadAverage()
        let start = ContinuousClock.now
        let result: GeneratedDraft?
        let failure: (any Error)?
        do {
            let request = CVGenerationRequest(userPrompt: input.description, fallbackLanguageCode: input.language)
            result = try await useCase.generateCV(from: request)
            failure = nil
        } catch {
            result = nil
            failure = error
        }
        let seconds = seconds(since: start)
        // The rules again on the model's draft, outside the timed path: they are deterministic, so this is the draft the check saw.
        let grounded = service.raw.flatMap { try? sanitizer.sanitize($0, against: input.description) }
        return Measured(
            input: input, run: run, seconds: seconds, load: load, raw: service.raw, grounded: grounded, result: result, error: failure
        )
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

    private func write(_ value: some Encodable, to name: String) throws {
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: outputFolder.appendingPathComponent(name))
    }

    // MARK: - What is measured

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

    /// One input drafted once: the three drafts, and the counts of the final one.
    struct Measured: Encodable {
        let id: String
        let language: String
        let kind: DraftingInput.Kind
        let run: Int
        let seconds: Double
        let load: Double?
        /// The model's draft, before the rules.
        let raw: CVData?
        /// The model's draft after the rules of ADR 0023, before the claim check.
        let grounded: CVData?
        /// What the use case returns, and the app shows.
        let final: CVData?
        /// Whether the claim check gave no answer, so that every personal item was withdrawn.
        let unchecked: Bool
        let error: String?
        /// Whether the model's guardrail refused the description.
        let refused: Bool
        /// The classes of every field of the final draft, and the expected facts it keeps and loses. A run that threw has no field
        /// and loses every fact.
        let report: InventedFacts.Report
        /// The fields of the model's draft that the counter calls invented: what the rules and the check had to remove.
        let rawInvented: [InventedFacts.Finding]
        /// Why an example's run misses the name, the title or a job; empty for the other inputs.
        let misses: [String]

        init(
            input: DraftingInput, run: Int, seconds: Double, load: Double?, raw: CVData?, grounded: CVData?, result: GeneratedDraft?,
            error: (any Error)?
        ) {
            id = input.id
            language = input.language
            kind = input.kind
            self.run = run
            self.seconds = seconds
            self.load = load
            self.raw = raw
            self.grounded = grounded
            final = result?.cvData
            unchecked = result?.personalItemsUnchecked ?? false
            self.error = error.map { String(describing: $0) }
            refused = error.map(Self.isGuardrailRefusal) ?? false
            report = InventedFacts.count(result?.cvData ?? CVData(), for: input)
            rawInvented = raw.map { InventedFacts.count($0, for: input).invented } ?? []

            var misses: [String] = []
            if input.kind == .example {
                if let error { misses.append("threw \(error)") }
                if unchecked { misses.append("the check gave no answer") }
                if !report.keeps(.name) { misses.append("lost the name") }
                if !report.keeps(.title) { misses.append("lost the title") }
                if !report.keeps(.employer) { misses.append("kept no job") }
            }
            self.misses = misses
        }

        /// Whether `error` is the model's guardrail refusing the description. macOS 27 throws `LanguageModelError`; its older
        /// `LanguageModelSession.GenerationError` is what earlier systems throw.
        private static func isGuardrailRefusal(_ error: any Error) -> Bool {
            if #available(macOS 27.0, iOS 27.0, *), let modelError = error as? LanguageModelError, case .guardrailViolation = modelError {
                return true
            }
            if let generationError = error as? LanguageModelSession.GenerationError, case .guardrailViolation = generationError {
                return true
            }
            return false
        }
    }

    /// The counts of a set of runs: the input's, the language's, or every run's.
    struct Counts: Encodable {
        let runs: Int
        let kept: Int
        let lost: Int
        let invented: Int
        let toReview: Int
        let unchecked: Int
        let errors: Int
        let refusals: Int
        /// The fields the counter calls invented in the model's own drafts, before the rules and the check.
        let rawInvented: Int

        init(_ measured: [Measured]) {
            runs = measured.count
            kept = measured.map(\.report.kept.count).reduce(0, +)
            lost = measured.map(\.report.lost.count).reduce(0, +)
            invented = measured.map(\.report.invented.count).reduce(0, +)
            toReview = measured.map(\.report.toReview.count).reduce(0, +)
            unchecked = measured.filter(\.unchecked).count
            errors = measured.filter { $0.error != nil }.count
            refusals = measured.filter(\.refused).count
            rawInvented = measured.map(\.rawInvented.count).reduce(0, +)
        }
    }

    struct Summary: Encodable {
        let revision: String
        let system: String
        let xcode: String
        let runsPerInput: Int
        let inputs: [String]
        /// What the copy of the app's language detector says of each input.
        let detectedLanguages: [String: String]
        let medianSeconds: Double
        let p95Seconds: Double
        let maxSeconds: Double
        let maxLoad: Double?
        let total: Counts
        let perLanguage: [String: Counts]
        let perInput: [String: Counts]
        /// "<id> run <n>: <path> \"<value>\" (<reason>)" for every invented field of a final draft.
        let invented: [String]
        /// "<id> run <n>: <reason>" for every run of an example that misses the name, the title or a job.
        let exampleMisses: [String]
        /// "<id> run <n>: <fact>" for every expected fact a final draft lost.
        let lost: [String]

        init(inputs: [DraftingInput], measured: [Measured]) {
            revision = revisionUnderTest
            system = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
            xcode = Self.xcodeVersion()
            runsPerInput = runs
            self.inputs = inputs.map(\.id)
            detectedLanguages = Dictionary(uniqueKeysWithValues: inputs.map {
                ($0.id, AppLanguageDetector.languageTag(of: $0.description) ?? "none")
            })
            let times = measured.map(\.seconds).sorted()
            medianSeconds = times.isEmpty ? 0 : times[times.count / 2]
            p95Seconds = times.isEmpty ? 0 : times[min(times.count - 1, Int(Double(times.count) * 0.95))]
            maxSeconds = times.last ?? 0
            maxLoad = measured.compactMap(\.load).max()
            total = Counts(measured)
            perLanguage = Dictionary(grouping: measured, by: \.language).mapValues(Counts.init)
            perInput = Dictionary(grouping: measured, by: \.id).mapValues(Counts.init)
            invented = measured.flatMap { draft in
                draft.report.invented.map { "\(draft.id) run \(draft.run): \($0.path) \"\($0.value)\" (\($0.reason))" }
            }
            exampleMisses = measured.flatMap { draft in draft.misses.map { "\(draft.id) run \(draft.run): \($0)" } }
            lost = measured.flatMap { draft in draft.report.lost.map { "\(draft.id) run \(draft.run): \($0)" } }
        }

        /// The version and build of the Xcode the run uses, from DEVELOPER_DIR.
        private static func xcodeVersion() -> String {
            let developer = URL(fileURLWithPath: environment["DEVELOPER_DIR"] ?? "/Applications/Xcode.app/Contents/Developer")
            let contents = developer.deletingLastPathComponent()
            func value(_ key: String, in file: String) -> String? {
                let plist = NSDictionary(contentsOf: contents.appendingPathComponent(file))
                return plist?[key] as? String
            }
            let version = value("CFBundleShortVersionString", in: "Info.plist") ?? "unknown"
            let build = value("ProductBuildVersion", in: "version.plist") ?? "unknown"
            return "\(version) (\(build)) at \(contents.deletingLastPathComponent().path)"
        }
    }

    /// A field a person reads once per run set: the same value of the same input is listed once, with the runs that wrote it.
    struct ReviewItem: Encodable {
        let id: String
        let value: String
        let reason: String
        let context: String?
        /// "run <n>: <path>" for every run and field that holds the value.
        let seen: [String]

        static func unique(in measured: [Measured]) -> [ReviewItem] {
            var order: [String] = []
            var items: [String: (finding: InventedFacts.Finding, id: String, seen: [String])] = [:]
            for draft in measured {
                for finding in draft.report.toReview {
                    let key = [draft.id, finding.value, finding.reason, finding.context ?? ""].joined(separator: "\u{1F}")
                    if items[key] == nil {
                        order.append(key)
                        items[key] = (finding, draft.id, [])
                    }
                    items[key]?.seen.append("run \(draft.run): \(finding.path)")
                }
            }
            return order.compactMap { key in
                items[key].map { item in
                    ReviewItem(
                        id: item.id, value: item.finding.value, reason: item.finding.reason, context: item.finding.context,
                        seen: item.seen
                    )
                }
            }
        }
    }
}
#endif
