import DiagnosticLogging
import DiagnosticTrace
import Foundation

// MARK: - What the AI draft records in the trace of a test build (ADR 0032)

/// The run of one AI draft in the trace: the description, whether the model could run, its language data, what each stage gave
/// or removed, what the sections wrote around the facts, the claim check's verdicts, the time of each stage and the draft the
/// person sees. Unlike `DraftLog`, it holds the text, so it goes only to the trace, which a closed gate drops whole in an App Store
/// build. The model service and the claim checker add the requests and the raw answers to the same run (`CVPrompt.traceFields`,
/// `SectionCallTrace`).
struct DraftTrace {
    private let run: any TraceRunRecording

    init(tracer: any DiagnosticTracer) {
        run = tracer.begin(.aiDraft)
    }

    /// Runs the draft so that what the model service and the logger record by kind goes to this run.
    func within<T>(isolation: isolated (any Actor)? = #isolation, _ work: () async throws -> T) async rethrows -> T {
        try await run.within(isolation: isolation, work)
    }

    /// The step that records what a stage gave. A switch over every stage, so that a new one cannot be added without its step.
    static func step(for stage: DraftLog.Stage) -> TraceStepName {
        switch stage {
        case .model, .writing: .response
        case .grounding, .claimCheck, .result: .removal
        }
    }

    /// The description the person typed, as the use case received it.
    func input(_ request: CVGenerationRequest) {
        guard run.isRecording else { return }
        run.record(
            .input, .token("source", "description"), .count("characters", request.userPrompt.count), .text("description", request.userPrompt),
            .token("fallbackLanguage", request.fallbackLanguageCode ?? "none")
        )
    }

    func availability(_ availability: AIAvailability) {
        guard run.isRecording else { return }
        switch availability {
        case .available:
            run.record(.availability, .flag("available", true))
        case .unavailable(let reason):
            run.record(.availability, .flag("available", false), .token("reason", "\(reason.logName)"))
        }
    }

    /// The language of the description, and whether grounding it needs the device's data and finds it.
    func languageData(_ check: LanguageCheck) {
        guard run.isRecording else { return }
        run.record(
            .languageData, .flag("supported", check.language != nil), .token("language", check.language.map { "\($0.logName)" } ?? "none"),
            .token("data", "\(check.data.logName)")
        )
    }

    /// What a stage gave: the model's draft whole, and for every later stage what it removed, changed, added or reordered.
    /// - Parameter before: The draft the stage started from; nil for the model, which starts from the description.
    func stage(_ stage: DraftLog.Stage, gave after: CVData, from before: CVData?) {
        // The difference and the JSON are the costly part of a draft's trace: a run that records nothing builds neither
        guard run.isRecording else { return }
        var fields: [TraceField] = [.token("stage", "\(stage.logName)")]
        if let before {
            let difference = DraftDifference(from: before, to: after)
            fields += [
                .count("removals", difference.removed.count), .count("changes", difference.changed.count),
                .count("additions", difference.added.count),
            ]
            fields += difference.removed.map { TraceField.text("removed", "\($0.path): \(Self.shown($0.before))") }
            fields += difference.changed.map { TraceField.text("changed", "\($0.path): \(Self.shown($0.before)) → \(Self.shown($0.after))") }
            fields += difference.added.map { TraceField.text("added", "\($0.path): \(Self.shown($0.after))") }
            fields += difference.reordered.map { TraceField.text("order", $0) }
        } else {
            fields.append(.text("cv", Self.json(after)))
        }
        run.record(Self.step(for: stage), fields)
    }

