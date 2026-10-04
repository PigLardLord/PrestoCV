import Foundation
import Testing
@testable import DocsCheckKit

@Suite("Check 2 · named paths")
struct NamedPathCheckTests {
    private let tools = ["Tools/run.sh": "", "Tools/DocsCheck/planned.json": "[]"]

    @Test("a named path that exists passes, whether it is a file or a directory")
    func existing() throws {
        let result = try findings(in: ["README.md": "`Tools/run.sh`, `Tools/` and `Tools/run.sh:3` and `docs/a.md#top`.", "docs/a.md": ""].merging(tools) { a, _ in a })
        #expect(result == [])
    }

    @Test("a named path that does not exist is a finding at the line of its code span")
    func missing() throws {
        let result = try findings(in: ["README.md": "Intro\n\nRun `Tools/gone.sh` or `Tools/run.sh`.\n`docs/old/` too", "Tools/run.sh": "", "docs/a.md": ""])
        #expect(result == ["README.md:3 path-missing", "README.md:4 path-missing"])
    }

    @Test("a directory path needs a directory")
    func directoryNeeded() throws {
        #expect(try findings(in: ["README.md": "`Tools/run.sh/`", "Tools/run.sh": ""]) == ["README.md:1 path-missing"])
    }

    @Test("paths in fenced code, and names that are not paths, are not checked")
    func notChecked() throws {
        let readme = "```\nTools/gone.sh\n```\n`Features/Gone` `rules.json` `~/Tools/x` `Tools/<n>.md` `Tools/*.md`\nTools/gone.sh in text"
        #expect(try findings(in: ["README.md": readme, "Tools/run.sh": ""]) == [])
    }

    @Test("a path is accepted if it exists from the repository root or from the directory of its document")
    func rootOrDocumentDirectory() throws {
        let result = try findings(in: [
            "Tools/Pkg/README.md": "`docs/here.md` `docs/root.md` `docs/neither.md` `docs/` `Tools/run.sh`",
            "Tools/Pkg/docs/here.md": "", "docs/root.md": "", "Tools/run.sh": "",
        ])
        #expect(result == ["Tools/Pkg/README.md:1 path-missing"])
    }

    @Test("a path is also looked for from each directory above its document, so a package's README can name Sources/X.swift")
    func directoriesAbove() throws {
        let result = try findings(in: [
            "Pkg/Tools/Gen/README.md": "`Sources/Here.swift` `Sources/Gone.swift` `Sources/Root.swift`",
            "Pkg/Sources/Here.swift": "", "Sources/Root.swift": "",
        ])
        #expect(result == ["Pkg/Tools/Gen/README.md:1 path-missing"])
    }

    @Test("a directory path needs a directory from one of the places")
    func directoryFromEitherPlace() throws {
        // `Shared` is a file at the root and a directory beside the document, so `Shared/` is satisfied beside it only.
        #expect(try findings(in: ["Pkg/README.md": "`Shared/`", "Pkg/Shared/here.md": "", "Shared": ""]) == [])
        #expect(try findings(in: ["Pkg/README.md": "`Shared/`", "Shared": ""]) == ["Pkg/README.md:1 path-missing"])
    }

    @Test("a path in a document at the root has only the root to be looked for in")
    func documentAtTheRoot() throws {
        #expect(try findings(in: ["README.md": "`docs/here.md` `docs/gone.md`", "docs/here.md": ""]) == ["README.md:1 path-missing"])
    }

    @Test("a path that leaves the repository from the document's directory is not found there")
    func leavingTheRepository() throws {
        #expect(try findings(in: ["README.md": "`Tools/x.sh`", "Tools/README.md": "`Tools/y.sh`", "Tools/x.sh": ""]) == ["Tools/README.md:1 path-missing"])
    }

    @Test("a path in the text of a link is checked like any other")
    func linkText() throws {
        #expect(try findings(in: ["README.md": "[`Tools/gone.sh`](Tools/run.sh)", "Tools/run.sh": ""]) == ["README.md:1 path-missing"])
    }

    // MARK: Planned paths

    @Test("a missing path that is declared as planned is not a finding")
    func planned() throws {
        let planned = #"[{"path": "Tools/new.sh", "ticket": 12}, {"path": "docs/future/", "ticket": 13}]"#
        let result = try findings(in: ["README.md": "`Tools/new.sh` and `docs/future`.", "Tools/run.sh": "", "docs/a.md": ""], planned: planned)
        #expect(result == [])
    }

    @Test("a planned path that now exists is a finding, at its line in the planned file")
    func plannedExists() throws {
        let planned = "[\n  {\"path\": \"Tools/new.sh\", \"ticket\": 12},\n  {\"path\": \"Tools/run.sh\", \"ticket\": 13}\n]"
        let result = try findings(in: ["README.md": "`Tools/new.sh` `Tools/run.sh`", "Tools/run.sh": ""], planned: planned)
        #expect(result == ["planned.json:3 planned-path-exists"])
    }

    @Test("a planned path that no document names any more is a finding")
    func plannedUnused() throws {
        let planned = "[\n  {\"path\": \"Tools/new.sh\", \"ticket\": 12}\n]"
        #expect(try findings(in: ["README.md": "Nothing here.", "Tools/run.sh": ""], planned: planned) == ["planned.json:2 planned-path-unused"])
    }

    @Test("a planned path covers only the path it names")
    func plannedIsExact() throws {
        let planned = #"[{"path": "Tools/new", "ticket": 12}]"#
        #expect(try findings(in: ["README.md": "`Tools/new` `Tools/new/x.sh` `Tools/other`", "Tools/run.sh": ""], planned: planned)
                == ["README.md:1 path-missing", "README.md:1 path-missing"])
    }

    @Test("a planned path is matched as written or from the directory of the document that names it")
    func plannedFromTheDocumentDirectory() throws {
        let planned = #"[{"path": "Tools/Pkg/docs/new.md", "ticket": 12}, {"path": "docs/other.md", "ticket": 13}]"#
        let result = try findings(in: ["Tools/Pkg/README.md": "`docs/new.md` `docs/other.md`", "docs/a.md": ""], planned: planned)
        #expect(result == [])
        let unused = try findings(in: ["Tools/Pkg/README.md": "`docs/new.md`", "docs/a.md": ""], planned: planned)
        #expect(unused == ["planned.json:1 planned-path-unused"])
    }

    @Test("a planned file that is not a list of paths with tickets is a finding", arguments: [
        "not json", #"{"path": "Tools/new", "ticket": 1}"#, #"[{"path": "Tools/new"}]"#, #"[{"ticket": 1}]"#, #"[{"path": "Tools/new", "ticket": 0}]"#,
        #"[{"path": "Tools/new", "ticket": "12"}]"#, #"[{"path": "", "ticket": 1}]"#, #"[{"path": "/Tools/new", "ticket": 1}]"#,
        #"[{"path": "Tools/../new", "ticket": 1}]"#, #"[{"path": "Tools/*.sh", "ticket": 1}]"#,
    ])
    func invalidPlannedFile(planned: String) throws {
        let result = try findings(in: ["README.md": "Nothing.", "Tools/run.sh": ""], planned: planned)
        #expect(result.contains { $0.hasSuffix(" planned-file-invalid") })
    }
}
