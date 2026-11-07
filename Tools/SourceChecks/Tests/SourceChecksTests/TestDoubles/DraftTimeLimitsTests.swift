import Foundation
import Testing

/// The tests of the AI draft never run out of time by themselves (#413). A draft's requests and its claim check have time limits,
/// and a limit on the real clock ends on a busy machine whatever the test says: the same tests pass on an idle Mac and fail on a
/// loaded one. So every limit a test gives (`DraftingLimits`, which holds the claim check's `ClaimCheckLimits`, and a section's
/// `TimeLimit`) runs on a test clock: `.onTestClock()`, the app's times on `TestCallClock`.
///
/// The check reads the code of every test file that names the draft or one of its limits (comments and strings left out), and
/// reports, one line each:
/// 1. the real limits: a `.standard` of `DraftingLimits` or `ClaimCheckLimits`, written with its type or implied by the context
///    (`limits: .standard`, `= .standard`, `{ .standard }`, `?? .standard`), that `.on(` does not move to another clock. Any
///    implied `.standard` counts, since the text does not say its type: an `ImportCV` in such a file writes `ImportLimits.standard`;
/// 2. a real clock (`ContinuousClock()`, `SuspendingClock()`, `.continuous`, `.suspending`) anywhere but as the `clock:` argument
///    of a call that makes no limit: the use case's `clock:` times the steps for the log and ends nothing;
/// 3. a call that builds a use case with the public initialiser, which sets the real limits: it has `logger:` and no `limits:`,
///    and it has `claimChecker:` or it names the use case (`CVGeneratorUseCase(`, `CVGeneratorUseCase.init(`,
///    `let u: CVGeneratorUseCase = .init(`, or `self.init(`, `Self(` and `.init(` inside `extension CVGeneratorUseCase`);
/// 4. the initialiser named without a call (`CVGeneratorUseCase.init` passed as a function), whose arguments it cannot read.
///
/// A text check cannot follow a value: limits made in another file and passed in, a type alias of the limits, a generic `T(…)` or
/// a metatype's `init` escape it. Where it cannot tell, it reports: a false alarm is seen and fixed, a silent miss is not.
///
/// The two evaluations call the real model and keep the real limits: `evaluations` names them.
@Suite("The AI draft tests - limits on a test clock")
struct DraftTimeLimitsTests {

    /// The tests that call the real model, and so keep the real limits.
    static let evaluations: Set<String> = [
        "CVGeneratorAI/Tests/CVGeneratorAITests/DraftingEvaluation.swift",
        "CVGeneratorAI/Tests/CVGeneratorAITests/ClaimCheckEvaluation.swift",
    ]

    /// The types whose `.standard` holds the real limits.
    static let limitTypes: Set<String> = ["DraftingLimits", "ClaimCheckLimits"]

    /// The calls that make a limit: a real clock is wrong in any of their arguments.
    static let limitCalls: Set<String> = ["DraftingLimits", "ClaimCheckLimits", "TimeLimit"]

    /// Whether the check reads a file: its code names the draft or one of its limits.
    static func reads(_ source: String) throws -> Bool {
        let draftTypes = #"\b(?:CVGeneratorUseCase|DraftingLimits|ClaimCheckLimits|ClaimWithdrawal|TimeLimit|SectionDraft)\b"#
        return try !DraftCode(source).matches(draftTypes).isEmpty
    }

