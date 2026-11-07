import Foundation
import Testing

/// The tests of the AI draft never run out of time by themselves (#413). A draft's requests and its claim check have time limits,
/// and a limit on the real clock ends on a busy machine whatever the test says: the same tests pass on an idle Mac and fail on a
/// loaded one. So every use case a test builds gets its limits (`DraftingLimits`, which holds the claim check's too) on
/// `TestCallClock`, whose time ends only when the test says so.
///
/// The two evaluations call the real model and keep the real limits: `evaluations` names them.
@Suite("The AI draft tests - limits on a test clock")
struct DraftTimeLimitsTests {

    /// The tests that call the real model, and so keep the real limits.
    static let evaluations: Set<String> = [
        "CVGeneratorAI/Tests/CVGeneratorAITests/DraftingEvaluation.swift",
        "CVGeneratorAI/Tests/CVGeneratorAITests/ClaimCheckEvaluation.swift",
    ]

    /// What a test file does wrong, one line each: a use case built with the public initialiser (it takes `logger:`, and sets the
    /// real limits), a use case given the real limits, a claim check given the real limits, and a helper that builds a use case
    /// without test-clock limits.
    static func violations(in path: String, source: String) -> [String] {
        let code = SwiftCode(source).code.joined(separator: "\n")
        var found: [String] = []
        for call in calls(of: "CVGeneratorUseCase(", in: code) {
            if call.contains("logger:") && !call.contains("limits:") {
                found.append("\(path): CVGeneratorUseCase(…) takes the real limits; pass `limits: .onTestClock()`")
            }
            if call.contains("limits: .standard") {
                found.append("\(path): CVGeneratorUseCase(…) is given `limits: .standard`; pass `limits: .onTestClock()`")
            }
        }
        if code.contains("within: .standard") {
            found.append("\(path): the claim check is given `within: .standard`; pass `within: .onTestClock()`")
        }
        if code.contains("extension CVGeneratorUseCase"), !code.contains(".onTestClock(") {
            found.append("\(path): the helper builds a use case without limits on `.onTestClock()`")
        }
        return found
    }

    /// The text between the parentheses of each call that starts with `opening` (its name and the parenthesis), not a declaration.
    private static func calls(of opening: String, in code: String) -> [String] {
        var found: [String] = []
        var from = code.startIndex
        while let start = code.range(of: opening, range: from..<code.endIndex) {
            from = start.upperBound
            var depth = 1
            var end = start.upperBound
            while end < code.endIndex, depth > 0 {
                if code[end] == "(" { depth += 1 }
                if code[end] == ")" { depth -= 1 }
                end = code.index(after: end)
            }
            found.append(String(code[start.upperBound..<end]))
        }
        return found
    }

    @Test("Every use case a test of the AI draft builds has its time limits on a test clock")
    func testsBuildTheirUseCasesOnATestClock() throws {
        let files = try RepositorySources.testFiles().filter { !Self.evaluations.contains($0.path) }
            .filter { $0.path.hasPrefix("CVGeneratorAI/") || $0.path.hasPrefix("PrestoCVTests/") }
        #expect(files.contains { $0.text.contains("CVGeneratorUseCase") }, "The check found no test that builds a use case")

        let found = files.flatMap { Self.violations(in: $0.path, source: $0.text) }

        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test("The evaluations that call the real model exist, so the exception names something")
    func evaluationsExist() throws {
        let paths = Set(try RepositorySources.testFiles().map(\.path))

        #expect(Self.evaluations.isSubset(of: paths), "\(Self.evaluations.subtracting(paths))")
    }

    struct Scenario: Sendable {
        let name: String
        let source: String
        let violations: Int
    }

    static let scenarios: [Scenario] = [
        Scenario(name: "the public initialiser", source: "CVGeneratorUseCase(service: s, claimChecker: c, logger: l, clock: k, tracer: t)", violations: 1),
        Scenario(name: "the full initialiser on a test clock",
                 source: "CVGeneratorUseCase(service: s, logger: l, limits: .onTestClock())", violations: 0),
        Scenario(name: "the real limits given", source: "CVGeneratorUseCase(service: s, logger: l, limits: .standard)", violations: 1),
        Scenario(name: "the helper form", source: "CVGeneratorUseCase(service: s, claimChecker: c)", violations: 0),
        Scenario(name: "a helper with the real limits", source: "extension CVGeneratorUseCase { init() { self.init(logger: l) } }", violations: 1),
        Scenario(name: "a helper on a test clock",
                 source: "extension CVGeneratorUseCase { init() { self.init(logger: l, limits: .onTestClock()) } }", violations: 0),
        Scenario(name: "a comment", source: "// CVGeneratorUseCase(service: s, logger: l)", violations: 0),
        Scenario(name: "a claim check on the real limits",
                 source: "ClaimWithdrawal.checking(d, in: t, with: c, within: .standard)", violations: 1),
        Scenario(name: "a claim check on a test clock",
                 source: "ClaimWithdrawal.checking(d, in: t, with: c, within: .onTestClock())", violations: 0),
    ]

    @Test("The check reads a source", arguments: scenarios)
    func readsASource(_ scenario: Scenario) {
        #expect(Self.violations(in: "A.swift", source: scenario.source).count == scenario.violations, "\(scenario.name)")
    }
}
