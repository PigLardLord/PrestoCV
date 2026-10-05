import SwiftSyntax

/// The thresholds of `CleanFunctions`, `CleanTypes` and `ISP` (ADR 0021 (c)). A measure above its limit is a finding.
enum Limits {
    static let functionLines = 20
    static let nesting = 2
    static let complexity = 5
}

extension Hit {
    /// A finding of a measuring detector. Its detail names the construct and stands for it in the fingerprint.
    init(measured detector: String, _ detail: String, line: Int) {
        self.init(detector: detector, detail: detail, node: detail, line: line, packageTarget: nil)
    }
}

/// Runs the detectors that measure the size and shape of code, and the one that reads its comments.
enum Measurements {
    static let detectors: Set<String> = ["functionLength", "nestingDepth", "cyclomaticComplexity"]

    static func hits(of tree: SourceFileSyntax, file: String) -> [Hit] {
        let lines = CodeLines(converter: SourceLocationConverter(fileName: file, tree: tree))
        let length = BodyLengthVisitor(lines: lines)
        let shape = BodyShapeVisitor(lines: lines)
        length.walk(tree)
        shape.walk(tree)
        return length.hits + shape.hits
    }
}
