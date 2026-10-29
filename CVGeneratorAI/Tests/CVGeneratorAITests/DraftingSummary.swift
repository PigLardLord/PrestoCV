import Foundation
import CVGeneratorAI

// What the drafting evaluation (#202) says of a whole run set. Pure, like `DraftingMeasure`: `DraftingSummaryTests` builds sets by hand.
//
// What it says first is the hard findings: a field the counter proves invented, a run that gave no usable draft (it threw, the model
// refused, or the claim check gave no answer), an example that lost its name, its title or every job, a tool of another trade written
// around the facts. No hard finding is not GO: the thresholds of what the draft writes around the facts (ADR 0031, `WrittenCounts`)
// must be met, and the fields and drafts in review.json are only queued for a person, and `Readiness` asks for their adjudication.

// MARK: - Percentile

enum Percentile {
    /// The value below which `fraction` of `values` lie, by linear interpolation between the two nearest ranks, so that the median of
    /// 1, 2, 3, 4 is 2.5 and the 95th percentile of a few runs is not just their maximum.
    static func of(_ fraction: Double, in values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let rank = min(max(fraction, 0), 1) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - Double(lower))
    }
}

// MARK: - Counts

/// The counts of a set of runs: one input's, one language's, or every run's.
struct DraftCounts: Codable, Equatable {
    let runs: Int
    let kept: Int
    let lost: Int
    let invented: Int
    let toReview: Int
    /// Runs whose claim check gave no answer.
    let unchecked: Int
    /// Runs that threw, a refusal included.
    let errors: Int
    let refusals: Int
    /// Runs that gave no usable draft: they threw, the model refused, or the claim check gave no answer.
    let failed: Int
    /// The fields the counter calls invented in the model's own drafts, before the rules and the check.
    let rawInvented: Int
    /// The drafts the model wrote, an input's identical drafts counted once. Under greedy sampling every run of an input repeats the
    /// first, so this is the size of the sample, not the number of runs.
    let distinctRaw: Int
    /// The drafts the app would show, an input's identical drafts counted once.
    let distinctFinal: Int

    init(_ measured: [DraftMeasure]) {
        runs = measured.count
        kept = measured.map(\.report.kept.count).reduce(0, +)
        lost = measured.map(\.report.lost.count).reduce(0, +)
        invented = measured.map(\.report.invented.count).reduce(0, +)
        toReview = measured.map(\.report.toReview.count).reduce(0, +)
        unchecked = measured.filter(\.unchecked).count
        errors = measured.filter { $0.error != nil }.count
        refusals = measured.filter(\.refused).count
        failed = measured.filter { $0.failure != nil }.count
        rawInvented = measured.map(\.rawInvented.count).reduce(0, +)
        let byInput = Dictionary(grouping: measured, by: \.id).values
        distinctRaw = byInput.map { Self.distinct($0.compactMap(\.raw)) }.reduce(0, +)
        distinctFinal = byInput.map { Self.distinct($0.compactMap(\.final)) }.reduce(0, +)
    }

    private static func distinct(_ drafts: [CVData]) -> Int {
        var seen: [CVData] = []
        for draft in drafts where !seen.contains(draft) {
            seen.append(draft)
        }
        return seen.count
    }
}

// MARK: - Summary

/// What a complete run set found.
struct DraftSummary: Codable, Equatable {
    let revision: String
    let system: String
    let xcode: String
    let runsPerInput: Int
    let inputs: [String]
    /// Whether the set drafts fewer inputs than the evaluation has: a partial set is never GO.
    let partial: Bool
    /// What the copy of the app's language detector says of each input.
    let detectedLanguages: [String: String]
    let medianSeconds: Double
    let p95Seconds: Double
    let maxSeconds: Double
    let maxLoad: Double?
    let total: DraftCounts
    let perLanguage: [String: DraftCounts]
    let perInput: [String: DraftCounts]
    /// "<id> run <n>: <path> \"<value>\" (<reason>)" for every invented field of a final draft.
    let invented: [String]
    /// "<id> run <n>: <why>" for every run of any input that threw, was refused or had no answer from the check.
    let failures: [String]
    /// "<id> run <n>: <reason>" for every run of an example that misses the name, the title or a job.
    let exampleMisses: [String]
    /// "<id> run <n>: <fact>" for every expected fact a final draft lost.
    let lost: [String]
    /// "<id> run <n>: <hit>" for every tool of another trade a final draft writes, and anything written around no role.
    let offField: [String]
    /// What the distinct final drafts write around the facts.
    let written: WrittenCounts
    /// "<id> run <n>: <class> <path> \"<value>\"" for every value of a final draft in a reader's class: numbers to follow, not findings.
    let readerClasses: [String]
    /// The thresholds of #354 the set misses: not hard findings, and no GO while any is left.
    let shortfalls: [String]
    /// The fields and the drafts a person reads once for this set (review.json).
    let reviewItems: Int

