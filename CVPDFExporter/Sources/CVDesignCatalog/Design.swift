import Foundation

public struct DesignManifest: Codable, Sendable, Equatable {
    public var id: String, name: String, version: DesignVersion, description: String
    /// The palette and the font scheme the design uses when a design choice names none, or names one the catalog does
    /// not know.
    public var defaultPalette: NamedPalette, defaultFonts: FontScheme
    /// Version of the markup contract the design's CSS was written for (ADR 0011).
    public var markupContract: Int
    public init(id: String, name: String, version: DesignVersion, description: String, defaultPalette: NamedPalette, defaultFonts: FontScheme,
                markupContract: Int = MarkupContract.version) {
        self.id = id; self.name = name; self.version = version; self.description = description
        self.defaultPalette = defaultPalette; self.defaultFonts = defaultFonts; self.markupContract = markupContract
    }
    /// The one rule for design identifiers: lowercase ASCII letters, digits and hyphens, 1–64 characters. Stores use it
    /// before touching storage, so an identifier can never name a path.
    public static func isValidID(_ id: String) -> Bool { id.fullyMatches(#"[a-z0-9-]{1,64}"#) }
    /// A name is one line of 1–80 Unicode scalars that is not only white space.
    public static func isValidName(_ name: String) -> Bool {
        isClean(name, maxScalars: 80, allowingNewlines: false) && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// A description is 0–500 Unicode scalars, and may span lines.
    public static func isValidDescription(_ description: String) -> Bool { isClean(description, maxScalars: 500, allowingNewlines: true) }
    /// Within the bound, with no control character (a newline only where allowed), no line or paragraph separator
    /// (U+2028, U+2029: a renderer breaks the line there, and a description's only break is `\n`) and no explicit
    /// bidirectional embedding, override or isolate (U+202A–U+202E, U+2066–U+2069): none can reorder the text around it.
    /// The directional marks U+200E, U+200F and U+061C stay: a right-to-left name may need them.
    private static func isClean(_ text: String, maxScalars: Int, allowingNewlines: Bool) -> Bool {
        var count = 0
        for scalar in text.unicodeScalars {
            count += 1
            if count > maxScalars { return false }
            if scalar.properties.generalCategory == .control && !(allowingNewlines && scalar == "\n") { return false }
            if scalar == "\u{2028}" || scalar == "\u{2029}" { return false }
            if (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value) { return false }
        }
        return true
    }
}

public enum DesignPackageViolation: Equatable, Sendable, CustomStringConvertible {
    case tooLarge(Int), malformed(String), unknownKeys([String]), containsHTML, invalidID(String), invalidName, invalidVersion(String),
         invalidDescription, unknownPalette(String), unknownFontScheme(String), unsupportedContract(Int), css(String), invalidPreview(String)
    public var description: String {
        switch self {
        case .tooLarge(let n): "package too large: \(n) bytes"
        case .malformed(let r): "malformed package: \(r)"
        case .unknownKeys(let keys): "unknown keys (\(keys.count)): " + keys.prefix(16).map(Self.excerpt).joined(separator: ", ") + (keys.count > 16 ? ", …" : "")
        case .containsHTML: "package ships HTML"
        case .invalidID(let id): "invalid id \(Self.excerpt(id))"
        case .invalidName: "invalid name"
        case .invalidVersion(let v): "invalid version \(Self.excerpt(v))"
        case .invalidDescription: "invalid description"
        case .unknownPalette(let id): "unknown palette \(Self.excerpt(id))"
        case .unknownFontScheme(let id): "unknown font scheme \(Self.excerpt(id))"
        case .unsupportedContract(let v): "unsupported markup contract \(v)"
        case .css(let reason): "stylesheet rejected: \(reason)"
        case .invalidPreview(let r): "invalid preview: \(r)"
        }
    }

    /// At most 64 Unicode scalars of the text a package supplied, quoted and escaped to ASCII (`\n`, `\u{202E}`), and `…`
    /// when cut: a description must not carry a whole package, or raw control and bidirectional characters, into a log
    /// or a screen. The associated values keep the full text.
    private static func excerpt(_ text: String) -> String {
        let quoted = "\"" + text.unicodeScalars.prefix(64).map { $0.escaped(asASCII: true) }.joined() + "\""
        return text.unicodeScalars.dropFirst(64).isEmpty ? quoted : quoted + "…"
    }
}

/// A design that passed every check. Only the validator creates one.
public struct ValidatedDesign: Sendable, Equatable {
    public let manifest: DesignManifest
    public let stylesheet: ValidatedStylesheet
    public let previewPNG: Data?
}

/// Anti-corruption layer for design packages (R8). Works on the raw bytes: size first, then a strict
/// decode (unknown keys and any `htmlContent` key are rejected), then id, name, version, description, default palette
/// and font scheme, contract, CSS and preview.
public struct DesignPackageValidator: Sendable {
    public var maxBytes: Int, maxPreviewBytes: Int
    public init(maxBytes: Int = 512 * 1024, maxPreviewBytes: Int = 256 * 1024) { self.maxBytes = maxBytes; self.maxPreviewBytes = maxPreviewBytes }

    static let packageKeys: Set<String> = ["manifest", "cssContent", "previewImageBase64"]
    static let manifestKeys: Set<String> = ["id", "name", "version", "description", "defaultPalette", "defaultFonts", "markupContract",
                                            "author", "price"]

    /// The manifest as the package writes it. The version and the identifiers of the defaults stay strings until the
    /// catalog has checked them, so a violation can name the text.
    private struct RawManifest: Decodable {
        let id: String, name: String, version: String, description: String
        let defaultPalette: String, defaultFonts: String
        let markupContract: Int
    }

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
        guard JSONSerialization.isValidJSONObject(manifestObject) else {   // on Darwin, an invalid object raises an exception no `catch` sees
            throw DesignPackageRejected(violations: violations + [.malformed("manifest")])
        }
        let raw: RawManifest
        do { raw = try JSONDecoder().decode(RawManifest.self, from: JSONSerialization.data(withJSONObject: manifestObject)) }
        catch { throw DesignPackageRejected(violations: violations + [.malformed("manifest")]) }
        guard let css = object["cssContent"] as? String else { throw DesignPackageRejected(violations: violations + [.malformed("cssContent")]) }
        if !DesignManifest.isValidID(raw.id) { violations.append(.invalidID(raw.id)) }
        if !DesignManifest.isValidName(raw.name) { violations.append(.invalidName) }
        let version = DesignVersion(raw.version)
        if version == nil { violations.append(.invalidVersion(raw.version)) }
        if !DesignManifest.isValidDescription(raw.description) { violations.append(.invalidDescription) }
        let palette = NamedPalette(rawValue: raw.defaultPalette)
        if palette == nil { violations.append(.unknownPalette(raw.defaultPalette)) }
        let fonts = FontScheme(rawValue: raw.defaultFonts)
        if fonts == nil { violations.append(.unknownFontScheme(raw.defaultFonts)) }
        if raw.markupContract != MarkupContract.version { violations.append(.unsupportedContract(raw.markupContract)) }
        var stylesheet: ValidatedStylesheet?
        do throws(CSSRejection) { stylesheet = ValidatedStylesheet(css: try CSSPolicy.canonical(css)) } catch { violations.append(.css(error.reason)) }
        var preview: Data?
        if let base64 = object["previewImageBase64"] {
            if let b = base64 as? String, let png = Data(base64Encoded: b), png.count <= maxPreviewBytes,
               png.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { preview = png }
            else { violations.append(.invalidPreview("not a PNG within \(maxPreviewBytes) bytes")) }
        }
        guard violations.isEmpty, let version, let palette, let fonts, let stylesheet else { throw DesignPackageRejected(violations: violations) }
        let manifest = DesignManifest(id: raw.id, name: raw.name, version: version, description: raw.description,
                                      defaultPalette: palette, defaultFonts: fonts, markupContract: raw.markupContract)
        return ValidatedDesign(manifest: manifest, stylesheet: stylesheet, previewPNG: preview)
    }
}

/// Where an installed design came from. The store records it, outside the package: a package is untrusted, so it
/// cannot say what it is.
public enum DesignOrigin: String, Sendable, Equatable, CaseIterable, Codable {
    /// Installed by `SyncBundledDesigns`, from the designs that ship with the app.
    case bundled
    /// Installed by `InstallDesign`, from a package someone supplied.
    case imported
}

/// What `DesignStore.saveIfNewer` did.
public enum ConditionalSave: Equatable, Sendable {
    /// No design had the identifier: the design was saved.
    case installed
    /// The installed design had an older version: the design replaced it.
    case upgraded
    /// The installed design has the same or a newer version: nothing was written.
    case keptInstalled
}

/// Stores validated designs. Owned by the catalog (R3); adapters live in CVDesignCatalogFileStore and test support,
/// and pass `DesignStoreContract`. Saving an identifier again replaces its design.
public protocol DesignStore: Sendable {
    func save(_ design: ValidatedDesign) async throws
    /// Saves the design only if no design has its identifier or the installed one has an older version, and says which.
    /// The comparison and the write are one step under the store's lock, so a design saved meanwhile by another caller
    /// is never replaced by an older one. When the installed design is kept, nothing is written.
    func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave
    /// nil only when no design has this identifier; a stored design that cannot be read is an error (R7).
    func design(id: String) async throws -> ValidatedDesign?
    /// The stored designs' manifests, ordered by identifier.
    func installedDesigns() async throws -> [DesignManifest]
}

/// Proves that a design renders a fixture document without losing content (ADR 0011). Owned by the
/// catalog, implemented downstream by CVRendering (the allowed Rendering → Catalog edge).
public protocol DesignRenderingGate: Sendable {
    func verify(_ design: ValidatedDesign) async throws
}

/// Outbound port, owned by the catalog (R3). Raw bytes: validation happens in the catalog, not the source.
public protocol BundledDesignSource: Sendable {
    func bundledPackages() async throws -> [(name: String, data: Data)]
}

/// CSS that passed validation. Only the validator can create one (internal init), so rendering
/// cannot receive unvalidated CSS: R8 enforced by the type system.
public struct ValidatedStylesheet: Sendable, Equatable {
    public let css: String
    init(css: String) { self.css = css }
}

public struct DesignPackageRejected: Error, Equatable { public let violations: [DesignPackageViolation] }

/// A palette colour: only `#RRGGBB` can exist, so it is safe to write into CSS.
public struct HexColor: Sendable, Equatable {
    public let value: String
    public init?(_ value: String) {
        guard value.fullyMatches(#"#[0-9A-Fa-f]{6}"#) else { return nil }
        self.value = value
    }
    /// A colour written in the source, known to be `#RRGGBB`. Only `NamedPalette` uses it; everything else goes
    /// through the checked initialiser.
    fileprivate init(known value: String) { self.value = value }
    /// WCAG relative luminance.
    var luminance: Double {
        let hex = Array(value.dropFirst())
        func channel(_ k: Int) -> Double {
            let v = Double(Int(String(hex[k...k + 1]), radix: 16) ?? 0) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
    }
    public func contrast(with other: HexColor) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Only readable palettes exist: text on background ≥ 4.5:1, primary on background ≥ 3:1. Designs can
/// only colour text with these variables, so no palette can make text invisible.
public struct Palette: Sendable, Equatable {
    public let primary: HexColor, text: HexColor, background: HexColor
    public init?(primary: HexColor, text: HexColor, background: HexColor) {
        guard text.contrast(with: background) >= 4.5, primary.contrast(with: background) >= 3 else { return nil }
        self.primary = primary; self.text = text; self.background = background
    }
    /// A palette written in the source, known to pass the contrast rule. Only `NamedPalette` uses it, and its tests
    /// build every case again through the checked initialiser.
    fileprivate init(known primary: HexColor, text: HexColor, background: HexColor) {
        self.primary = primary; self.text = text; self.background = background
    }
    public var customProperties: String {
        ":root{--color-primary:\(primary.value);--color-text:\(text.value);--color-background:\(background.value)}"
    }
}

/// The palettes a design choice can name: a closed set, named after colours and never after a design. The raw value is
/// the identifier a `DesignChoice` stores. Each one passes the `Palette` contrast rule.
public enum NamedPalette: String, Sendable, CaseIterable, Codable {
    case ink, slate, ocean, plum
    public var palette: Palette {
        switch self {
        case .ink: Self.palette("#000000", text: "#000000", background: "#FFFFFF")
        case .slate: Self.palette("#2C3E50", text: "#2C3E50", background: "#FFFFFF")
        case .ocean: Self.palette("#1E40AF", text: "#1F2937", background: "#E0E7FF")
        case .plum: Self.palette("#6B46C1", text: "#1F2937", background: "#FEF3C7")
        }
    }
    private static func palette(_ primary: String, text: String, background: String) -> Palette {
        Palette(known: HexColor(known: primary), text: HexColor(known: text), background: HexColor(known: background))
    }
}

/// Font stacks are a closed set of system families; designs refer to them only through variables. The raw value is
/// the identifier a `DesignChoice` stores.
public enum FontScheme: String, Sendable, CaseIterable, Codable {
    case system, serif, rounded
    public var customProperties: String {
        let stack = switch self {
        case .system: "-apple-system,system-ui,Helvetica,Arial,sans-serif"
        case .serif: "Georgia,'Times New Roman',serif"
        case .rounded: "ui-rounded,-apple-system,system-ui,sans-serif"
        }
        return ":root{--font-body:\(stack);--font-heading:\(stack)}"
    }
}

extension String {
    /// Whole-string match. `^…$` would accept a trailing newline (and U+2028), `\z` does not.
    func fullyMatches(_ pattern: String) -> Bool {
        range(of: "^(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }
}