    /// What the requests of the sections wrote around the facts and their checks kept, before the final check reads it: the summary,
    /// the duties of each job and the skills. Nothing was written when the description left nothing to write around.
    func written(_ writing: DraftWriting?) {
        guard run.isRecording else { return }
        var fields: [TraceField] = [.token("stage", "\(DraftLog.Stage.writing.logName)"), .flag("wrote", writing != nil)]
        if let writing {
            fields += [
                .count("roles", writing.roleDescriptions.count { $0?.presentValue != nil }),
                .count("technologies", writing.technologies.count), .count("softSkills", writing.softSkills.count),
            ]
            if let summary = writing.summary?.presentValue { fields.append(.text("summary", summary)) }
            for (number, duties) in writing.roleDescriptions.enumerated() {
                if let duties = duties?.presentValue { fields.append(.text("duties", "role \(number): \(duties)")) }
            }
            fields += writing.technologies.map { TraceField.text("technology", $0) }
            fields += writing.softSkills.map { TraceField.text("softSkill", $0) }
        }
        run.record(Self.step(for: .writing), fields)
    }

    /// What the claim check said of each personal item, and why it gave no answer when it did not.
    func claims(_ report: ClaimCheckReport) {
        guard run.isRecording else { return }
        var fields: [TraceField] = [
            .token("stage", "\(DraftLog.Stage.claimCheck.logName)"), .count("candidates", report.candidates.count),
            .flag("answered", report.failure == nil),
        ]
        if let failure = report.failure {
            fields += [.token("cause", failure.code), .text("causeText", failure.text)]
        }
        fields += zip(report.candidates, report.judgements).map { candidate, judgement in
            TraceField.text("verdict", "\(candidate.kind.rawValue): \(candidate.value) → \(judgement.stance.rawValue) \"\(judgement.quote)\"")
        }
        run.record(.check, fields)
    }

    /// A draft asked for while the model cannot run.
    func unavailable(_ reason: AIAvailability.Reason) {
        guard run.isRecording else { return }
        run.record(.failure, .token("check", "availability"), .token("error", "unavailable"), .token("reason", "\(reason.logName)"))
        run.finish(.failed(code: "unavailable"))
    }

    /// A description refused before the model was asked: it broke a rule of the request, or the device lacks the language data
    /// that grounding it needs.
    func rejected(check: DraftLog.Check, by error: any Error) {
        guard run.isRecording else { return }
        run.record(.failure, [.token("check", "\(check.logName)")] + Self.fields(of: error))
        run.finish(.failed(code: Self.code(of: error)))
    }

    /// A draft that came to its end: the time of each stage, and the draft the person sees.
    func finished(_ draft: GeneratedDraft, timing: DraftTiming) {
        guard run.isRecording else { return }
        timing.record(into: run)
        run.record(.finalDraft, .text("draft", Self.json(draft)), .flag("personalItemsUnchecked", draft.personalItemsUnchecked))
        run.finish(.finished)
    }

    /// A draft that stopped at a stage: why, and the time of each stage up to it.
    func stopped(at stage: DraftLog.Stage, by error: any Error, timing: DraftTiming) {
        guard run.isRecording else { return }
        if error is CancellationError {
            run.record(.failure, .token("stage", "\(stage.logName)"), .token("error", "cancelled"))
            timing.record(into: run)
            run.finish(.cancelled)
        } else {
            run.record(.failure, [.token("stage", "\(stage.logName)")] + Self.fields(of: error))
            timing.record(into: run)
            run.finish(.failed(code: Self.code(of: error)))
        }
    }

    // MARK: Values

    /// The error's code, and its own words when it has no code.
    private static func fields(of error: any Error) -> [TraceField] {
        guard error is LoggableError else {
            return [.token("error", code(of: error)), .text("description", String(describing: error))]
        }
        return [.token("error", code(of: error))]
    }

    private static func code(of error: any Error) -> String {
        (error as? LoggableError).map { "\($0.logCode)" } ?? String(describing: type(of: error))
    }

    private static func shown(_ value: String?) -> String {
        guard let value else { return "nil" }
        return value.isEmpty ? "\"\"" : value
    }

    /// A draft as compact JSON with sorted keys, so that two runs diff line by line once pretty-printed by a script.
    static func json(_ cvData: CVData) -> String {
        encoded(cvData)
    }

