/// What a check can report. The raw value is the code printed in the report and documented in the README.
public enum FindingCode: String, CaseIterable, Sendable {
    case linkTargetMissing = "link-target-missing"
    case linkAnchorMissing = "link-anchor-missing"
}

/// One place where a document and the repository disagree.
public struct Finding: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The path of the document, relative to the repository root.
    public let file: String
    public let line: Int
    public let code: FindingCode
    public let message: String

    public var description: String { "\(file):\(line): \(code.rawValue): \(message)" }

    public static func < (lhs: Finding, rhs: Finding) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.code != rhs.code { return lhs.code.rawValue < rhs.code.rawValue }
        return lhs.message < rhs.message
    }
}