    /// What a test file does wrong, one line each, by the four rules above.
    static func violations(in path: String, source: String) throws -> [String] {
        guard try reads(source) else { return [] }
        let code = DraftCode(source)
        let calls = code.calls()
        var found: [String] = []
        func report(_ offset: Int, _ text: String) { found.append("\(path):\(code.line(of: offset)): \(text)") }

        for match in try code.matches(#"\.standard\b"#) {
            if try code.continues(after: match, with: #"\s*\.\s*on\s*\("#) { continue }
            switch code.receiver(ofMemberAt: match.location) {
            case .implied, .type("Self"):
                report(match.location, "`.standard` gives the real limits; write `.onTestClock()`")
            case .type(let type) where limitTypes.contains(type):
                report(match.location, "`\(type).standard` gives the real limits; write `\(type).onTestClock()`")
            default:
                break
            }
        }

        let realClocks = #"\b(?:Continuous|Suspending)Clock\s*(?:\.\s*init\s*)?\(\s*\)|\.(?:continuous|suspending)\b"#
        for match in try code.matches(realClocks) {
            let start = match.location
            if code.units[start] == DraftCode.dot {
                switch code.receiver(ofMemberAt: start) {
                case .implied: break
                case .type(let type) where type.hasSuffix("Clock"): break
                default: continue
                }
            }
            if code.isTheLogClock(at: start, calls: calls) { continue }
            report(start, "a real clock, and a limit on it ends on a busy machine; use `TestCallClock()`")
        }

        let bodies = try code.useCaseExtensionBodies()
        for call in calls where call.labels.contains("logger") && !call.labels.contains("limits")
            && (call.labels.contains("claimChecker") || code.buildsAUseCase(call, extensionBodies: bodies)) {
            report(call.open, "`\(call.name)(…)` builds a use case on the real limits; pass `limits: .onTestClock()`")
        }

        for match in try code.matches(#"\bCVGeneratorUseCase\s*\.\s*init\b(?!\s*\()"#) {
            report(match.location, "`CVGeneratorUseCase.init` passed as a function hides its arguments; call it with `limits:`")
        }
        return found
    }

    @Test("Every limit a test of the AI draft gives runs on a test clock")
    func testsBuildTheirUseCasesOnATestClock() throws {
        let files = try RepositorySources.testFiles().filter { !Self.evaluations.contains($0.path) }
        let read = try files.filter { try Self.reads($0.text) }
        #expect(!read.isEmpty, "The check found no test of the AI draft")

        let found = try read.flatMap { try Self.violations(in: $0.path, source: $0.text) }

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
        // A use case built with the public initialiser, or given the real limits.
        Scenario(name: "the public initialiser", source: "CVGeneratorUseCase(service: s, claimChecker: c, logger: l, clock: k, tracer: t)", violations: 1),
        Scenario(name: "the public initialiser by its name",
                 source: "CVGeneratorUseCase.init(service: s, claimChecker: c, logger: l, clock: k, tracer: t)", violations: 1),
        Scenario(name: "the public initialiser by the variable's type",
                 source: "let u: CVGeneratorUseCase = .init(service: s, claimChecker: c, logger: l, clock: k, tracer: t)", violations: 1),
        Scenario(name: "a use case named by the variable's type", source: "let u: CVGeneratorUseCase = .init(service: s, logger: l)", violations: 1),
        Scenario(name: "the initialiser passed as a function", source: "let make = CVGeneratorUseCase.init", violations: 1),
        Scenario(name: "the initialiser by its full name",
                 source: "let make = CVGeneratorUseCase.init(service:claimChecker:logger:clock:tracer:)", violations: 1),
        Scenario(name: "the full initialiser on a test clock",
                 source: "CVGeneratorUseCase(service: s, logger: l, limits: .onTestClock())", violations: 0),
        Scenario(name: "the real limits given", source: "CVGeneratorUseCase(service: s, logger: l, limits: .standard)", violations: 1),
        Scenario(name: "the real limits given without a space", source: "CVGeneratorUseCase(service: s, logger: l, limits:.standard)", violations: 1),
        Scenario(name: "the helper form", source: "CVGeneratorUseCase(service: s, claimChecker: c)", violations: 0),
        Scenario(name: "a helper with the real limits", source: "extension CVGeneratorUseCase { init() { self.init(logger: l) } }", violations: 1),
        Scenario(name: "a helper on a test clock",
                 source: "extension CVGeneratorUseCase { init() { self.init(logger: l, limits: .onTestClock()) } }", violations: 0),
        Scenario(name: "a helper on the public initialiser beside a test clock elsewhere", source: """
            extension CVGeneratorUseCase {
                convenience init(service: S) { self.init(service: service, claimChecker: C(), logger: L(), clock: K(), tracer: T()) }
            }
            let limits = DraftingLimits.onTestClock()
            """, violations: 1),
        Scenario(name: "another helper that takes a claim checker and a logger (a false alarm the author sees)",
                 source: "let u = CVGeneratorUseCase(service: s, claimChecker: c); makeUseCase(claimChecker: c, logger: l)", violations: 1),
        Scenario(name: "a view model given a claim checker",
                 source: "let u = CVGeneratorUseCase(service: s, claimChecker: c); makeViewModel(claimChecker: x)", violations: 0),
        Scenario(name: "a comment", source: "// CVGeneratorUseCase(service: s, logger: l)", violations: 0),
        Scenario(name: "a string", source: #"let u = CVGeneratorUseCase(service: s, claimChecker: c); print("limits: .standard, ContinuousClock()")"#,
                 violations: 0),
        // The real limits in other forms.
        Scenario(name: "a claim check on the real limits",
                 source: "ClaimWithdrawal.checking(d, in: t, with: c, within: .standard)", violations: 1),
        Scenario(name: "a claim check on a test clock",
                 source: "ClaimWithdrawal.checking(d, in: t, with: c, within: .onTestClock())", violations: 0),
        Scenario(name: "the real limits in a variable", source: "let limits = DraftingLimits.standard", violations: 1),
        Scenario(name: "the real limits on the next line", source: "let limits = DraftingLimits\n    .standard", violations: 1),
        Scenario(name: "the real batch size read", source: "let size = ClaimCheckLimits.standard.batchSize", violations: 1),
        Scenario(name: "the real limits as a default", source: "func make(limits: DraftingLimits = .standard) {}", violations: 1),
        Scenario(name: "the real limits from a getter", source: "var limits: DraftingLimits { .standard }", violations: 1),
        Scenario(name: "the real limits returned", source: "var limits: DraftingLimits { return .standard }", violations: 1),
        Scenario(name: "the real limits as a fallback", source: "let limits: DraftingLimits = given ?? .standard", violations: 1),
        Scenario(name: "the real limits of Self", source: "extension DraftingLimits { static var test: Self { Self.standard } }", violations: 1),
        Scenario(name: "a section given the real limit",
                 source: "SectionDraft(service: s, sanitizer: z, log: l, limit: DraftingLimits.standard.section, description: d)", violations: 1),
        Scenario(name: "the standard times on a test clock", source: "let limits = DraftingLimits.standard.on(clock)", violations: 0),
        Scenario(name: "the standard times on a test clock, the next line", source: "let limits = DraftingLimits.standard\n    .on(clock)", violations: 0),
        Scenario(name: "the standard of another type", source: "let d = UserDefaults.standard; let u = CVGeneratorUseCase(service: s, claimChecker: c)",
                 violations: 0),
        Scenario(name: "an import given the real limits in a draft test (a false alarm the author sees)",
                 source: "ImportCV(pdfReader: r, limits: .standard, logger: l, clock: k, tracer: t); CVGeneratorUseCase(service: s, claimChecker: c)",
                 violations: 1),
        Scenario(name: "an import given its limits by type in a draft test",
                 source: "ImportCV(pdfReader: r, limits: ImportLimits.standard, logger: l, clock: k, tracer: t); CVGeneratorUseCase(service: s, claimChecker: c)",
                 violations: 0),
        Scenario(name: "a file that names no draft type", source: "ImportCV(pdfReader: r, limits: .standard, logger: l, clock: ContinuousClock(), tracer: t)",
                 violations: 0),
        // Real clocks.
        Scenario(name: "the standard times on the real clock", source: "let limits = DraftingLimits.standard.on(ContinuousClock())", violations: 1),
        Scenario(name: "the standard times on the real clock, implied", source: "let limits = DraftingLimits.standard.on(.continuous)", violations: 1),
        Scenario(name: "claim check limits on the real clock",
                 source: "ClaimCheckLimits(batchSize: 8, time: .seconds(60), on: ContinuousClock())", violations: 1),
        Scenario(name: "drafting limits on the real clock",
                 source: "DraftingLimits(extraction: .seconds(90), section: .seconds(30), claimCheck: .onTestClock(), on: SuspendingClock())", violations: 1),
        Scenario(name: "a time limit on the real clock", source: "TimeLimit(duration: .seconds(30), clock: ContinuousClock())", violations: 1),
        Scenario(name: "a time limit on a test clock", source: "TimeLimit(duration: .seconds(30), clock: TestCallClock())", violations: 0),
        Scenario(name: "a section's time limit on the real clock, implied",
                 source: "SectionDraft(service: s, sanitizer: z, log: l, limit: .init(duration: .seconds(30), clock: ContinuousClock()), description: d)",
                 violations: 1),
        Scenario(name: "a real clock in a variable", source: "let c = ContinuousClock(); let u = CVGeneratorUseCase(service: s, claimChecker: c)", violations: 1),
        Scenario(name: "a real clock as a default", source: "func make(clock: any Clock<Duration> = ContinuousClock()) -> TimeLimit { l }", violations: 1),
        Scenario(name: "the real clock by its type", source: "let limit = TimeLimit(duration: .seconds(1), clock: ContinuousClock.continuous)", violations: 1),
        Scenario(name: "the use case's log clock",
                 source: "CVGeneratorUseCase(service: s, claimChecker: c, logger: l, clock: ContinuousClock(), tracer: t, limits: .onTestClock())",
                 violations: 0),
        Scenario(name: "the time now", source: "let start = ContinuousClock.now; let limit = TimeLimit(duration: .seconds(1), clock: k)", violations: 0),
        Scenario(name: "a member of a value", source: "let k = timer.suspending; let u = CVGeneratorUseCase(service: s, claimChecker: c)", violations: 0),
    ]

    @Test("The check reads a source", arguments: scenarios)
    func readsASource(_ scenario: Scenario) throws {
        let found = try Self.violations(in: "A.swift", source: scenario.source)

        #expect(found.count == scenario.violations, "\(scenario.name): \(found)")
    }
}

/// A test file's code without its comments and strings, read as UTF-16 units, so that the offsets of a regular expression's
/// matches index it.
private struct DraftCode {
    /// Where a member written `.name` is read from.
    enum Receiver: Equatable {
        /// The context gives the type: `limits: .standard`, `return .standard`.
        case implied
        /// A name: `DraftingLimits.standard`, or a value's `limits.standard`.
        case type(String)
        /// The result of a call, a subscript, or an optional: `make().standard`.
        case expression
    }

