import SwiftSyntax

/// `fileLength`: the code lines of the whole file, all types and extensions together.
enum FileLength {
    static func hits(of tree: SourceFileSyntax, lines: CodeLines) -> [Hit] {
        let count = lines.count(in: tree)
        guard count > Limits.fileLines else { return [] }
        return [Hit(measured: "fileLength", "the file has \(count) lines of code, at most \(Limits.fileLines)", line: 1)]
    }
}
