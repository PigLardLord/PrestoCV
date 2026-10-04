import DocsCheckKit
import Foundation

// DocsCheck <root> [--planned <planned.json>] [--known-top-level <names.txt>]...
// Prints one finding per line, sorted, then a summary line. Exit status: 0 no findings, 1 findings, 2 the check could not run.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(2)
}

let usage = "usage: DocsCheck <root> [--planned <planned.json>] [--known-top-level <names.txt>]..."
var arguments = Array(CommandLine.arguments.dropFirst())
var plannedPath: String?
var knownTopLevelPaths: [String] = []
while let flag = arguments.firstIndex(where: { $0 == "--planned" || $0 == "--known-top-level" }) {
    guard flag + 1 < arguments.count else { fail("\(arguments[flag]) needs a path") }
    if arguments[flag] == "--planned" { plannedPath = arguments[flag + 1] } else { knownTopLevelPaths.append(arguments[flag + 1]) }
    arguments.removeSubrange(flag...(flag + 1))
}
guard arguments.count == 1 else { fail(usage) }

do {
    let report = try DocumentationChecker(
        root: URL(fileURLWithPath: arguments[0]),
        plannedFile: plannedPath.map { URL(fileURLWithPath: $0) },
        knownTopLevelFiles: knownTopLevelPaths.map { URL(fileURLWithPath: $0) }
    ).run()
    for finding in report.findings { print(finding) }
    print("checked \(report.documentCount) documents: \(report.findings.count) findings")
    exit(report.findings.isEmpty ? 0 : 1)
} catch {
    fail(error.description)
}
