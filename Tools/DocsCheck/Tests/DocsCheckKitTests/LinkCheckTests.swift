import Foundation
import Testing
@testable import DocsCheckKit

@Suite("Check 1 · links")
struct LinkCheckTests {
    @Test("a relative link to a file or a directory that exists passes")
    func existingTargets() throws {
        let result = try findings(in: [
            "README.md": "[a](docs/a.md) [dir](docs/) [dir2](docs) [tool](Tools/run.sh)",
            "docs/a.md": "back to [root](../README.md) and [self](a.md)",
            "Tools/run.sh": "",
        ])
        #expect(result == [])
    }

    @Test("a link to a file that does not exist is a finding at its line")
    func missingFile() throws {
        let result = try findings(in: ["README.md": "Intro\n\nSee [gone](docs/gone.md) and [here](docs/a.md).", "docs/a.md": ""])
        #expect(result == ["README.md:3 link-target-missing"])
    }

    @Test("a link is resolved from the directory of the file that holds it")
    func relativeToTheFile() throws {
        let result = try findings(in: ["docs/sub/b.md": "[ok](../a.md) [bad](a.md)", "docs/a.md": ""])
        #expect(result == ["docs/sub/b.md:1 link-target-missing"])
    }

    @Test("a link that starts with a slash is resolved from the repository root")
    func rootRelative() throws {
        let result = try findings(in: ["docs/sub/b.md": "[ok](/docs/a.md) [bad](/a.md)", "docs/a.md": ""])
        #expect(result == ["docs/sub/b.md:1 link-target-missing"])
    }

    @Test("a link that leaves the repository does not resolve")
    func outsideTheRepository() throws {
        #expect(try findings(in: ["README.md": "[up](../outside.md) [deep](docs/../../x.md)"]) == ["README.md:1 link-target-missing", "README.md:1 link-target-missing"])
    }

    @Test("a trailing slash means a directory, so a file does not satisfy it")
    func trailingSlash() throws {
        #expect(try findings(in: ["README.md": "[f](docs/a.md/) [d](docs/)", "docs/a.md": ""]) == ["README.md:1 link-target-missing"])
    }