    /// A call: the name before its parenthesis, the parentheses, and the labels of its arguments.
    struct Call {
        let name: String
        let nameStart: Int
        let open: Int
        let close: Int
        let labels: Set<String>

        /// The type the call names, without `init`: `CVGeneratorUseCase` for `CVGeneratorUseCase.init`, empty for `.init`.
        var type: String { name.split(separator: ".").last { $0 != "init" }.map(String.init) ?? "" }
    }

    static let dot = UInt16(UInt8(ascii: "."))
    private static let colon = UInt16(UInt8(ascii: ":"))
    private static let comma = UInt16(UInt8(ascii: ","))
    private static let equals = UInt16(UInt8(ascii: "="))
    private static let pairs: [UInt16: UInt16] = [UInt16(UInt8(ascii: "(")): UInt16(UInt8(ascii: ")")), UInt16(UInt8(ascii: "[")): UInt16(UInt8(ascii: "]")),
                                                  UInt16(UInt8(ascii: "{")): UInt16(UInt8(ascii: "}"))]
    /// The words after which a `.member` is implied by the context, not read from the word.
    private static let keywords: Set<String> = ["return", "in", "case", "try", "await", "else", "throw", "where", "is", "as", "if",
                                                "guard", "while", "switch", "then"]

    let text: String
    let units: [UInt16]

