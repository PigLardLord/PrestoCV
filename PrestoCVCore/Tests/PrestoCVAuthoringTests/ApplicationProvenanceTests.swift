import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport

private typealias P = ApplicationProvenance

private func expect(_ error: ApplicationError, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(error)") } catch let e as ApplicationError { #expect(e == error) } catch { Issue.record("\(error)") }
}

private func experience(_ statements: String...) throws -> P.SourceExperience { try P.SourceExperience(statements: statements) }

/// A provenance around the parts under test; everything else is valid.
private func provenance(jobID: String = "job-1", snapshot: [P.SourceExperience]? = nil, report: P.Report? = nil, questions: [P.Question]? = nil,
                        override: LetterDefaults = .empty, defaults: LetterDefaults = .empty, prompt: String = "tailor-3", provider: String = "provider-a",
                        model: String = "model-small", sources: [P.LineSources] = []) throws -> P {
    try P(jobID: JobID(jobID), sourceCV: FixtureProvenance.sourceCV, snapshot: snapshot ?? [experience("One", "Two")],
          report: report ?? P.Report(argument: "Argument"), questions: questions ?? [], letterOverride: override, letterDefaults: defaults,
          promptVersion: prompt, providerAlias: provider, modelAlias: model, lineSources: sources)
}

@Suite("ADR 0019 · application provenance")
struct ApplicationProvenanceTests {
    @Test("the provenance's bounds are wide enough for everything Tailoring's model accepts: 200 sources per line, 10,000 bytes in the report")
    func boundsHoldTailoringsBounds() throws {
        #expect(P.Limits.sourcesPerLine == 200 && P.Limits.reportBytes == 10_000)
        let text = String(repeating: "r", count: 10_000)
        let report = try P.Report(argument: text, cut: [text], moved: [text], reworded: [text])
        let position = P.StatementPosition(experience: 0, line: 0)
        let sources = P.LineSources(experience: 0, line: 0, statements: Array(repeating: position, count: 200))
        let held = try provenance(report: report, sources: [sources])
        #expect(held.report == report && held.lineSources == [sources])
    }

    @Test("a question's value holds a term or a model request of 10,000 bytes, and a tailored CV 200 experiences of 200 lines: 40,000 line sources")
    func valueAndLineSourceBoundsHoldTailoringsBounds() throws {
        #expect(P.Limits.valueBytes == 10_000 && P.Limits.lineSources == 40_000)
        let value = String(repeating: "v", count: 10_000)
        let question = try P.Question(code: "c", values: [value], scope: .skills, answer: "a")
        #expect(question.values == [value])
        expect(.tooLong(.questionValue)) { _ = try P.Question(code: "c", values: [value + "v"], scope: .skills) }
        let sources = (0..<40_000).map { P.LineSources(experience: $0 / 200, line: $0 % 200) }
        let held = try provenance(questions: [question], sources: sources)
        #expect(held.lineSources.count == 40_000 && held.questions == [question])
        expect(.tooMany(.lineSources)) { _ = try provenance(sources: sources + [P.LineSources(experience: 200, line: 0)]) }
    }

    @Test("the fixture populates every part, so a completeness test over it sees every leaf")
    func fixtureIsComplete() {
        let leaves = FieldLeaves.of(FixtureProvenance.full())
        #expect(!leaves.contains(FieldLeaves.missing) && !leaves.contains(FieldLeaves.empty) && !leaves.contains(""))
    }

    @Test("an identifier is required, trimmed and bounded, and the bound is the limit itself")
    func identifiers() throws {
        #expect(try JobID("  job-1 ").raw == "job-1")
        expect(.empty(.jobID)) { _ = try JobID(" ") }
        _ = try JobID(String(repeating: "a", count: JobID.maxBytes))
        expect(.tooLong(.jobID)) { _ = try JobID(String(repeating: "a", count: JobID.maxBytes + 1)) }
        expect(.forbiddenCharacters(.jobID)) { _ = try JobID("a\nb") }
        let limit = P.Limits.identifierBytes
        _ = try provenance(prompt: String(repeating: "a", count: limit), provider: String(repeating: "a", count: limit), model: String(repeating: "a", count: limit))
        expect(.tooLong(.promptVersion)) { _ = try provenance(prompt: String(repeating: "a", count: limit + 1)) }
        expect(.tooLong(.providerAlias)) { _ = try provenance(provider: String(repeating: "a", count: limit + 1)) }
        expect(.tooLong(.modelAlias)) { _ = try provenance(model: String(repeating: "a", count: limit + 1)) }
        expect(.empty(.promptVersion)) { _ = try provenance(prompt: "") }
        expect(.empty(.providerAlias)) { _ = try provenance(provider: " ") }
        expect(.empty(.modelAlias)) { _ = try provenance(model: "\n") }
    }

    @Test("a statement is one line that says something, and each list is bounded")
    func statements() throws {
        expect(.empty(.statement)) { _ = try experience("One", " ") }
        expect(.forbiddenCharacters(.statement)) { _ = try experience("One\nTwo") }
        expect(.tooLong(.statement)) { _ = try experience(String(repeating: "a", count: P.Limits.statementBytes + 1)) }
        _ = try P.SourceExperience(statements: Array(repeating: "a", count: P.Limits.items))
        expect(.tooMany(.statement)) { _ = try P.SourceExperience(statements: Array(repeating: "a", count: P.Limits.items + 1)) }
        let experiences = Array(repeating: try experience("a"), count: P.Limits.items + 1)
        expect(.tooMany(.snapshot)) { _ = try provenance(snapshot: experiences) }
        _ = try provenance(snapshot: Array(experiences.dropLast()))
    }

