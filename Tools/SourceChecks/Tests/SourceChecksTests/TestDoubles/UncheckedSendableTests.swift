import Testing
import Foundation

/// R10 (docs/architecture/rules.md): test doubles use `Mutex`, not `@unchecked Sendable`. A `Mutex` makes the compiler check
/// what `@unchecked Sendable` and a lock leave to the author, and a double written with it needs no promise that it is safe.
///
/// The tests that were written before the rule still have some. The list names each by its file and its type, and it only
/// shrinks: a type that is not on it is refused, even in a file that is, and a type that is on it and is gone leaves it.
@Suite("Test doubles - a Mutex, not @unchecked Sendable")
struct UncheckedSendableTests {

    // MARK: - The list

    /// A type of the app's tests declared `@unchecked Sendable`: its file, from the root of the repository, and its name
    struct Declaration: Hashable, CustomStringConvertible {
        let file: String
        let type: String

        var description: String { "\(type) in \(file)" }
    }

    private static let legacy: [Declaration] = [
        ("PrestoCVTests/Features/CVEditor/ElementBindingTests.swift", ["Names"]),
        ("PrestoCVTests/Features/CVList/CVListRowTextTests.swift", ["TestClock", "TestZone"]),
        ("PrestoCVTests/Features/CVList/CVListViewModelUnreadableTests.swift", ["StubListingUseCase"]),
        ("PrestoCVTests/Features/Import/ImportViewModelTests.swift", ["RemovedFiles"]),
    ].flatMap { file, types in types.map { Declaration(file: file, type: $0) } }

    // MARK: - Reading and comparing

    /// The name of an `@unchecked` that no type's header holds
    static let noType = "(no type)"

