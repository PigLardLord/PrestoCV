import Testing
import Foundation
import CVGeneratorAI

// What the drafting evaluation says of a whole run set. The first things it says are the hard findings, and "no hard finding" never
// reads as GO. Three runs of an input that repeat each other are one draft, and the summary says so.

@Suite("Drafting evaluation: what a run set says")
struct DraftingSummaryTests {
    // MARK: - Percentiles

    @Test("A percentile interpolates between the two nearest ranks", arguments: PercentileCase.all)
    func percentile(_ item: PercentileCase) {
        let value = Percentile.of(item.fraction, in: item.values)

        #expect(abs(value - item.expected) < 0.000_001, "\(item): \(value)")
    }

    // MARK: - Distinct drafts

    @Test("Three identical runs of an input are one draft, not three")
    func identicalRuns() throws {
        let measured = try DraftMeasures.set(["en-plain", "it-plain"], runs: 3)

        let counts = DraftCounts(measured)

        #expect(counts.runs == 6)
        #expect(counts.distinctRaw == 2)
        #expect(counts.distinctFinal == 2)
    }

    @Test("A run that differs from the others of its input is another draft")
    func differentRun() throws {
        let measured = try DraftMeasures.set(["en-plain", "it-plain"], runs: 3, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain", run: 2))

        let counts = DraftCounts(measured)

        #expect(counts.distinctRaw == 3)
        #expect(counts.distinctFinal == 3)
    }

    @Test("A draft that the rules changed counts apart in the final drafts and not in the model's")
    func rulesChangedTheDraft() throws {
        let removed = Tweak(edit: { $0.interests.append("Origami") }, finalEdit: { $0.interests.removeLast() })
        let measured = try DraftMeasures.set(["en-plain"], runs: 2, tweak: DraftMeasures.tweak(removed, for: "en-plain", run: 2))

        let counts = DraftCounts(measured)

        #expect(counts.distinctRaw == 2)
        #expect(counts.distinctFinal == 1)
        #expect(counts.rawInvented == 1)
        #expect(counts.invented == 0)
    }

    // MARK: - The headline

    @Test("A set with no hard finding says that it is not GO, and what is still open")
    func noHardFinding() throws {
        let scenario = try Scenario.make(ids: ["en-plain", "it-plain"], runs: 3, tweak: DraftMeasures.tweak(Scenario.reviewedOnce, for: "en-plain"))
        let summary = scenario.summary

        #expect(summary.hardFindings == 0)
        // The field of en-plain, and the draft of each input, which a person reads for pertinence.
        #expect(summary.headline == "NO HARD FINDING in 6 runs of 2 inputs. This is not GO: 3 review items need an adjudication")
        #expect(summary.text.hasPrefix(summary.headline + "\n"))
    }

    @Test("Several review items are counted in the plural")
    func severalItems() throws {
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain"))

        #expect(scenario.summary.reviewItems == 4)
        #expect(scenario.summary.headline == "NO HARD FINDING in 4 runs of 2 inputs. This is not GO: 4 review items need an adjudication")
    }

    @Test("Several review items, an unknown revision and a partial set are all open")
    func openThings() throws {
        let tweak = DraftMeasures.tweak(Scenario.reviewedOnce, for: "en-plain")
        let scenario = try Scenario.make(ids: ["en-plain", "it-plain"], all: DraftingInputs.all().map(\.id), revision: "unknown", tweak: tweak)

        #expect(scenario.summary.headline.hasSuffix(
            "This is not GO: 3 review items need an adjudication; the revision under test is not recorded; the set is partial"
        ))
    }

    @Test("A complete, reviewed set at a known revision has nothing open, and the line does not say GO by itself")
    func nothingOpen() throws {
        // A description with no role, whose draft writes nothing around the facts: nothing to read.
        let headline = try Scenario.make(ids: ["en-norole"], all: ["en-norole"]).summary.headline

        #expect(headline == "NO HARD FINDING in 1 runs of 1 inputs. Nothing is left to adjudicate; GO is the verdict of the readiness check")
    }

    @Test("A partial set says so in its headline")
    func partialHeadline() throws {
        let scenario = try Scenario.make(ids: ["en-plain"], all: ["en-plain", "it-plain"])

        #expect(scenario.summary.partial)
        #expect(scenario.summary.headline.hasSuffix("the set is partial"))
        #expect(scenario.summary.text.contains("(a partial set)"))
    }

    @Test("An invented field is a hard finding and the first line says so")
    func inventedIsHard() throws {
        let scenario = try Scenario.make(runs: 3, tweak: DraftMeasures.tweak(Scenario.invented, for: "en-plain"))
        let summary = scenario.summary

        #expect(summary.invented.count == 3)
        #expect(summary.hardFindings == 3)
        #expect(summary.headline.hasPrefix("HARD FINDINGS in 6 runs of 2 inputs: 3 invented, 0 failed runs, 0 example misses"))
        #expect(summary.text.contains("invented: en-plain run 2: interests[0] \"Origami\""))
    }

    @Test("A tool of another trade that a draft writes is a hard finding, and the text names it")
    func offFieldHit() throws {
        let java = Tweak(edit: { $0.skills.append(Skill(name: "Java")) })
        let summary = try Scenario.make(tweak: DraftMeasures.tweak(java, for: "en-plain")).summary

        #expect(summary.offField.count == 1)
        #expect(summary.hardFindings == 1)
        #expect(summary.headline == "HARD FINDINGS in 2 runs of 2 inputs: 0 invented, 0 failed runs, 0 example misses, 1 off-field hits")
        #expect(summary.offField.first?.hasPrefix("en-plain run 1: skills[") == true)
        #expect(summary.text.contains(".name \"Java\" (a tool of another trade: Java)"))
    }

    @Test("Whatever a draft writes around a description with no role is an off-field hit")
    func noRoleWritten() throws {
        let summaryOnly = Tweak(edit: { $0.summary = WrittenLayer.texts["en"]?.summary })
        let summary = try Scenario.make(ids: ["en-norole"], tweak: DraftMeasures.tweak(summaryOnly, for: "en-norole")).summary

        #expect(summary.hardFindings == 1)
        #expect(summary.offField.first?.hasPrefix("en-norole run 1: summary \"Reliable and careful") == true)
        #expect(summary.offField.first?.hasSuffix("(written around a description with no role)") == true)
    }

    @Test("A missed threshold is no hard finding and keeps the set from GO")
    func missedThreshold() throws {
        let noSummary = Tweak(edit: { $0.summary = nil })
        let scenario = try Scenario.make(tweak: DraftMeasures.tweak(noSummary, for: "en-plain"))
        let summary = scenario.summary

        #expect(summary.hardFindings == 0)
        #expect(summary.shortfalls == ["a summary in 1 of 2 distinct drafts (90% needed)"])
        #expect(summary.headline.contains("This is not GO: 1 threshold is missed; "))
        #expect(summary.text.contains("missed: a summary in 1 of 2 distinct drafts (90% needed)"))
        #expect(scenario.adjudicated().verdict.reasons == ["a threshold is missed: a summary in 1 of 2 distinct drafts (90% needed)"])
    }

    @Test("The text says what the drafts write around the facts")
    func writtenLine() throws {
        let summary = try Scenario.make(ids: ["example-en", "en-plain", "en-norole"]).summary

        #expect(summary.text.contains(
            "written around the facts: a summary in 2 of 2 distinct drafts (examples 1 of 1); a description on "
                + "\(summary.written.keptJobs) of \(summary.written.keptJobs) kept jobs; enough tools of the trade and soft skills in 2 of 2; "
                + "0 of \(summary.written.sentences) sentences in another language; off-field hits 0"
        ))
        #expect(summary.shortfalls.isEmpty)
    }

    @Test("The text counts the reader's classes and lists each, as numbers to follow, not findings")
    func readerLines() throws {
        let teamwork = Tweak(edit: { $0.skills.append(Skill(name: "Teamwork")) })
        let summary = try Scenario.make(ids: ["en-plain"], tweak: DraftMeasures.tweak(teamwork, for: "en-plain")).summary

        #expect(summary.text.contains(
            "the reader's classes, by rough rules: a soft skill as a technology 1; no tool of the trade 0; two forms in one job 0; "
                + "a skill in another language 0; two technologies of one head noun "
        ))
        #expect(summary.text.contains("reader class: en-plain run 1: softAsTechnology skills["))
        #expect(summary.readerClasses.filter { $0.contains("softAsTechnology") }.count == 1)
    }

    @Test("A draft whose claim check gave no answer fails its input, in all three runs, and the first line says so")
    func uncheckedInputFails() throws {
        let thrown = CheckEvent(candidates: 4, answers: nil, error: "serviceFailed", cancelled: false)
        let unchecked = Tweak(unchecked: true, checks: [thrown])
        let scenario = try Scenario.make(ids: ["pt-plain", "pt-traps"], runs: 3, tweak: DraftMeasures.tweak(unchecked, for: "pt-traps"))
        let summary = scenario.summary

        #expect(summary.total.unchecked == 3)
        #expect(summary.perInput["pt-traps"]?.unchecked == 3)
        #expect(summary.perInput["pt-plain"]?.unchecked == 0)
        #expect(summary.failures.count == 3)
        #expect(summary.hardFindings == 3)
        #expect(summary.headline.hasPrefix("HARD FINDINGS"))
        #expect(summary.text.contains("failed: pt-traps run 1: the claim check gave no answer: a call threw serviceFailed"))
    }

    @Test("A run that threw, or that the model refused, is a failed run of any input", arguments: [
        CVGenerationError.contentNotAllowed, .generationFailed,
    ])
    func failedRuns(_ error: CVGenerationError) throws {
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Tweak(error: error), for: "it-plain", run: 2))
        let summary = scenario.summary

        #expect(summary.failures.count == 1)
        #expect(summary.failures.first?.hasPrefix("it-plain run 2:") == true)
        #expect(summary.total.errors == 1)
        #expect(summary.total.failed == 1)
        #expect(summary.total.refusals == (error == .contentNotAllowed ? 1 : 0))
        #expect(summary.hardFindings == 1)
    }

    @Test("An example that lost its name is a hard finding")
    func exampleMiss() throws {
        let lostName = Tweak(edit: { $0.name = nil })
        let scenario = try Scenario.make(ids: ["example-en", "en-plain"], tweak: DraftMeasures.tweak(lostName, for: "example-en"))

        #expect(scenario.summary.exampleMisses == ["example-en run 1: lost the name"])
        #expect(scenario.summary.hardFindings == 1)
    }

    // MARK: - The sample

    @Test("The summary says that the sample is the distinct drafts, not the runs")
    func sampleLine() throws {
        let summary = try Scenario.make(ids: ["en-plain", "it-plain"], runs: 3).summary

        #expect(summary.text.contains("runs: 6 (3 per input); distinct drafts: 2 final, 2 of the model"))
        #expect(summary.text.contains("the sample is 2 drafts, not 6"))
    }

    @Test("A set whose runs all differ has no sample line")
    func noSampleLine() throws {
        let summary = try Scenario.make(ids: ["en-plain"], runs: 1).summary

        #expect(!summary.text.contains("the sample is"))
    }

    // MARK: - The times

    @Test("The times are the median and the 95th percentile by interpolation, and the maximum")
    func times() throws {
        let scenario = try Scenario.make(ids: ["en-plain"], runs: 4) { _, run in Tweak(seconds: Double(run * 10)) }
        let summary = scenario.summary

        #expect(summary.medianSeconds == 25)
        #expect(abs(summary.p95Seconds - 38.5) < 0.000_001)
        #expect(summary.maxSeconds == 40)
        #expect(summary.text.contains("seconds: median 25.0, p95 38.5, max 40.0; max load unknown"))
    }

    // MARK: - An incomplete set

    @Test("A summary refuses a set that is not the one the manifest announces", arguments: IncompleteCase.all)
    func incompleteSet(_ item: IncompleteCase) throws {
        let measured = try item.measured()
        let manifest = item.manifest().completed(runs: item.manifest().expectedRuns)

        #expect {
            try DraftSummary(manifest: manifest, detectedLanguages: [:], measured: measured)
        } throws: { error in
            guard let drafting = error as? DraftingError, case .incompleteSet(let problems) = drafting else { return false }
            return problems.contains { $0.contains(item.problem) }
        }
    }

    @Test("A summary of the right runs, in any order, is made")
    func anyOrder() throws {
        let measured = try DraftMeasures.set(["en-plain", "it-plain"], runs: 2).reversed()
        let manifest = DraftMeasures.manifest(["en-plain", "it-plain"], runs: 2)

        let summary = try DraftSummary(manifest: manifest.completed(runs: 4), detectedLanguages: [:], measured: Array(measured))

        #expect(summary.total.runs == 4)
    }

    // MARK: - The file

    @Test("A summary reads back the way it was written")
    func roundTrip() throws {
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.invented, for: "en-plain"))
        let summary = scenario.summary

        let decoded = try JSONDecoder().decode(DraftSummary.self, from: JSONEncoder().encode(summary))

        #expect(decoded == summary)
    }
}