    init(_ source: String) {
        text = SwiftCode(source).skeleton.joined(separator: "\n")
        units = Array(text.utf16)
    }

    // MARK: Matching

    func matches(_ pattern: String) throws -> [NSRange] {
        try NSRegularExpression(pattern: pattern).matches(in: text, range: NSRange(location: 0, length: units.count)).map(\.range)
    }

    /// Whether the code right after `match` matches `pattern`.
    func continues(after match: NSRange, with pattern: String) throws -> Bool {
        let end = match.location + match.length
        let rest = NSRange(location: end, length: units.count - end)
        return try NSRegularExpression(pattern: pattern).firstMatch(in: text, options: .anchored, range: rest) != nil
    }

    func line(of offset: Int) -> Int {
        units[..<offset].lazy.filter { $0 == 10 }.count + 1
    }

    // MARK: Reading back

    func receiver(ofMemberAt dot: Int) -> Receiver {
        guard let before = previousNonSpace(before: dot) else { return .implied }
        let unit = units[before]
        if Self.isWord(unit) {
            let word = word(endingAt: before)
            return Self.keywords.contains(word) ? .implied : .type(word)
        }
        if unit == UInt16(UInt8(ascii: ")")) || unit == UInt16(UInt8(ascii: "]")) { return .expression }
        let postfix: Set<UInt16> = [UInt16(UInt8(ascii: "?")), UInt16(UInt8(ascii: "!")), UInt16(UInt8(ascii: ">"))]
        return postfix.contains(unit) && before == dot - 1 ? .expression : .implied
    }

    /// Whether the real clock at `start` is the `clock:` argument of a call that makes no limit: the use case's, which times the
    /// steps for the log.
    func isTheLogClock(at start: Int, calls: [Call]) -> Bool {
        guard let colon = previousNonSpace(before: start), units[colon] == Self.colon,
              let labelEnd = previousNonSpace(before: colon), word(endingAt: labelEnd) == "clock",
              let opening = previousNonSpace(before: wordStart(endingAt: labelEnd)),
              units[opening] == Self.comma || units[opening] == UInt16(UInt8(ascii: "(")),
              let call = calls.filter({ $0.open < start && start < $0.close }).max(by: { $0.open < $1.open })
        else { return false }
        return !DraftTimeLimitsTests.limitCalls.contains(call.type) && !call.labels.contains("duration")
    }