    /// `@unchecked` is written in code for one reason, a conformance that the compiler does not check, and it may be followed by
    /// `Sendable` in any spelling (`Swift.Sendable`, a comment or a line break in between)
    private static let unchecked = try! NSRegularExpression(pattern: #"@unchecked\b"#)

    /// A type's header, from its keyword to its `@unchecked` with no brace in between: a conformance is written there.
    /// A keyword that ends a word or follows a dot (`value.class`) is not one.
    private static let header = try! NSRegularExpression(pattern: #"(?<![\p{L}\p{N}_.])(?:class|struct|enum|actor|extension)\s+([\p{L}_][\p{L}\p{N}_.]*)[^{}]*?@unchecked\b"#)

    /// The names of the types a source declares `@unchecked Sendable`, in the order they are written, read from its code: a
    /// comment or a string that names it declares nothing. An `@unchecked` that no type's header holds is counted under
    /// `noType`, so that it is refused and never lost.
    static func declared(in source: String) -> [String] {
        let text = SwiftCode(source).skeleton.joined(separator: "\n")
        let whole = NSRange(text.startIndex..., in: text)
        let named = header.matches(in: text, range: whole).map { NSString(string: text).substring(with: $0.range(at: 1)) }
        return named + Array(repeating: noType, count: unchecked.numberOfMatches(in: text, range: whole) - named.count)
    }

    /// The declarations of the files that the list does not hold (`new`), and those of the list that no file declares any
    /// more (`stale`). A type declared twice is listed twice.
    static func refused(in files: [RepositorySources.File], listed: [Declaration]) -> (new: [Declaration], stale: [Declaration]) {
        let found = files.flatMap { file in declared(in: file.text).map { Declaration(file: file.path, type: $0) } }
        return (remaining(found, without: listed), remaining(listed, without: found))
    }

    /// `all` without one occurrence of each of `taken`
    private static func remaining(_ all: [Declaration], without taken: [Declaration]) -> [Declaration] {
        var rest = taken
        return all.filter { declaration in
            guard let index = rest.firstIndex(of: declaration) else { return true }
            rest.remove(at: index)
            return false
        }
    }

    private static func appTests() throws -> [RepositorySources.File] {
        let files = try RepositorySources.swiftFiles(in: "PrestoCVTests")
        try #require(!files.isEmpty, "The sources of the app's tests are in the repository")
        return files
    }

    // MARK: - The app's tests

    @Test("No new test double is @unchecked Sendable: it keeps what it shares in a Mutex")
    func noNewDoubleIsUnchecked() throws {
        let new = Self.refused(in: try Self.appTests(), listed: Self.legacy).new

        #expect(new.isEmpty, "R10: use a Mutex from Synchronization, as AppLaunchViewModelTests does, in \(new)")
    }

    @Test("A type of the list still declares it: when it does not, it leaves the list")
    func theListHoldsOnlyWhatIsStillThere() throws {
        let stale = Self.refused(in: try Self.appTests(), listed: Self.legacy).stale

        #expect(stale.isEmpty, "These types no longer declare @unchecked Sendable: take them out of the list, which only shrinks: \(stale)")
    }

    // MARK: - Reading a source

    /// A name, a source, and the types it declares `@unchecked Sendable`
    static let sources: [(String, String, [String])] = [
        ("a class", "final class A: @unchecked Sendable {}", ["A"]),
        ("a class with other conformances before it", "private final class A: B, P, @unchecked Sendable {\n}", ["A"]),
        ("a header over several lines", "final class A: B,\n    P,\n    @unchecked\n    Sendable {\n}", ["A"]),
        ("a struct, an enum and an actor", "struct S: @unchecked Sendable {}\nenum E: @unchecked Sendable {}\nactor C: @unchecked Sendable {}", ["S", "E", "C"]),
        ("a name with a letter that is not ASCII and a digit", "final class Ñandú2: @unchecked Sendable {}", ["Ñandú2"]),
        ("a generic type", "final class Box<T: Hashable>: @unchecked Sendable {}", ["Box"]),
        ("an extension", "extension Box: @unchecked Sendable where T: P {}", ["Box"]),
        ("an extension of a type inside a type", "extension Outer.Inner: @unchecked Sendable {}", ["Outer.Inner"]),
        ("an extension with a retroactive conformance", "extension URL: @retroactive @unchecked Sendable {}", ["URL"]),
        ("a type inside a type", "enum Outer {\n    final class Inner: @unchecked Sendable {}\n}", ["Inner"]),
        ("two types, one after the other, with a body between", "final class A: @unchecked Sendable { let x = 1 }\nfinal class B: @unchecked Sendable {}", ["A", "B"]),
        ("a type with no conformance after one that has it", "final class A: @unchecked Sendable {}\nfinal class B: Sendable {}", ["A"]),
        ("the module in front of Sendable", "final class A: @unchecked Swift.Sendable {}", ["A"]),
        ("a comment between the two words", "final class A: @unchecked /* checked by hand */ Sendable {}", ["A"]),
        ("a line break between the two words", "final class A: @unchecked\n    Swift.Sendable {}", ["A"]),
        ("an attribute whose name starts like it", "@uncheckedFoo var x = 1\nfinal class A: Sendable {}", []),
        ("an attribute whose name starts like it, after a header", "struct S: P\n@uncheckedFoo var x = 1", []),
        ("a keyword after a dot, on the line before a type", "let kind = value.class\nfinal class A: @unchecked Sendable {}", ["A"]),
        ("a name that ends like a keyword, on the line before a type", "let value: myclass\nfinal class A: @unchecked Sendable {}", ["A"]),
        ("a type that is checked", "final class A: Sendable {}\nstruct B: P, Sendable {}", []),
        ("a line comment", "// final class A: @unchecked Sendable {}\nfinal class B {}", []),
        ("a doc comment", "/// A double that is `@unchecked Sendable`.\nfinal class B {}", []),
        ("a block comment", "/* final class A: @unchecked Sendable {} */\nfinal class B {}", []),
        ("a string", #"let name = "final class A: @unchecked Sendable {}""#, []),
        ("a multi-line string", "let text = \"\"\"\n    final class A: @unchecked Sendable {}\n    \"\"\"", []),
        ("a type after a comment that names the word", "// not @unchecked Sendable\nfinal class A: @unchecked Sendable {}", ["A"]),
        ("a use that no type's header holds", "let value: @unchecked Sendable = 1", [noType]),
    ]

    @Test("A source declares the types whose header says @unchecked Sendable, not what a comment or a string says", arguments: sources)
    func declaredTypes(name: String, source: String, types: [String]) {
        #expect(Self.declared(in: source) == types, "\(name)")
    }

    // MARK: - The list against sources

    struct Scenario: Sendable {
        let name: String
        let files: [RepositorySources.File]
        let listed: [Declaration]
        let new: [Declaration]
        let stale: [Declaration]
    }

    private static let one = "final class Names: @unchecked Sendable {}"
    private static let two = "final class Names: @unchecked Sendable {}\nfinal class Other: @unchecked Sendable {}"

    static let scenarios: [Scenario] = [
        Scenario(name: "what the list holds",
                 files: [.init(path: "A.swift", text: one)],
                 listed: [.init(file: "A.swift", type: "Names")], new: [], stale: []),
        Scenario(name: "a second type in a file of the list",
                 files: [.init(path: "A.swift", text: two)],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [.init(file: "A.swift", type: "Other")], stale: []),
        Scenario(name: "one of the two types of a file of the list is gone",
                 files: [.init(path: "A.swift", text: one)],
                 listed: [.init(file: "A.swift", type: "Names"), .init(file: "A.swift", type: "Other")],
                 new: [], stale: [.init(file: "A.swift", type: "Other")]),
        Scenario(name: "the last type of a file of the list is gone",
                 files: [.init(path: "A.swift", text: "final class Names: Sendable {}")],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [], stale: [.init(file: "A.swift", type: "Names")]),
        Scenario(name: "a type of the list renamed",
                 files: [.init(path: "A.swift", text: "final class Renamed: @unchecked Sendable {}")],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [.init(file: "A.swift", type: "Renamed")], stale: [.init(file: "A.swift", type: "Names")]),
        Scenario(name: "a type of the list moved to another file",
                 files: [.init(path: "B.swift", text: one)],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [.init(file: "B.swift", type: "Names")], stale: [.init(file: "A.swift", type: "Names")]),
        Scenario(name: "a type in a file that the list does not hold",
                 files: [.init(path: "B.swift", text: one)],
                 listed: [], new: [.init(file: "B.swift", type: "Names")], stale: []),
        Scenario(name: "a comment naming a listed type, as the only mention",
                 files: [.init(path: "A.swift", text: "// " + one)],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [], stale: [.init(file: "A.swift", type: "Names")]),
        Scenario(name: "a string naming it, in a file that the list does not hold",
                 files: [.init(path: "B.swift", text: #"let text = "@unchecked Sendable""#)],
                 listed: [], new: [], stale: []),
        Scenario(name: "a second type of the same name in a file of the list",
                 files: [.init(path: "A.swift", text: one + "\nenum Outer {\n    " + one + "\n}")],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [.init(file: "A.swift", type: "Names")], stale: []),
        Scenario(name: "a use that no type's header holds, in a file of the list",
                 files: [.init(path: "A.swift", text: one + "\nlet value: @unchecked Sendable = 1")],
                 listed: [.init(file: "A.swift", type: "Names")],
                 new: [.init(file: "A.swift", type: noType)], stale: []),
    ]

    @Test("The list names each declaration by file and type: another one is refused, and one that is gone leaves the list", arguments: scenarios)
    func listAgainstSources(scenario: Scenario) {
        let refused = Self.refused(in: scenario.files, listed: scenario.listed)

        #expect(refused.new == scenario.new, "\(scenario.name): the declarations refused as new")
        #expect(refused.stale == scenario.stale, "\(scenario.name): the entries refused as stale")
    }
}
