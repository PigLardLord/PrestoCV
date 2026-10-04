/// Check 2. A path a document names in a code span, when its first segment is a top-level entry of the repository,
/// must exist. A path that is planned is declared in the planned file, and a declaration that is no longer needed
/// is reported, so the list cannot go stale.
struct NamedPathCheck {
    let tree: RepositoryTree
    let planned: PlannedPaths
    /// Where the planned file is, relative to the repository root, for findings about it.
    let plannedFileName: String

    func findings(in documents: [Document]) throws(DocsCheckError) -> [Finding] {
        var findings = planned.problems.map {
            Finding(file: plannedFileName, line: $0.line, code: .plannedFileInvalid, message: "\(plannedFileName): \($0.message)")
        }
        let topLevel = try tree.topLevelEntries()
        var named: Set<String> = []
        for document in documents {
            for span in document.markdown.codeSpans {
                for path in PathRecogniser.paths(inCodeSpan: span.text, topLevel: topLevel) {
                    named.insert(path.path)
                    let kind = try tree.kind(of: path.path)
                    if let kind, kind == .directory || !path.mustBeDirectory { continue }
                    if planned.declares(path.path) { continue }
                    let problem = kind == nil ? "does not exist" : "is a file, not a directory"
                    findings.append(Finding(file: document.path, line: span.line, code: .pathMissing, message: "`\(path.path)` \(problem)"))
                }
            }
        }
        for entry in planned.entries {
            if try tree.kind(of: entry.path) != nil {
                findings.append(Finding(file: plannedFileName, line: entry.line, code: .plannedPathExists,
                                        message: "`\(entry.path)` exists now, so it is no longer planned (ticket #\(entry.ticket)): remove its entry"))
            } else if !named.contains(entry.path) {
                findings.append(Finding(file: plannedFileName, line: entry.line, code: .plannedPathUnused,
                                        message: "no document names `\(entry.path)` (ticket #\(entry.ticket)): remove its entry"))
            }
        }
        return findings
    }
}
