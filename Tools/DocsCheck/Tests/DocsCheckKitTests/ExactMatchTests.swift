import Testing
@testable import DocsCheckKit

@Suite("Names and anchors are matched exactly, as GitHub does")
struct ExactMatchTests {
    private let decomposed = "e\u{0301}"
    private let precomposed = "\u{00E9}"

    // MARK: File names

    @Test("a file name is matched with its case through the directory listing, even on a case-insensitive volume")
    func exactCaseThroughTheListing() throws {
        let tree = RepositoryTree(files: FakeFiles(contents: ["docs/a.md": "", "Tools/run.sh": ""], caseInsensitive: true))
        #expect(try tree.kind(of: "docs/a.md") == .file)
        #expect(try tree.kind(of: "docs") == .directory)
        #expect(try tree.kind(of: "docs/A.md") == nil)
        #expect(try tree.kind(of: "Docs/a.md") == nil)
        #expect(try tree.kind(of: "tools") == nil)
    }

    @Test("a link and a named path with the wrong case do not resolve on such a volume")
    func wrongCaseIsAFinding() throws {
        let fake = FakeFiles(contents: ["README.md": "[a](docs/A.md) [b](docs/a.md) `docs/A.md` `Docs/a.md` `docs/a.md`", "docs/a.md": ""], caseInsensitive: true)
        let report = try DocumentationChecker(files: fake, rootPath: "/fake", plannedFile: nil).run()
        let codes = report.findings.filter { $0.file == "README.md" }.map { "\($0.line) \($0.code.rawValue)" }
        // `Docs/a.md` is a path by its extension, and there is no `Docs` with that case.
        #expect(codes == ["1 link-target-missing", "1 path-missing", "1 path-missing"])
    }

    @Test("a file name is matched scalar by scalar: a decomposed accent is not the precomposed one")
    func scalarFileNames() throws {
        let tree = RepositoryTree(files: FakeFiles(contents: ["docs/caf\(precomposed).md": ""]))
        #expect(try tree.kind(of: "docs/caf\(precomposed).md") == .file)
        #expect(try tree.kind(of: "docs/caf\(decomposed).md") == nil)
    }

    // MARK: Anchors

    @Test("an anchor is matched scalar by scalar: a decomposed accent is not GitHub's precomposed one")
    func scalarAnchors() throws {
        let result = try findings(in: [
            "README.md": "[ok](docs/a.md#citt\(precomposed)) [wrong](docs/a.md#citte\u{0301}) [also ok](docs/b.md#citte\u{0301})",
            "docs/a.md": "## citt\(precomposed)", "docs/b.md": "## citte\u{0301}",
        ])
        #expect(result == ["README.md:1 link-anchor-missing"])
    }

    @Test("two headings that differ only in composition are different anchors, so neither is numbered")
    func scalarDuplicates() {
        let document = MarkdownDocument(text: "## \(precomposed)\n## \(decomposed)\n## \(precomposed)")
        #expect(document.anchors.map { Array($0.unicodeScalars) } == [
            Array(precomposed.unicodeScalars), Array(decomposed.unicodeScalars), Array("\(precomposed)-1".unicodeScalars),
        ])
    }
}