// MARK: - Cases

struct PercentileCase: Sendable, CustomTestStringConvertible {
    let fraction: Double
    let values: [Double]
    let expected: Double

    var testDescription: String { "\(fraction) of \(values)" }

    static let all: [PercentileCase] = [
        PercentileCase(fraction: 0.5, values: [], expected: 0),
        PercentileCase(fraction: 0.95, values: [7], expected: 7),
        PercentileCase(fraction: 0.5, values: [1, 2, 3, 4], expected: 2.5),
        PercentileCase(fraction: 0.5, values: [1, 2, 3], expected: 2),
        PercentileCase(fraction: 0.5, values: [4, 1, 3, 2], expected: 2.5),
        PercentileCase(fraction: 0.95, values: [10, 20], expected: 19.5),
        PercentileCase(fraction: 0.95, values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], expected: 9.55),
        PercentileCase(fraction: 0, values: [3, 9, 5], expected: 3),
        PercentileCase(fraction: 1, values: [3, 9, 5], expected: 9),
        PercentileCase(fraction: 2, values: [3, 9, 5], expected: 9),
        PercentileCase(fraction: -1, values: [3, 9, 5], expected: 3),
    ]
}

/// A set of runs that is not the one its manifest announces, and the problem the summary names.
struct IncompleteCase: Sendable, CustomTestStringConvertible {
    let label: String
    let problem: String
    let manifest: @Sendable () -> RunManifest
    let measured: @Sendable () throws -> [DraftMeasure]

