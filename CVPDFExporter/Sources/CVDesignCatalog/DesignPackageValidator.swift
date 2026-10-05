import Foundation

/// Anti-corruption layer for design packages (ValidatingBoundary). Works on the raw bytes: size first, then a strict
/// decode (unknown keys and any `htmlContent` key are rejected), then id, contract, CSS and preview.
public struct DesignPackageValidator: Sendable {
    public var maxBytes: Int, maxPreviewBytes: Int
    public init(maxBytes: Int = 512 * 1024, maxPreviewBytes: Int = 256 * 1024) { self.maxBytes = maxBytes; self.maxPreviewBytes = maxPreviewBytes }

    static let packageKeys: Set<String> = ["manifest", "cssContent", "previewImageBase64"]
    static let manifestKeys: Set<String> = ["id", "name", "version", "description", "markupContract", "author", "price"]

    public func validate(_ data: Data) throws(DesignPackageRejected) -> ValidatedDesign {
        guard data.count <= maxBytes else { throw DesignPackageRejected(violations: [.tooLarge(data.count)]) }
        let parsed: Any
        do { parsed = try JSONSerialization.jsonObject(with: data) } catch { throw DesignPackageRejected(violations: [.malformed("not JSON")]) }
        guard let object = parsed as? [String: Any], let manifestObject = object["manifest"] as? [String: Any] else {
            throw DesignPackageRejected(violations: [.malformed("not a design package")])
        }
        var violations: [DesignPackageViolation] = []
        if object.keys.contains("htmlContent") { violations.append(.containsHTML) }
        let unknown = Set(object.keys).subtracting(Self.packageKeys).subtracting(["htmlContent"])
            .union(Set(manifestObject.keys).subtracting(Self.manifestKeys).map { "manifest." + $0 })
        if !unknown.isEmpty { violations.append(.unknownKeys(unknown.sorted())) }
        let manifest: DesignManifest
        do { manifest = try JSONDecoder().decode(DesignManifest.self, from: JSONSerialization.data(withJSONObject: manifestObject)) }
        catch { throw DesignPackageRejected(violations: violations + [.malformed("manifest")]) }
        guard let css = object["cssContent"] as? String else { throw DesignPackageRejected(violations: violations + [.malformed("cssContent")]) }
        if !DesignManifest.isValidID(manifest.id) { violations.append(.invalidID(manifest.id)) }
        if manifest.markupContract != MarkupContract.version { violations.append(.unsupportedContract(manifest.markupContract)) }
        var stylesheet: ValidatedStylesheet?
        do throws(CSSRejection) { stylesheet = ValidatedStylesheet(css: try CSSPolicy.canonical(css)) } catch { violations.append(.css(error.reason)) }
        var preview: Data?
        if let base64 = object["previewImageBase64"] {
            if let b = base64 as? String, let png = Data(base64Encoded: b), png.count <= maxPreviewBytes,
               png.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { preview = png }
            else { violations.append(.invalidPreview("not a PNG within \(maxPreviewBytes) bytes")) }
        }
        guard violations.isEmpty, let stylesheet else { throw DesignPackageRejected(violations: violations) }
        return ValidatedDesign(manifest: manifest, stylesheet: stylesheet, previewPNG: preview)
    }
}
