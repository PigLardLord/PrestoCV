import Foundation

public struct DesignManifest: Codable, Sendable, Equatable {
    public var id: String, name: String, version: String, description: String
    /// Version of the markup contract the design's CSS was written for (ADR 0011).
    public var markupContract: Int
    public init(id: String, name: String, version: String, description: String, markupContract: Int = MarkupContract.version) {
        self.id = id; self.name = name; self.version = version; self.description = description; self.markupContract = markupContract
    }
    /// The one rule for design identifiers: lowercase ASCII letters, digits and hyphens, 1–64 characters. Stores use it
    /// before touching storage, so an identifier can never name a path.
    public static func isValidID(_ id: String) -> Bool { id.fullyMatches(#"[a-z0-9-]{1,64}"#) }
}

public enum DesignPackageViolation: Equatable, Sendable, CustomStringConvertible {
    case tooLarge(Int), malformed(String), unknownKeys([String]), containsHTML, invalidID(String),
         unsupportedContract(Int), css(String), invalidPreview(String)
    public var description: String {
        switch self {
        case .tooLarge(let n): "package too large: \(n) bytes"
        case .malformed(let r): "malformed package: \(r)"
        case .unknownKeys(let k): "unknown keys: \(k)"
        case .containsHTML: "package ships HTML"
        case .invalidID(let id): "invalid id \(id)"
        case .unsupportedContract(let v): "unsupported markup contract \(v)"
        case .css(let reason): "stylesheet rejected: \(reason)"
        case .invalidPreview(let r): "invalid preview: \(r)"
        }
    }
}

/// A design that passed every check. Only the validator creates one.
public struct ValidatedDesign: Sendable, Equatable {
    public let manifest: DesignManifest
    public let stylesheet: ValidatedStylesheet
    public let previewPNG: Data?
}

/// CSS that passed validation. Only the validator can create one (internal init), so rendering
/// cannot receive unvalidated CSS: ValidatingBoundary enforced by the type system.
public struct ValidatedStylesheet: Sendable, Equatable {
    public let css: String
    init(css: String) { self.css = css }
}

public struct DesignPackageRejected: Error, Equatable { public let violations: [DesignPackageViolation] }