    /// Whether `call` names the use case: by its type, by the type of the variable it sets, or as `self.init` and the like in an
    /// extension of it.
    func buildsAUseCase(_ call: Call, extensionBodies: [Range<Int>]) -> Bool {
        if call.type == "CVGeneratorUseCase" { return true }
        if ["self.init", "Self", "Self.init", ".init"].contains(call.name), extensionBodies.contains(where: { $0.contains(call.open) }) {
            return true
        }
        guard call.name == ".init", let equals = previousNonSpace(before: call.nameStart), units[equals] == Self.equals,
              let typeEnd = previousNonSpace(before: equals) else { return false }
        return word(endingAt: typeEnd) == "CVGeneratorUseCase"
    }

    /// The bodies of `extension CVGeneratorUseCase`, braces included.
    func useCaseExtensionBodies() throws -> [Range<Int>] {
        try matches(#"\bextension\s+(?:\w+\s*\.\s*)*CVGeneratorUseCase\b"#).compactMap { match in
            guard let open = units[(match.location + match.length)...].firstIndex(of: UInt16(UInt8(ascii: "{"))),
                  let close = closing(open) else { return nil }
            return open..<(close + 1)
        }
    }

    // MARK: Calls

    /// Every call in the code with a name before its parenthesis; declarations (`init(`, `func f(`) are not calls.
    func calls() -> [Call] {
        units.indices.compactMap { open in
            guard units[open] == UInt16(UInt8(ascii: "(")), let close = closing(open) else { return nil }
            var nameStart = open
            while nameStart > 0, Self.isWord(units[nameStart - 1]) || units[nameStart - 1] == Self.dot { nameStart -= 1 }
            let name = string(nameStart..<open)
            guard !name.isEmpty, name != "init", name != "subscript", !isDeclared(nameStart) else { return nil }
            return Call(name: name, nameStart: nameStart, open: open, close: close, labels: labels(in: (open + 1)..<close))
        }
    }

    /// The labels of the arguments between a call's parentheses: the words before a colon at the start of each argument, and
    /// every word of a full name (`service:claimChecker:logger:`).
    private func labels(in range: Range<Int>) -> Set<String> {
        var arguments: [Range<Int>] = []
        var depth = 0
        var start = range.lowerBound
        for index in range {
            let unit = units[index]
            if Self.pairs.keys.contains(unit) { depth += 1 }
            if Self.pairs.values.contains(unit) { depth -= 1 }
            if unit == Self.comma, depth == 0 {
                arguments.append(start..<index)
                start = index + 1
            }
        }
        arguments.append(start..<range.upperBound)
        var labels: Set<String> = []
        for argument in arguments {
            var index = argument.lowerBound
            while true {
                while index < argument.upperBound, Self.isSpace(units[index]) { index += 1 }
                let wordStart = index
                while index < argument.upperBound, Self.isWord(units[index]) { index += 1 }
                guard index > wordStart else { break }
                let word = string(wordStart..<index)
                while index < argument.upperBound, Self.isSpace(units[index]) { index += 1 }
                guard index < argument.upperBound, units[index] == Self.colon else { break }
                labels.insert(word)
                index += 1
            }
        }
        return labels
    }

    /// Whether the name at `nameStart` is being declared (`func make(`), not called.
    private func isDeclared(_ nameStart: Int) -> Bool {
        guard let before = previousNonSpace(before: nameStart), Self.isWord(units[before]) else { return false }
        return ["func", "case"].contains(word(endingAt: before))
    }

    /// The index of the bracket that closes the one at `open`.
    private func closing(_ open: Int) -> Int? {
        guard let close = Self.pairs[units[open]] else { return nil }
        var depth = 0
        for index in open..<units.count {
            if units[index] == units[open] { depth += 1 }
            if units[index] == close {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    // MARK: Units

    private func previousNonSpace(before index: Int) -> Int? {
        var index = index - 1
        while index >= 0, Self.isSpace(units[index]) { index -= 1 }
        return index >= 0 ? index : nil
    }

    private func wordStart(endingAt end: Int) -> Int {
        var start = end
        while start > 0, Self.isWord(units[start - 1]) { start -= 1 }
        return start
    }

    private func word(endingAt end: Int) -> String {
        string(wordStart(endingAt: end)..<(end + 1))
    }

    private func string(_ range: Range<Int>) -> String {
        String(decoding: units[range], as: UTF16.self)
    }

    private static func isWord(_ unit: UInt16) -> Bool {
        (48...57).contains(unit) || (65...90).contains(unit) || (97...122).contains(unit) || unit == 95
    }

    private static func isSpace(_ unit: UInt16) -> Bool {
        unit == 32 || unit == 9 || unit == 10 || unit == 13
    }
}
