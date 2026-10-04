import DocsCheckKit
import Foundation

// DocsCheck <root> [--planned <planned.json>]
// Prints one finding per line, sorted, then a summary line. Exit status: 0 no findings, 1 findings, 2 the check could not run.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(2)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var plannedPath: String?
if let flag = arguments.firstIndex(of: "--planned") {
    guard flag + 1 < arguments.count else { fail("--planned needs a path") }
    plannedPath = arguments[flag + 1]
    arguments.removeSubrange(flag...(flag + 1))
}
guard arguments.count == 1 else { fail("usage: DocsCheck <root> [--planned <planned.json>]") }

do {
    let report = try DocumentationChecker(
        root: URL(fileURLWithPath: arguments[0]),
        plannedFile: plannedPath.map { URL(fileURLWithPath: $0) }
    ).run()
    for finding in report.findings { print(finding) }
    print("checked \(report.documentCount) documents: \(report.findings.count) findings")
    exit(report.findings.isEmpty ? 0 : 1)
} catch {
    fail(error.description)
}
