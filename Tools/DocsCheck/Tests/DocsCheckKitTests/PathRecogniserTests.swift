import Testing
@testable import DocsCheckKit

@Suite("Check 2 · recognising a named path")
struct PathRecogniserTests {
    private static let topLevel: Set<String> = ["Tools", "docs", "PrestoCVCore", ".github", "AGENTS.md", "PrestoCV.xcodeproj"]

    private func paths(_ span: String) -> [String] {
        PathRecogniser.paths(inCodeSpan: span, topLevel: Self.topLevel).map(\.path)
    }

    @Test("a path whose first segment is a top-level entry is recognised", arguments: [
        ("Tools/DocsCheck/check.sh", "Tools/DocsCheck/check.sh"),
        ("docs/architecture/rules.md", "docs/architecture/rules.md"),
        (".github/workflows/ci.yml", ".github/workflows/ci.yml"),
        ("PrestoCVCore/Sources/PrestoCVDomain", "PrestoCVCore/Sources/PrestoCVDomain"),
        ("AGENTS.md", "AGENTS.md"),
        ("PrestoCV.xcodeproj", "PrestoCV.xcodeproj"),
        ("Tools/Info+Debug@2x.png", "Tools/Info+Debug@2x.png"),
    ])
    func recognised(span: String, path: String) {
        #expect(paths(span) == [path])
    }

    @Test("a trailing slash makes the path a directory")
    func directory() {
        let named = PathRecogniser.paths(inCodeSpan: "docs/architecture/", topLevel: Self.topLevel)
        #expect(named == [NamedPath(path: "docs/architecture", mustBeDirectory: true)])
        #expect(PathRecogniser.paths(inCodeSpan: "docs/a.md", topLevel: Self.topLevel) == [NamedPath(path: "docs/a.md", mustBeDirectory: false)])
    }

    @Test("a line number, a column or an anchor after the path is not part of it", arguments: [
        "Tools/x.swift:10", "Tools/x.swift:10:3", "Tools/x.swift:10-20", "Tools/x.swift#L10", "Tools/x.swift#L10-L20", "Tools/x.swift#section",
    ])
    func locationSuffix(span: String) {
        #expect(paths(span) == ["Tools/x.swift"])
    }

    @Test("every word of a command that names a path is checked", arguments: [
        ("Tools/DocsCheck/check.sh --against base.json", ["Tools/DocsCheck/check.sh"]),
        ("swift test --package-path Tools/DocsCheck", ["Tools/DocsCheck"]),
        ("xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV", ["PrestoCV.xcodeproj"]),
        ("docs/ and Tools/", ["docs", "Tools"]),
    ])
    func commands(span: String, expected: [String]) {
        #expect(paths(span) == expected)
    }

    @Test("placeholders, globs and ellipses are skipped", arguments: [
        "Tools/<name>/x", "docs/*.md", "docs/**/x.md", "Tools/{a,b}.swift", "Tools/…", "Tools/.../x", "docs/adr/00?? .md", "Tools/[a-z].md",
        "Tools/$HOME/x", "Tools/x(1).md", "Tools/a|b",
    ])
    func placeholders(span: String) {
        #expect(paths(span) == [])
    }

    @Test("a path under the home directory or the file system root is skipped", arguments: ["~/Tools/x", "/Tools/x", "/docs", "~", "../Tools/x", "./Tools/x", "Tools/../docs/x"])
    func absolutePaths(span: String) {
        #expect(paths(span) == [])
    }

    @Test("a word with a slash that ends in a known file extension is a path, whatever its first segment", arguments: [
        "Sources/Core/File.swift", "a/b.md", "a/b.json", "a/b.mjs", "a/b.js", "a/b.sh", "a/b.yml", "a/b.yaml", "a/b.css", "a/b.html", "a/b.txt", "a/b.csv",
        "Server/Package.swift", "Sources/X.swift:10", "Sources/X.swift#L3", ".hidden/x.yml", "other/docs/x.md",
    ])
    func byExtension(span: String) {
        let found = PathRecogniser.paths(inCodeSpan: span, topLevel: Self.topLevel)
        #expect(found.count == 1 && found[0].mustBeDirectory == false)
        #expect(found.first.map { span.hasPrefix($0.path) } == true)
    }

    @Test("an extension outside the list, a name without a slash, a host name and a glob are not paths", arguments: [
        "a/b.png", "a/b.xml", "a/b.SWIFT", "a/b.MD", "a/b.Json", "a/b.md/", "b.swift", "a/.swift", "a/swift", "example.com/index.html", "www.example.org/a/b.md",
        "Sources/*.swift", "Sources/<name>.swift", "Sources/{a,b}.swift", "Sources/x.swift,", "~/a/b.md", "/a/b.md", "../a/b.md", "a/../b.md", "a/.build/b.json",
    ])
    func notByExtension(span: String) {
        #expect(paths(span) == [])
    }

    @Test("a command is read word by word, so a file in it is a path and a flag is not")
    func commandWithFile() {
        #expect(paths("swift run --package-path Tools/DocsCheck Sources/Gen.swift --out out/x.json") == ["Tools/DocsCheck", "Sources/Gen.swift", "out/x.json"])
    }

    @Test("a path through a build directory names a build product, so it is skipped", arguments: ["Tools/DocsCheck/.build", "Tools/.build/release/DocsCheck", ".build/x"])
    func buildProducts(span: String) {
        #expect(PathRecogniser.paths(inCodeSpan: span, topLevel: Self.topLevel.union([".build"])) == [])
    }

    @Test("a path whose first segment is not a top-level entry is skipped", arguments: [
        "Features/Profile", "App/", "rules.json", "tools/DocsCheck", "TOOLS/x", "other/docs/x", "Swift.fatalError", "a/b",
    ])
    func notTopLevel(span: String) {
        #expect(paths(span) == [])
    }

    @Test("a URL, an expression or a sentence is not a path", arguments: [
        "https://example.com/Tools/x", "mailto:docs/x", "name=Tools/x", "\"Tools/x\"", "'docs/a'", "Tools/x;", "docs/a,docs/b",
    ])
    func notAPath(span: String) {
        #expect(paths(span) == [])
    }
}
