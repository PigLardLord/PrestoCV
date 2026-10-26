import Foundation
import CVGeneratorAI

// Run records and run sets made by hand, for the tests of the harness of the drafting evaluation. No model runs here.

/// What a test changes in a run: the draft the model wrote, and how the use case ended.
struct Tweak {
    /// Edits the draft the model wrote. The final draft is the same unless `finalEdit` edits it again.
    var edit: (inout Draft) -> Void = { _ in }
    var finalEdit: ((inout Draft) -> Void)?
    var unchecked = false
    var error: (any Error)?
    var checks: [CheckEvent] = []
    var seconds = 10.0
}

enum DraftMeasures {
    static let revision = "abc1234"

    /// One run of the input `id`: the draft of its facts and nothing else, as the tweak edits it.
    static func measure(_ id: String, run: Int = 1, revision: String = DraftMeasures.revision, _ tweak: Tweak = Tweak()) throws -> DraftMeasure {
        let input = try InventedFactsTests.input(id)
        var raw = Draft(faithfulTo: input)
        tweak.edit(&raw)
        var shown = raw
        tweak.finalEdit?(&shown)
        let result = tweak.error == nil
            ? GeneratedDraft(cvData: shown.cv, personalItemsUnchecked: tweak.unchecked) : nil
        return DraftMeasure(
            input: input, run: run, revision: revision, seconds: tweak.seconds, load: nil, raw: raw.cv, grounded: raw.cv, result: result,
            error: tweak.error, checks: tweak.checks
        )
    }

    /// `runs` runs of each of `ids`, in the order the evaluation writes them: every input once, then again.
    static func set(
        _ ids: [String], runs: Int = 1, revision: String = DraftMeasures.revision, tweak: (String, Int) -> Tweak = { _, _ in Tweak() }
    ) throws -> [DraftMeasure] {
        var measured: [DraftMeasure] = []
        for run in 1...runs {
            for id in ids {
                measured.append(try measure(id, run: run, revision: revision, tweak(id, run)))
            }
        }
        return measured
    }

    /// `tweak` for the runs of `id` (of its run number `run`, when given) and the plain tweak for every other run.
    static func tweak(_ tweak: Tweak, for id: String, run: Int? = nil) -> (String, Int) -> Tweak {
        { name, number in name == id && (run == nil || run == number) ? tweak : Tweak() }
    }

    static func manifest(_ ids: [String], runs: Int = 1, revision: String = DraftMeasures.revision, all: [String]? = nil) -> RunManifest {
        RunManifest(
            revision: revision, system: "macOS test", xcode: "27.0 (test)", started: Date(timeIntervalSince1970: 1_792_000_000),
            runsPerInput: runs, inputs: ids, allInputs: all ?? ids
        )
    }
}

/// A complete run set with its summary and review items, which a test then spoils one way at a time.
struct Scenario {
    var manifest: RunManifest
    var measured: [DraftMeasure]
    var summary: DraftSummary
    var review: [ReviewItem]
    var adjudication: Adjudication?

    /// A set that is complete, of the whole evaluation (`all` defaults to `ids`), with no adjudication.
    static func make(
        ids: [String] = ["en-plain", "it-plain"], all: [String]? = nil, runs: Int = 1, revision: String = DraftMeasures.revision,
        tweak: (String, Int) -> Tweak = { _, _ in Tweak() }
    ) throws -> Scenario {
        let measured = try DraftMeasures.set(ids, runs: runs, revision: revision, tweak: tweak)
        let started = DraftMeasures.manifest(ids, runs: runs, revision: revision, all: all)
        let manifest = started.completed(runs: started.expectedRuns)
        return Scenario(
            manifest: manifest, measured: measured,
            summary: try DraftSummary(manifest: manifest, detectedLanguages: [:], measured: measured),
            review: ReviewItem.unique(in: measured), adjudication: nil
        )
    }

    /// The same set once a person has decided every item of review.json.
    func adjudicated(by reviewer: String = "G. T.", at revision: String? = nil, as decision: Adjudication.Decision = .accept) -> Scenario {
        var scenario = self
        scenario.adjudication = Adjudication(
            reviewer: reviewer, revision: revision ?? manifest.revision,
            entries: review.map { Adjudication.Entry(key: $0.key, decision: decision, note: nil) }
        )
        return scenario
    }

    var verdict: Readiness {
        Readiness.verdict(manifest: manifest, summary: summary, review: review, adjudication: adjudication)
    }

    /// What makes en-plain write one field the counter sends to review: a hobby of several words, taken from the description.
    static var reviewedOnce: Tweak { Tweak(edit: { $0.interests.append("bake bread") }) }

    /// What makes en-plain or en-traps write two fields the counter sends to review: a language of the description, listed as a skill
    /// too. The skill is a doubt, and so is the language, which the skill now shadows.
    static var reviewed: Tweak { Tweak(edit: { $0.skills.append(Skill(name: "English")) }) }

    /// What makes en-plain write a field the counter proves invented: a skill the description does not have.
    static var invented: Tweak { Tweak(edit: { $0.skills.append(Skill(name: "Kubernetes")) }) }
}