    var testDescription: String { label }

    static let all: [IncompleteCase] = [
        IncompleteCase(
            label: "a run is missing", problem: "it-plain run 2 is missing",
            manifest: { DraftMeasures.manifest(["en-plain", "it-plain"], runs: 2) },
            measured: { try DraftMeasures.set(["en-plain", "it-plain"], runs: 2).dropLast().map { $0 } }
        ),
        IncompleteCase(
            label: "an input is missing", problem: "it-plain run 1 is missing",
            manifest: { DraftMeasures.manifest(["en-plain", "it-plain"]) },
            measured: { try DraftMeasures.set(["en-plain"]) }
        ),
        IncompleteCase(
            label: "a run is there twice", problem: "en-plain run 1 is there 2 times",
            manifest: { DraftMeasures.manifest(["en-plain"]) },
            measured: { try DraftMeasures.set(["en-plain", "en-plain"]) }
        ),
        IncompleteCase(
            label: "a run of another input", problem: "de-plain run 1 is not part of this set",
            manifest: { DraftMeasures.manifest(["en-plain"]) },
            measured: { try DraftMeasures.set(["en-plain", "de-plain"]) }
        ),
        IncompleteCase(
            label: "a run beyond the announced ones", problem: "en-plain run 2 is not part of this set",
            manifest: { DraftMeasures.manifest(["en-plain"], runs: 1) },
            measured: { try DraftMeasures.set(["en-plain"], runs: 2) }
        ),
        IncompleteCase(
            label: "runs of two revisions", problem: "it-plain run 1 was measured at revision other, not abc1234",
            manifest: { DraftMeasures.manifest(["en-plain", "it-plain"]) },
            measured: { [try DraftMeasures.measure("en-plain"), try DraftMeasures.measure("it-plain", revision: "other")] }
        ),
    ]
}