    static func json(_ draft: GeneratedDraft) -> String {
        encoded(TracedDraft(cvData: draft.cvData, personalItemsUnchecked: draft.personalItemsUnchecked))
    }

    private static func encoded(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            return "unencodable: \(type(of: value))"
        }
    }

    private struct TracedDraft: Encodable {
        let cvData: CVData
        let personalItemsUnchecked: Bool
    }
}

/// The time of each stage of a draft, on the use case's clock: read at the start and at the end of each stage, so that the
/// time of the whole draft is the last reading.
struct DraftTiming {
    private let stopwatch: Stopwatch
    private var laps: [(stage: DraftLog.Stage, time: Duration)] = []
    /// The time since the start, at the last reading.
    private(set) var elapsed: Duration = .zero

    init(clock: any Clock<Duration>) {
        stopwatch = Stopwatch(started: clock)
    }

    /// Ends a stage. A stage that runs twice, as grounding does, keeps one time: the sum of both.
    mutating func lap(_ stage: DraftLog.Stage) {
        let now = stopwatch.elapsed
        if let index = laps.firstIndex(where: { $0.stage == stage }) {
            laps[index].time += now - elapsed
        } else {
            laps.append((stage, now - elapsed))
        }
        elapsed = now
    }

    /// Reads the time of a draft that stopped within a stage.
    mutating func stop() -> Duration {
        elapsed = stopwatch.elapsed
        return elapsed
    }

    func record(into run: any TraceRunRecording) {
        run.record(.timing, laps.map { TraceField.duration($0.stage.logName, $0.time) } + [TraceField.duration("elapsed", elapsed)])
    }
}

// MARK: - The requests to the model

extension CVPrompt {
    /// What the model service asks the model for a draft, for the trace: the instructions, the prompt and how it is asked.
    var traceFields: [TraceField] {
        [
            .token("call", "draft"), .flag("schemaInPrompt", true), .token("sampling", "greedy"),
            .text("instructions", instructions ?? ""), .text("prompt", text),
        ]
    }
}

/// One request of a section of the draft (ADR 0031, "A request per section") in the trace: a `request` step with the instructions and
/// the prompt, and a `response` step with the raw answer, or with why there was none. Both name the call, so that the steps of a
/// draft's many requests read apart; the first pass and the claim check name theirs `draft` and `claimCheck`.
struct SectionCallTrace: Equatable {
    /// The request: `job`, `jobRepair`, `tools`, `softSkills`, `moreSkills`, `summarySentence` or `summarySentenceRepair`.
    let call: String
    /// The number in the brief of the job a job request writes for.
    let role: Int?
    /// The most tokens the answer may take.
    let tokens: Int

    func request(_ prompt: SectionPrompts.Prompt) -> [TraceField] {
        named + [
            .count("maximumTokens", tokens), .flag("schemaInPrompt", true), .token("sampling", "greedy"),
            .text("instructions", prompt.instructions), .text("prompt", prompt.text),
        ]
    }

    /// The raw answer; `complete` says whether a streamed answer ended on its own and not cut, and is nil for an answer that is not streamed.
    func answered(raw: String, complete: Bool?) -> [TraceField] {
        named + [.flag("answered", true)] + (complete.map { [TraceField.flag("complete", $0)] } ?? []) + [.text("raw", raw)]
    }

    /// A stream that ended with no answer at all.
    func unanswered() -> [TraceField] {
        named + [.flag("answered", false), .token("error", "noAnswer")]
    }

    /// A request that failed: the error the use case sees, and the framework's own words.
    func failed(error code: String, framework: String) -> [TraceField] {
        named + [.flag("answered", false), .token("error", code), .text("framework", framework)]
    }

    private var named: [TraceField] {
        [TraceField.token("call", call)] + (role.map { [TraceField.count("role", $0)] } ?? [])
    }
}
