/// Check 2. A path a document names in a code span, when its first segment is a top-level entry of the repository
/// or it ends in a known file extension, must exist, from the repository root or from the directory of the document
/// or one above it. A path that is planned is declared in the planned file, as a path from the repository root, and
/// an entry that excuses nothing now, or whose file exists, is reported, so the list cannot go stale.
struct NamedPathCheck {
    let tree: RepositoryTree
    let planned: PlannedPaths
    /// Where the planned file is, relative to the repository root, for findings about it.
    let plannedFileName: String
    /// Names that count as top-level entries although they may no longer be: see `DocumentationChecker`.
    var knownTopLevel: Set<String> = []

    func findings(in documents: [Document]) throws(DocsCheckError) -> [Finding] {
        var findings = planned.problems.map {
            Finding(file: plannedFileName, line: $0.line, code: .plannedFileInvalid, message: "\(plannedFileName): \($0.message)")
        }
        let topLevel = try tree.topLevelEntries().union(knownTopLevel)
        var excused: Set<String> = []
        for document in documents {
            for span in document.markdown.codeSpans {
                for path in PathRecogniser.paths(inCodeSpan: span.text, topLevel: topLevel) {
                    let places = Self.places(of: path.path, in: document.path)
                    var existsAsFile = false
                    var found = false
                    for place in places {
                        switch try tree.kind(of: place) {
                        case .directory?: found = true
                        case .file?: if path.mustBeDirectory { existsAsFile = true } else { found = true }
                        case nil: break
                        }
                    }
                    if found { continue }
                    if let declared = places.first(where: planned.declares) {
                        excused.insert(declared)
                        continue
                    }
                    let problem = existsAsFile ? "is a file, not a directory"
                        : places.count > 1 ? "does not exist from the repository root, nor from the directory of its document or those above it"
                        : "does not exist"
                    findings.append(Finding(file: document.path, line: span.line, code: .pathMissing, message: "\(Finding.quoted(path.path)) \(problem)"))
                }
            }
        }
        for entry in planned.entries {
            if try tree.kind(of: entry.path) != nil {
                findings.append(Finding(file: plannedFileName, line: entry.line, code: .plannedPathExists,
                                        message: "\(Finding.quoted(entry.path)) exists now, so it is no longer planned (ticket #\(entry.ticket)): remove its entry"))
            } else if !excused.contains(entry.path) {
                findings.append(Finding(file: plannedFileName, line: entry.line, code: .plannedPathUnused,
                                        message: "no document names \(Finding.quoted(entry.path)) (ticket #\(entry.ticket)): remove its entry"))
            }
        }
        return findings
    }

    /// The paths a name can mean: as written, from the root, and from the directory of the document and each directory
    /// above it, so that a package's README can name `Sources/X.swift` from the package root.
    private static func places(of path: String, in document: String) -> [String] {
        var places = [path]
        var directory = document.split(separator: "/").dropLast().map(String.init)
        while !directory.isEmpty {
            if let beside = RepositoryPath.resolve(path, from: directory.joined(separator: "/") + "/x"), beside != path { places.append(beside) }
            directory.removeLast()
        }
        return places
    }
}
