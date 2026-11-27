import Foundation
import Testing

// MARK: - Modules Docs Tests

/// What `docs/architecture/modules.md` says about the tests is what the code does. The architecture checker compares the
/// table of production targets with `rules.json`, but not the bullets of the test targets nor the launch arguments of the UI
/// tests, and both fell behind the code unseen: three launch arguments and one import of `PrestoCVCompositionTests` were
/// missing from the doc.
@Suite("Modules Docs Tests")
struct ModulesDocsTests {

    private static let modulesPath = "docs/architecture/modules.md"
    private static let rulesPath = "Tools/ArchitectureCheck/rules.json"
    private static let fixturesPath = "PrestoCVApp/Sources/PrestoCVComposition/LaunchFixtures.swift"
    private static let launchArgumentsBullet = "- **UI tests and previews**"

    // MARK: Reading

    /// The texts that `pattern` captures in its first group, in `text`.
    static func captures(of pattern: String, in text: String) throws -> [String] {
        let expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// The launch arguments a source declares: every `static let …Argument = "-PrestoCVNext…"`.
    static func declaredArguments(in source: String) throws -> Set<String> {
        Set(try captures(of: #"static let \w+Argument = "(-PrestoCVNext\w+)""#, in: source))
    }

    /// The launch arguments a text names in code spans: every `` `-PrestoCVNext… ``.
    static func namedArguments(in text: String) throws -> Set<String> {
        Set(try captures(of: #"`(-PrestoCVNext\w+)"#, in: text))
    }

    /// The bullet of `text` that starts with `start`: its line and the lines that continue it, up to a blank line or the next
    /// bullet.
    static func bullet(startingWith start: String, in text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { $0.hasPrefix(start) }) else { return nil }
        var bullet = [lines[first]]
        for line in lines[(first + 1)...] {
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.hasPrefix("- ") || line.hasPrefix("#") { break }
            bullet.append(line)
        }
        return bullet.joined(separator: " ")
    }

    /// The "may import" bullets of a doc, by target: the first sentence after "may import", where the bullet lists the
    /// imports. A bullet reads `` - **`Name`** (Apple hosts) may import `A`, `B`, Testing and Foundation. … ``.
    static func mayImportLists(in text: String) throws -> [String: String] {
        let expression = try NSRegularExpression(
            pattern: #"^\s*- (?:\*\*)?`(\w+)`(?:\*\*)?(?: \([^)]*\))? may import (.*)$"#, options: [.anchorsMatchLines])
        var lists: [String: String] = [:]
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let name = Range(match.range(at: 1), in: text), let rest = Range(match.range(at: 2), in: text) else { continue }
            let list = text[rest].components(separatedBy: ". ").first ?? ""
            lists[String(text[name]), default: ""] += list
        }
        return lists
    }

    /// The imports of `allowed` that `list` does not name as a whole word.
    static func unnamed(_ allowed: [String], in list: String) throws -> [String] {
        try allowed.filter { module in
            let word = try NSRegularExpression(pattern: "(?<![A-Za-z0-9_])\(NSRegularExpression.escapedPattern(for: module))(?![A-Za-z0-9_])")
            return word.firstMatch(in: list, range: NSRange(list.startIndex..., in: list)) == nil
        }
    }

    /// The targets of `rules.json`, with what the checker lets them import.
    struct Rules: Decodable {
        struct Target: Decodable {
            let name: String
            let kind: String?
            let allowedImports: [String]
        }
        let targets: [Target]
    }

    // MARK: Checks of the repository

    @Test("modules.md names every launch argument of the UI tests, and only those")
    func launchArgumentsAreDocumented() throws {
        let declared = try Self.declaredArguments(in: Repository.text(Self.fixturesPath))
        // The pattern still finds the declarations: a rename of the constants must not empty the check.
        #expect(declared.count >= 14, "\(Self.fixturesPath) declares \(declared.count) launch arguments the pattern finds")
        let doc = try Repository.text(Self.modulesPath)
        let bullet = try #require(Self.bullet(startingWith: Self.launchArgumentsBullet, in: doc),
                                  "\(Self.modulesPath) has no bullet that starts with \"\(Self.launchArgumentsBullet)\"")
        let named = try Self.namedArguments(in: bullet)
        #expect(declared.subtracting(named).isEmpty,
                "\(Self.modulesPath) does not name these launch arguments: \(declared.subtracting(named).sorted())")
        #expect(named.subtracting(declared).isEmpty,
                "\(Self.modulesPath) names launch arguments the fixtures do not parse: \(named.subtracting(declared).sorted())")
    }

    @Test("A test target's may-import bullet in modules.md names every import rules.json allows it")
    func testBulletsNameEveryAllowedImport() throws {
        let rules = try JSONDecoder().decode(Rules.self, from: Data(Repository.text(Self.rulesPath).utf8))
        let lists = try Self.mayImportLists(in: Repository.text(Self.modulesPath))
        let documented = rules.targets.filter { $0.kind == "test" && lists[$0.name] != nil }
        // The bullets are still found: a change of their wording must not empty the check.
        #expect(documented.count >= 15, "only \(documented.count) test targets of rules.json have a may-import bullet")
        for target in documented {
            let missing = try Self.unnamed(target.allowedImports, in: lists[target.name] ?? "")
            #expect(missing.isEmpty, "the bullet of \(target.name) in \(Self.modulesPath) does not name \(missing)")
        }
    }

    // MARK: Checks of the reading

    @Test("Arguments are read from their declarations and from code spans only")
    func readsArguments() throws {
        let source = #"static let seedArgument = "-PrestoCVNextSeed"\n let other = "-PrestoCVNextHidden""#
        #expect(try Self.declaredArguments(in: source) == ["-PrestoCVNextSeed"])
        #expect(try Self.namedArguments(in: "(`-PrestoCVNextSeed <base 64>`, -PrestoCVNextBare)") == ["-PrestoCVNextSeed"])
    }

    @Test("A may-import list is the bullet's first sentence, and a module is named only as a whole word")
    func readsMayImportLists() throws {
        let doc = """
            - **`ATests`** (Apple hosts) may import `A`, `ATestSupport`, Testing and Foundation. They use `B` through `A`.
              - `Nested` may import `C`.
            - `Other` holds things.
            """
        let lists = try Self.mayImportLists(in: doc)
        #expect(Set(lists.keys) == ["ATests", "Nested"])
        let list = try #require(lists["ATests"])
        #expect(try Self.unnamed(["A", "ATestSupport", "Testing", "Foundation"], in: list).isEmpty)
        #expect(try Self.unnamed(["B", "ATest", "Test"], in: list) == ["B", "ATest", "Test"])
    }

    @Test("A bullet runs to the next bullet or a blank line")
    func readsBullet() {
        let doc = "- **UI tests and previews** use `-PrestoCVNextSeed`\n  and `-PrestoCVNextTips`.\n- **Next** `-PrestoCVNextOther`\n"
        #expect(Self.bullet(startingWith: "- **UI tests and previews**", in: doc)
                == "- **UI tests and previews** use `-PrestoCVNextSeed`   and `-PrestoCVNextTips`.")
        #expect(Self.bullet(startingWith: "- **Missing**", in: doc) == nil)
    }
}
