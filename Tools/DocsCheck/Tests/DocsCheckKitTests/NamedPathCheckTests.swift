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

    @Test("every kind of document is read, and a path is relative to the repository, not to the document")
    func relativeToTheRepository() throws {
        let result = try findings(in: ["docs/a.md": "`Tools/run.sh` `run.sh`", "Tools/run.sh": "", "Tools/README.md": "`Tools/gone.sh` `gone.sh`"])
        #expect(result == ["Tools/README.md:1 path-missing"])
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

    @Test("a planned file that is not a list of paths with tickets is a finding", arguments: [
        "not json", #"{"path": "Tools/new", "ticket": 1}"#, #"[{"path": "Tools/new"}]"#, #"[{"ticket": 1}]"#, #"[{"path": "Tools/new", "ticket": 0}]"#,
        #"[{"path": "Tools/new", "ticket": "12"}]"#, #"[{"path": "", "ticket": 1}]"#, #"[{"path": "/Tools/new", "ticket": 1}]"#,
        #"[{"path": "Tools/../new", "ticket": 1}]"#, #"[{"path": "Tools/*.sh", "ticket": 1}]"#,
    ])
    func invalidPlannedFile(planned: String) throws {
        let result = try findings(in: ["README.md": "Nothing.", "Tools/run.sh": ""], planned: planned)
        #expect(result.contains { $0.hasSuffix(" planned-file-invalid") })
    }

    @Test("a planned file that cannot be read is an error, never a pass")
    func missingPlannedFile() throws {
        try withRepository(["README.md": "x"]) { root in
            #expect(throws: (any Error).self) {
                try DocumentationChecker(root: root, plannedFile: root.appendingPathComponent("missing.json")).run()
            }
        }
    }
}
