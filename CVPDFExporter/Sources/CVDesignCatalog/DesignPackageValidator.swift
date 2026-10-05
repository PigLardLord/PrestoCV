import Foundation

/// Anti-corruption layer for design packages (ValidatingBoundary). Works on the raw bytes: size first, then a strict
/// decode (unknown keys and any `htmlContent` key are rejected), then id, contract, CSS and preview.
public struct DesignPackageValidator: Sendable {
    /// The largest package accepted, in bytes. It is checked before anything is parsed.
    public var maxBytes: Int
    /// The largest preview PNG accepted, in bytes after decoding.
    public var maxPreviewBytes: Int

    public init(maxBytes: Int = 512 * 1024, maxPreviewBytes: Int = 256 * 1024) { self.maxBytes = maxBytes; self.maxPreviewBytes = maxPreviewBytes }

    /// Checks a package and returns the design it holds.
    ///
    /// - Parameter data: the bytes of a `.mcvt` file, which are never trusted.
    /// - Throws: `DesignPackageRejected` with every violation found. A package that is too large, is not JSON or has no
    ///   manifest is rejected for that reason alone; one whose manifest or CSS text cannot be read is rejected for it
    ///   together with the key violations found before.
    public func validate(_ data: Data) throws(DesignPackageRejected) -> ValidatedDesign {
        let package = try RawPackage(data, maxBytes: maxBytes)
        var review = PackageReview(maxPreviewBytes: maxPreviewBytes)
        review.checkKeys(of: package)
        guard let manifest = package.decodedManifest else { throw review.rejection(adding: .malformed("manifest")) }
        guard let css = package.object["cssContent"] as? String else { throw review.rejection(adding: .malformed("cssContent")) }
        review.checkManifest(manifest)
        review.checkStylesheet(css)
        review.checkPreview(package.object["previewImageBase64"])
        guard review.violations.isEmpty, let stylesheet = review.stylesheet else { throw DesignPackageRejected(violations: review.violations) }
        return ValidatedDesign(manifest: manifest, stylesheet: stylesheet, previewPNG: review.preview)
    }
}

/// The package's JSON object and its manifest object, before anything inside them is trusted.
private struct RawPackage {
    let object: [String: Any], manifest: [String: Any]

    init(_ data: Data, maxBytes: Int) throws(DesignPackageRejected) {
        guard data.count <= maxBytes else { throw DesignPackageRejected(violations: [.tooLarge(data.count)]) }
        let parsed: Any
        do { parsed = try JSONSerialization.jsonObject(with: data) } catch { throw DesignPackageRejected(violations: [.malformed("not JSON")]) }
        guard let object = parsed as? [String: Any], let manifest = object["manifest"] as? [String: Any] else {
            throw DesignPackageRejected(violations: [.malformed("not a design package")])
        }
        self.object = object
        self.manifest = manifest
    }

    /// nil when the manifest does not decode.
    var decodedManifest: DesignManifest? {
        do { return try JSONDecoder().decode(DesignManifest.self, from: JSONSerialization.data(withJSONObject: manifest)) } catch { return nil }
    }
}

/// What checking one package finds: the violations, and the stylesheet and preview that passed.
private struct PackageReview {
    private static let packageKeys: Set<String> = ["manifest", "cssContent", "previewImageBase64"]
    private static let manifestKeys: Set<String> = ["id", "name", "version", "description", "markupContract", "author", "price"]
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    let maxPreviewBytes: Int
    private(set) var violations: [DesignPackageViolation] = []
    private(set) var stylesheet: ValidatedStylesheet?
    private(set) var preview: Data?

    func rejection(adding violation: DesignPackageViolation) -> DesignPackageRejected {
        DesignPackageRejected(violations: violations + [violation])
    }

    mutating func checkKeys(of package: RawPackage) {
        if package.object.keys.contains("htmlContent") { violations.append(.containsHTML) }
        let unknownInPackage = Set(package.object.keys).subtracting(Self.packageKeys).subtracting(["htmlContent"])
        let unknownInManifest = Set(package.manifest.keys).subtracting(Self.manifestKeys).map { "manifest." + $0 }
        let unknown = unknownInPackage.union(unknownInManifest)
        if !unknown.isEmpty { violations.append(.unknownKeys(unknown.sorted())) }
    }

    mutating func checkManifest(_ manifest: DesignManifest) {
        if !DesignManifest.isValidID(manifest.id) { violations.append(.invalidID(manifest.id)) }
        if manifest.markupContract != MarkupContract.version { violations.append(.unsupportedContract(manifest.markupContract)) }
    }

    mutating func checkStylesheet(_ css: String) {
        do throws(CSSRejection) { stylesheet = ValidatedStylesheet(css: try CSSPolicy.canonical(css)) } catch { violations.append(.css(error.reason)) }
    }

    /// A package without a preview is valid; one whose preview is not a PNG within the size cap is not.
    mutating func checkPreview(_ raw: Any?) {
        guard let raw else { return }
        if let png = decodedPNG(raw) { preview = png } else { violations.append(.invalidPreview("not a PNG within \(maxPreviewBytes) bytes")) }
    }

    private func decodedPNG(_ raw: Any) -> Data? {
        guard let text = raw as? String, let png = Data(base64Encoded: text), png.count <= maxPreviewBytes, png.starts(with: Self.pngSignature) else {
            return nil
        }
        return png
    }
}