    /// - Throws: `DraftingError.incompleteSet` when `measured` is not exactly the runs the manifest announces, at its revision: a
    ///   summary of a part of the set, or of runs of two revisions, would say nothing of either.
    init(manifest: RunManifest, detectedLanguages: [String: String], measured: [DraftMeasure]) throws {
        let problems = manifest.problems(in: measured)
        guard problems.isEmpty else { throw DraftingError.incompleteSet(problems) }
        revision = manifest.revision
        system = manifest.system
        xcode = manifest.xcode
        runsPerInput = manifest.runsPerInput
        inputs = manifest.inputs
        partial = manifest.partial
        self.detectedLanguages = detectedLanguages
        let times = measured.map(\.seconds)
        medianSeconds = Percentile.of(0.5, in: times)
        p95Seconds = Percentile.of(0.95, in: times)
        maxSeconds = times.max() ?? 0
        maxLoad = measured.compactMap(\.load).max()
        total = DraftCounts(measured)
        perLanguage = Dictionary(grouping: measured, by: \.language).mapValues(DraftCounts.init)
        perInput = Dictionary(grouping: measured, by: \.id).mapValues(DraftCounts.init)
        invented = measured.flatMap { draft in
            draft.report.invented.map { "\(draft.id) run \(draft.run): \($0.path) \"\($0.value)\" (\($0.reason))" }
        }
        failures = measured.compactMap { draft in draft.failure.map { "\(draft.id) run \(draft.run): \($0)" } }
        exampleMisses = measured.flatMap { draft in draft.misses.map { "\(draft.id) run \(draft.run): \($0)" } }
        lost = measured.flatMap { draft in draft.report.lost.map { "\(draft.id) run \(draft.run): \($0)" } }
        offField = measured.flatMap { draft in (draft.written?.offField ?? []).map { "\(draft.id) run \(draft.run): \($0)" } }
        written = WrittenCounts(measured)
        readerClasses = measured.flatMap { draft in
            (draft.written?.readerFindings ?? []).map { "\(draft.id) run \(draft.run): \($0.kind.rawValue) \($0.path) \"\($0.value)\"" }
        }
        shortfalls = written.shortfalls(p95Seconds: p95Seconds)
        reviewItems = ReviewItem.unique(in: measured).count
    }

    /// What fails the evaluation by itself: an invented field, a failed run of any input, a missed example, an off-field hit.
    var hardFindings: Int { invented.count + failures.count + exampleMisses.count + offField.count }

    /// The first line of summary.txt: the hard findings, or their absence with what is still open.
    var headline: String {
        let set = "\(total.runs) runs of \(inputs.count) inputs"
        guard hardFindings == 0 else {
            return "HARD FINDINGS in \(set): \(invented.count) invented, \(failures.count) failed runs, "
                + "\(exampleMisses.count) example misses, \(offField.count) off-field hits"
        }
        var open: [String] = []
        if shortfalls.count == 1 { open.append("1 threshold is missed") }
        if shortfalls.count > 1 { open.append("\(shortfalls.count) thresholds are missed") }
        if reviewItems == 1 { open.append("1 review item needs an adjudication") }
        if reviewItems > 1 { open.append("\(reviewItems) review items need an adjudication") }
        if revision == "unknown" || revision.isEmpty { open.append("the revision under test is not recorded") }
        if partial { open.append("the set is partial") }
        guard !open.isEmpty else {
            return "NO HARD FINDING in \(set). Nothing is left to adjudicate; GO is the verdict of the readiness check"
        }
        return "NO HARD FINDING in \(set). This is not GO: " + open.joined(separator: "; ")
    }

    /// The text of summary.txt: the headline, how big the sample is, the times, then each hard finding.
    var text: String {
        var lines = [headline]
        lines.append("revision \(revision); \(system); Xcode \(xcode)")
        lines.append("inputs: \(inputs.joined(separator: ", "))" + (partial ? " (a partial set)" : ""))
        lines.append(
            "runs: \(total.runs) (\(runsPerInput) per input); distinct drafts: \(total.distinctFinal) final, \(total.distinctRaw) of the model"
        )
        if total.distinctFinal < total.runs {
            lines.append(
                "The runs of an input repeat each other (greedy sampling): the sample is \(total.distinctFinal) drafts, not \(total.runs). "
                    + "The counts are over runs; the times stay valid."
            )
        }
        lines.append(
            "seconds: median \(Self.fixed(medianSeconds)), p95 \(Self.fixed(p95Seconds)), max \(Self.fixed(maxSeconds)); "
                + "max load \(maxLoad.map(Self.fixed) ?? "unknown")"
        )
        lines.append(
            "invented \(total.invented); failed runs \(total.failed) (threw \(total.errors), refused \(total.refusals), "
                + "check gave no answer \(total.unchecked)); example misses \(exampleMisses.count); "
                + "facts lost \(total.lost); to review \(reviewItems) items"
        )
        lines.append(
            "written around the facts: a summary in \(written.withSummary) of \(written.drafts) distinct drafts "
                + "(examples \(written.examplesWithSummary) of \(written.exampleDrafts)); a description on \(written.describedJobs) of "
                + "\(written.keptJobs) kept jobs; enough tools of the trade and soft skills in \(written.withSkills) of \(written.drafts); "
                + "\(written.otherLanguage) of \(written.sentences) sentences in another language; off-field hits \(offField.count)"
        )
        lines.append(written.reader.line)
        lines += invented.map { "invented: \($0)" }
        lines += failures.map { "failed: \($0)" }
        lines += exampleMisses.map { "example miss: \($0)" }
        lines += offField.map { "off-field: \($0)" }
        lines += shortfalls.map { "missed: \($0)" }
        lines += readerClasses.map { "reader class: \($0)" }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func fixed(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