    @Test("the report holds the argument and what was cut, moved and reworded, as bounded text")
    func report() throws {
        expect(.tooLong(.reportArgument)) { _ = try P.Report(argument: String(repeating: "a", count: P.Limits.reportBytes + 1)) }
        expect(.empty(.reportEntry)) { _ = try P.Report(argument: "A", cut: [" "]) }
        expect(.tooMany(.reportEntry)) { _ = try P.Report(argument: "A", moved: Array(repeating: "m", count: P.Limits.items + 1)) }
        expect(.forbiddenCharacters(.reportEntry)) { _ = try P.Report(argument: "A", reworded: ["a\u{202E}b"]) }
        #expect(try P.Report(argument: " A \n").argument == "A")
    }

    @Test("a question is a code and its values, a scope and an answer that a skipped question lacks")
    func questions() throws {
        expect(.empty(.questionCode)) { _ = try P.Question(code: " ", scope: .skills) }
        expect(.tooLong(.questionCode)) { _ = try P.Question(code: String(repeating: "c", count: P.Limits.identifierBytes + 1), scope: .skills) }
        expect(.tooMany(.questionValue)) { _ = try P.Question(code: "c", values: Array(repeating: "v", count: P.Limits.questionValues + 1), scope: .summary) }
        expect(.tooLong(.answer)) { _ = try P.Question(code: "c", scope: .summary, answer: String(repeating: "a", count: P.Limits.answerBytes + 1)) }
        #expect(try P.Question(code: "c", scope: .summary, answer: "  ").answer == nil)
        #expect(try P.Question(code: "c", scope: .summary, answer: "Line one\nline two").answer == "Line one\nline two")
        expect(.tooMany(.questions)) {
            _ = try provenance(questions: Array(repeating: P.Question(code: "c", scope: .skills), count: P.Limits.items + 1))
        }
    }

    @Test("a question about an experience names one of the snapshot's")
    func questionScope() throws {
        _ = try provenance(questions: [P.Question(code: "c", scope: .experience(0))])
        expect(.invalidReference(.questions)) { _ = try provenance(questions: [P.Question(code: "c", scope: .experience(1))]) }
        expect(.invalidReference(.questions)) { _ = try provenance(questions: [P.Question(code: "c", scope: .experience(-1))]) }
    }

    @Test("every statement and answer that a line names is a position inside the snapshot and its answers")
    func references() throws {
        let questions = [try P.Question(code: "c", scope: .skills, answer: "Yes"), try P.Question(code: "d", scope: .summary)]
        let snapshot = [try experience("One", "Two"), try experience("Three")]
        func with(_ sources: P.LineSources) throws { _ = try provenance(snapshot: snapshot, questions: questions, sources: [sources]) }
        try with(P.LineSources(experience: 3, line: 7, statements: [P.StatementPosition(experience: 1, line: 0), P.StatementPosition(experience: 0, line: 1)], answers: [0]))
        for position in [P.StatementPosition(experience: 2, line: 0), P.StatementPosition(experience: 1, line: 1), P.StatementPosition(experience: -1, line: 0),
                         P.StatementPosition(experience: 0, line: -1)] {
            expect(.invalidReference(.statementReference)) { try with(P.LineSources(experience: 0, line: 0, statements: [position])) }
        }
        expect(.invalidReference(.answerReference)) { try with(P.LineSources(experience: 0, line: 0, answers: [2])) }
        expect(.invalidReference(.answerReference)) { try with(P.LineSources(experience: 0, line: 0, answers: [-1])) }
        expect(.invalidReference(.answerReference)) { try with(P.LineSources(experience: 0, line: 0, answers: [1])) }   // skipped: not an answer
    }

    @Test("the position of a tailored line is only non-negative, because the user's edits move it; the lists are bounded")
    func lineSources() throws {
        _ = try provenance(sources: [P.LineSources(experience: 40, line: 40)])
        expect(.invalidReference(.lineSources)) { _ = try provenance(sources: [P.LineSources(experience: -1, line: 0)]) }
        expect(.invalidReference(.lineSources)) { _ = try provenance(sources: [P.LineSources(experience: 0, line: -1)]) }
        let position = P.StatementPosition(experience: 0, line: 0)
        _ = try provenance(sources: [P.LineSources(experience: 0, line: 0, statements: Array(repeating: position, count: P.Limits.sourcesPerLine))])
        expect(.tooMany(.statementReference)) {
            _ = try provenance(sources: [P.LineSources(experience: 0, line: 0, statements: Array(repeating: position, count: P.Limits.sourcesPerLine + 1))])
        }
        expect(.tooMany(.lineSources)) {
            _ = try provenance(sources: Array(repeating: P.LineSources(experience: 0, line: 0), count: P.Limits.lineSources + 1))
        }
    }

    @Test("the defaults as the snapshot held them say what the override set, and the override leaves the other fields to the person")
    func overrideApplied() throws {
        let override = try LetterDefaults(salaryExpectation: "60k")
        expect(.overrideNotApplied(.salaryExpectation)) { _ = try provenance(override: override, defaults: LetterDefaults(salaryExpectation: "55k", note: "Remote")) }
        expect(.overrideNotApplied(.salaryExpectation)) { _ = try provenance(override: override, defaults: .empty) }
        let held = try provenance(override: override, defaults: LetterDefaults(salaryExpectation: "60k", note: "Remote"))
        #expect(held.letterOverride == override && held.letterDefaults.note == "Remote")
        _ = try provenance(override: .empty, defaults: LetterDefaults(note: "Remote"))
    }
}