    @Test("a file name is matched with its exact case, as on GitHub")
    func exactCase() throws {
        #expect(try findings(in: ["README.md": "[a](docs/A.md) [b](Docs/a.md) [c](docs/a.md)", "docs/a.md": ""])
                == ["README.md:1 link-target-missing", "README.md:1 link-target-missing"])
    }

    @Test("percent-encoding and a query string do not change the file")
    func encodingAndQuery() throws {
        #expect(try findings(in: ["README.md": "[a](docs/a%20b.md) [b](docs/a.md?plain=1) [c](docs/a%2Fb.md)", "docs/a b.md": "", "docs/a.md": ""])
                == ["README.md:1 link-target-missing"])
    }

    @Test("external links are not followed", arguments: ["https://example.com/x", "http://example.com", "mailto:a@b.c", "//example.com/x", "tel:+390000", "ftp://h/f"])
    func externalLinks(destination: String) throws {
        #expect(try findings(in: ["README.md": "[x](\(destination))"]) == [])
    }

    @Test("an anchor in the same file must be a heading of it")
    func sameFileAnchor() throws {
        let result = try findings(in: ["README.md": "# Title\n\n[ok](#title) [bad](#nothing) [top](#) [bare](README.md#title)\n\n## Section `x`\n[ok](#section-x)"])
        #expect(result == ["README.md:3 link-anchor-missing"])
    }

    @Test("an anchor into another Markdown file must be one of its headings, numbered when it repeats")
    func otherFileAnchor() throws {
        let result = try findings(in: [
            "README.md": "[a](docs/a.md#install) [b](docs/a.md#install-1) [c](docs/a.md#install-2) [d](docs/a.md#città)",
            "docs/a.md": "# Install\n## Install\n## Città",
        ])
        #expect(result == ["README.md:1 link-anchor-missing"])
    }

    @Test("an anchor is matched after percent-decoding, and as written")
    func anchorEncoding() throws {
        let result = try findings(in: ["README.md": "[ok](docs/a.md#citt%C3%A0) [wrong case](docs/a.md#Città)", "docs/a.md": "## Città"])
        #expect(result == ["README.md:1 link-anchor-missing"])
    }

    @Test("a link with plain=1 shows the file's source, so its anchor is a line and is not checked")
    func plainView() throws {
        let result = try findings(in: [
            "README.md": "[a](docs/a.md?plain=1#L10) [b](docs/a.md?x=1&plain=1#L2-L4) [c](docs/a.md?plain=1#nothing) [d](docs/a.md?plain=0#nothing) [e](docs/a.md?x=1#nothing) [f](docs/gone.md?plain=1#L1)",
            "docs/a.md": "# A",
        ])
        #expect(result == ["README.md:1 link-anchor-missing", "README.md:1 link-anchor-missing", "README.md:1 link-target-missing"])
    }

    @Test("an anchor into a file that is not Markdown or into a directory is not checked")
    func anchorElsewhere() throws {
        #expect(try findings(in: ["README.md": "[a](Tools/run.sh#L10) [b](docs/#top)", "Tools/run.sh": "", "docs/x.txt": ""]) == [])
    }

    @Test("a missing target is reported once, without an anchor finding")
    func missingTargetWithAnchor() throws {
        #expect(try findings(in: ["README.md": "[a](docs/gone.md#x)"]) == ["README.md:1 link-target-missing"])
    }

    @Test("links in link definitions are checked")
    func definitions() throws {
        #expect(try findings(in: ["README.md": "[a][x]\n\n[x]: docs/gone.md"]) == ["README.md:3 link-target-missing"])
    }

    @Test("only docs/, README files and AGENTS.md are read, and nothing under .build or .git")
    func scope() throws {
        let broken = "[x](gone.md)"
        let result = try findings(in: [
            "AGENTS.md": broken + "\n\nDocumentation changes with the code in the same pull request.", "README.md": broken, "docs/deep/er/a.md": broken, "Package/README.md": broken,
            "Notes.md": broken, "Other/ROADMAP.md": broken, "docs/readme.txt": broken,
            "Tools/X/.build/checkouts/dep/README.md": broken, ".git/README.md": broken, "docs/.build/a.md": broken,
        ])
        #expect(result == ["AGENTS.md:1 link-target-missing", "Package/README.md:1 link-target-missing", "README.md:1 link-target-missing", "docs/deep/er/a.md:1 link-target-missing"])
    }

    @Test("a symbolic link to a directory is not followed, so a cycle cannot hang the walk")
    func symbolicLinks() throws {
        try withRepository(acceptedBaseline.merging(["README.md": "[a](docs/a.md)", "docs/a.md": "[x](gone.md)"]) { _, test in test }) { root in
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("docs/loop"), withDestinationURL: root)
            let report = try DocumentationChecker(root: root).run()
            #expect(report.findings.filter { $0.code == .linkTargetMissing }.map(\.file) == ["docs/a.md"])
        }
    }

    @Test("the pull request template is a document: its links and the paths in its code spans are checked")
    func templateIsADocument() throws {
        let template = "## Purpose\n\nSee [the rules](docs/gone.md) and `docs/architecture/missing.md`.\n\n## Documents updated\n\nWhich?"
        #expect(try findings(in: [".github/pull_request_template.md": template])
                == [".github/pull_request_template.md:3 link-target-missing", ".github/pull_request_template.md:3 path-missing"])
        #expect(try findings(in: ["README.md": "x", ".github/other.md": "[a](gone.md)"]) == [])
    }

    @Test("findings are sorted by file, then line")
    func ordering() throws {
        let result = try findings(in: ["docs/b.md": "x\n[a](1.md)\n[b](2.md)", "docs/a.md": "[a](1.md)", "README.md": "[a](1.md)"])
        #expect(result == ["README.md:1 link-target-missing", "docs/a.md:1 link-target-missing", "docs/b.md:2 link-target-missing", "docs/b.md:3 link-target-missing"])
    }
}
