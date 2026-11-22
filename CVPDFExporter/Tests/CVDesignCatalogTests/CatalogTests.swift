import Testing
import Foundation
import CVDesignCatalog
import CVBundledDesigns
import CVRenderingTestSupport

func designData(_ css: String, id: String = "ok", extra: [String: Any] = [:], manifestExtra: [String: Any] = [:],
                manifestWithout: [String] = [], contract: Int = MarkupContract.version) -> Data {
    var manifest: [String: Any] = ["id": id, "name": "x", "version": "1.0.0", "description": "", "defaultPalette": "ink",
                                   "defaultFonts": "system", "markupContract": contract]
    manifest.merge(manifestExtra) { $1 }
    for key in manifestWithout { manifest[key] = nil }
    var object: [String: Any] = ["manifest": manifest, "cssContent": css]
    object.merge(extra) { $1 }
    return try! JSONSerialization.data(withJSONObject: object)   // test fixture only
}
func rejected(_ css: String) -> Bool { (try? DesignPackageValidator().validate(designData(css))) == nil }
let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0])

@Suite("ADR 0002 / R8 · design packages")
struct CatalogTests {
    @Test("bundled designs load from Bundle.module on every platform, Linux included")
    func bundledLoad() async throws {
        #expect(try await BundleDesignSource().bundledPackages().map(\.name) == ["minimal", "modern", "professional"])
    }

    @Test("a <style> breakout is rejected wherever it hides: bare, in a comment, in a string (security C1)", arguments: [
        "</style><script>alert(1)</script>", "/* </style><img src=x> */ .cv{color:var(--color-text)}",
        ".cv{font-family:\"</style>\"}", "<!-- .cv{} -->",
    ])
    func styleBreakout(css: String) { #expect(rejected(css)) }

    @Test("a comment opener inside a string cannot hide later declarations (security C2)", arguments: [
        #".cv[data-section="/*"]{color:var(--color-text)} .cv{background:url(https://evil.example)} /* */"#,
        #".cv-section{font-family:"x/*";display:none} /* "*/"#,
        #".cv-entry{font-family:'/*';background:url(https://evil.example/p)}/*'*/"#,
    ])
    func stringHidesComment(css: String) { #expect(rejected(css)) }

    @Test("resource loads are impossible", arguments: [
        ".cv{background:url('https://evil.example/?x')}", ".cv{background:URL(\n\"https://evil.example/a\")}",
        ".cv{background:\\75 rl(https://evil.example/a)}", "@\\69mport url(//evil.example/x.css);",
        "@import url(//evil.example/x.css);", "@font-face{font-family:x;src:local(x)}",
        ".cv{background:image-set(\"https://evil.example/a\" 1x)}", ".cv{background:u/**/rl(https://evil.example/a)}",
        ".cv{background:url(data:image/png;base64,AAAA)}", ".cv{behavior:url(x.htc)}",
        ".cv{list-style-image:url(x)}", ".cv{border-image:url(x) 30}", ".cv{mask:url(x)}", ".cv{cursor:url(x),auto}",
        ".cv{filter:url(#x)}", "@namespace url(x);", ".cv{background-color:{{colorPrimary}}}",
    ])
    func resources(css: String) { #expect(rejected(css)) }

    @Test("every hiding, moving or injecting construct from the reviews is rejected (C3, C4, H3)", arguments: [
        "@media print{[data-section=\"experience\"]{display:none}}", ".cv-entry{display:table-column}",
        ".cv-entry{--h:none;display:var(--h)}", ".cv{--h:none} .cv-section{display:var(--h)}", ".cv-entry{content-visibility:hidden}",
        ".cv-entry{-webkit-clip-path:inset(50%)}", ".cv-entry{filter:opacity(0)}", ".cv-entry{opacity:0%}", ".cv-entry{opacity:.001}",
        ".cv-entry{font-size:0vw}", ".cv-entry{font-size:0.001px}", ".cv-entry{font-size:0.01px}", ".cv-entry{font:0/0 a}",
        ".cv-entry{transform:scale(0)}", ".cv-entry{scale:0}", ".cv-entry{position:absolute;left:-9999px}", ".cv-entry{text-indent:-9999px}",
        ".cv-entry{height:0;overflow:hidden}", ".cv-entry{-webkit-text-security:disc}", ".cv-entry{color:transparent}",
        ".cv-entry{-webkit-text-fill-color:transparent}", ".cv-entry{mask-image:linear-gradient(transparent,transparent)}",
        ".cv-entry{color:var(--color-background)}", ".cv-interest{position:fixed;inset:0;background:#fff;z-index:2147483647}",
        ".cv-entry{zoom:0.001}", ".cv-entry{display:list-item;list-style:inside \"other@example.org\"}",
        ".cv-entry{unicode-bidi:bidi-override;direction:rtl}", ".cv-section{display:flex;flex-direction:column-reverse}",
        ".cv-entry{order:-1}", ".cv-entry{grid-row:1}", ".cv-entry{line-height:0}", ".cv-entry{mix-blend-mode:screen}",
        "@page{size:1px 1px}", ".cv-entry{margin-top:100000px}", ".cv-header{padding-top:20000px}", "@counter-style x{symbols:\"a\"}",
        ".cv-entry{text-emphasis:\"x\"}", ".cv-entry{hyphenate-character:\"x\"}", ".cv-entry{quotes:\"a\" \"b\"}",
        ".cv-entry::before{content:\"x\"}", ".cv-entry::marker{color:var(--color-text)}", ".cv-section:has(.cv-entry){color:var(--color-text)}",
        ".cv-entry:nth-of-type(3){color:var(--color-text)}", "#main{color:var(--color-text)}", ".hero-section{color:var(--color-text)}",
        ".cv-entry{color:var(--color-text) !important}", "@supports (display:grid){.cv{display:grid}}", "@layer a{.cv{display:grid}}",
        "@container (min-width:1px){.cv{display:grid}}", ".cv-entry{visibility:hidden}", ".cv-entry{opacity:0}",
        ".cv-entry{DISPLAY :\tNONE}", ".cv{.cv-entry{color:var(--color-text)}}", ".cv-entry{width:calc(0px)}",
        ".cv-entry{font-size:0}", ".cv-entry{font-size:+0}", ".cv-entry{font-size:0.0}",
    ])
    func hidingRejected(css: String) { #expect(rejected(css)) }

    @Test("huge numbers are rejected, never a crash", arguments: [
        ".cv-skill[data-rating=99999999999999999999]{color:var(--color-text)}", ".cv{margin:1234567890pt}",
        ".cv{flex:1.00000000000000000001}", ".cv-skill[data-rating=1e400]{color:var(--color-text)}",
    ])
    func hugeNumbers(css: String) { #expect(rejected(css)) }

    @Test("flex and grid containers keep inline entries apart with a column gap", arguments: [
        ".cv-profile{display:flex}", ".cv-profile{display:inline-flex}", ".cv-profile{display:grid;grid-template-columns:1fr 1fr}",
        ".cv-profile{display:flex;gap:0}", ".cv-profile{display:flex;gap:4pt 0}", ".cv-profile{display:flex;column-gap:2pt}",
        ".cv-profile{display:flex;column-gap:0.2em}", ".cv-profile{display:flex;row-gap:8pt}", ".cv-profile{display:flex;gap:4pt 2px}",
    ])
    func flexNeedsGap(css: String) { #expect(rejected(css)) }

    @Test("a flex or grid container with a column gap of at least 3pt is accepted", arguments: [
        ".cv-profile{display:flex;gap:3pt}", ".cv-profile{display:inline-flex;column-gap:0.25em}",
        ".cv-entry{display:grid;gap:0 12pt}", ".cv-header{display:flex;flex-wrap:wrap;gap:4px}", ".cv-skill{row-gap:0}",
    ])
    func flexWithGap(css: String) throws { _ = try DesignPackageValidator().validate(designData(css)) }

    @Test("relative font sizes are refused: nesting compounds em and %, and rem follows the root (final gate)", arguments: [
        ".cv{font-size:7pt}.cv-section{font-size:60%}", ".cv-entry{font-size:0.6em}", ".cv{font-size:100%}", ".cv-skill{font-size:1em}",
        ".cv-name{font-size:0.6rem}", "*{font-size:7pt}.cv-name{font-size:0.6rem}",
    ])
    func parentRelativeFontSize(css: String) { #expect(rejected(css)) }

    @Test("the universal selector is refused: it also reaches the document root (final gate)", arguments: ["*{color:var(--color-text)}", ".cv *{margin:0}", "section>*{padding:0}"])
    func universalSelector(css: String) { #expect(rejected(css)) }

    @Test("absolute font sizes within bounds are accepted", arguments: [".cv{font-size:9pt}", ".cv{font-size:12px}", ".cv-entry{font-size:7pt}"])
    func fontSizes(css: String) throws { _ = try DesignPackageValidator().validate(designData(css)) }

    @Test("zero is still fine where zero is allowed")
    func zeroSpacing() throws { _ = try DesignPackageValidator().validate(designData(".cv{margin:0;padding:0 4pt}")) }

    @Test("an ordinary design passes and is emitted in canonical form, without comments")
    func canonical() throws {
        let css = """
        /* Two columns */
        .cv { font-family: var(--font-body); color: var(--color-text); }
        .cv-entry , .cv-profile:first-child{ display:grid; grid-template-columns: 1fr 2fr; gap: 12px 8px }
        @media print { .cv-section { break-inside: avoid } }
        [data-section="skills"] > .cv-skill[data-rating="5"] { font-weight: 700; border-bottom: 1pt solid var(--color-primary) }
        .cv-entry-period{font-size:9pt;margin:0 0 4pt}
        """
        let validated = try DesignPackageValidator().validate(designData(css))
        #expect(validated.stylesheet.css == """
        .cv{font-family:var(--font-body);color:var(--color-text)}.cv-entry,.cv-profile:first-child{display:grid;grid-template-columns:1fr 2fr;gap:12px 8px}@media print{.cv-section{break-inside:avoid}}[data-section="skills"]>.cv-skill[data-rating="5"]{font-weight:700;border-bottom:1pt solid var(--color-primary)}.cv-entry-period{font-size:9pt;margin:0 0 4pt}
        """)
        #expect(!validated.stylesheet.css.contains("/*"))
    }

    @Test("package structure is checked strictly on the raw bytes (review: M13, M16)")
    func strictPackage() throws {
        let v = DesignPackageValidator()
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", id: "../../etc")) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", id: "modern\n")) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", extra: ["htmlContent": NSNull()])) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", extra: ["scripts": "x"])) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", manifestExtra: ["homepage": "x"])) }
        // A design targets the contract of this version: a newer one is unknown, and one written for contract 1 no longer fits the nesting (#467).
        for contract in [0, 1, MarkupContract.version + 1] {
            #expect(throws: DesignPackageRejected.self, "contract \(contract)") { _ = try v.validate(designData(".cv{}", contract: contract)) }
        }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", extra: ["previewImageBase64": "not base64"])) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(designData(".cv{}", extra: ["previewImageBase64": Data("GIF89a".utf8).base64EncodedString()])) }
        #expect(throws: DesignPackageRejected.self) { _ = try DesignPackageValidator(maxBytes: 100).validate(designData(String(repeating: " ", count: 200))) }
        #expect(throws: DesignPackageRejected.self) { _ = try v.validate(Data("[]".utf8)) }
        let ok = try v.validate(designData(".cv{}", extra: ["previewImageBase64": png.base64EncodedString()]))
        #expect(ok.previewPNG == png && ok.manifest.markupContract == MarkupContract.version)
    }

    @Test("only readable palettes exist; colour parsing rejects trailing line terminators (security S7)")
    func palettes() {
        #expect(HexColor("#FFFFFF\n") == nil && HexColor("#FFFFFF\u{2028}") == nil && HexColor("#FFFFFF") != nil)
        let white = HexColor("#FFFFFF")!
        #expect(Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#111111")!, background: white) != nil)
        #expect(Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#EEEEEE")!, background: white) == nil)
        #expect(Palette(primary: HexColor("#FAFAFA")!, text: HexColor("#111111")!, background: white) == nil)
    }

    /// A design may colour 9pt text with primary (dates, links), so primary needs the 4.5:1 of ordinary text, not 3:1.
    @Test("primary needs the contrast of ordinary text: 4.5:1 on the background", arguments: [
        ("#949494", false),   // 3.03:1, readable only as a border or a large heading
        ("#777777", false),   // 4.48:1, just below
        ("#767676", true),    // 4.54:1, just above
    ])
    func primaryContrast(primary: String, exists: Bool) {
        #expect((Palette(primary: HexColor(primary)!, text: HexColor("#111111")!, background: HexColor("#FFFFFF")!) != nil) == exists)
    }

    /// A picker draws a palette with its own colours: the red, green and blue come from the colour's digits, each
    /// channel from its own pair, upper or lower case alike.
    @Test("a colour gives its red, green and blue, each from 0 to 1")
    func channels() throws {
        let ocean = try #require(HexColor("#1E40AF")).channels
        #expect(ocean.red == 30.0 / 255)
        #expect(ocean.green == 64.0 / 255)
        #expect(ocean.blue == 175.0 / 255)
        let lower = try #require(HexColor("#fef3c7")).channels
        #expect(lower.red == 254.0 / 255 && lower.green == 243.0 / 255 && lower.blue == 199.0 / 255)
        let black = try #require(HexColor("#000000")).channels
        let white = try #require(HexColor("#FFFFFF")).channels
        #expect(black.red == 0 && black.green == 0 && black.blue == 0)
        #expect(white.red == 1 && white.green == 1 && white.blue == 1)
    }
}

/// A section title keeps a fixed room below its last line, for its own spacing and the next line, so that it is never
/// alone at the foot of a page (#467). A design may not set more below the title, or on its start, than that room covers.
@Suite("#467 · what a design may set below a section's title and on its start")
struct SectionStartLimitTests {
    func reason(_ css: String) -> String? {
        do { _ = try DesignPackageValidator().validate(designData(css)); return nil } catch {
            return error.violations.compactMap { if case .css(let reason) = $0 { reason } else { nil } }.first ?? "\(error)"
        }
    }

    @Test("a section title's bottom padding or margin beyond 1em or 12pt is refused, whatever the selector reaching it", arguments: [
        ".cv-section-title{padding-bottom:4em}", ".cv-section-title{padding-bottom:13pt}", ".cv-section-title{padding-bottom:17px}",
        ".cv-section-title{padding-bottom:1.1rem}", ".cv-section-title{padding:0 0 1.5em}", ".cv-section-title{padding:2em}",
        "h2{margin-bottom:4em}", ".cv-section-title{margin:0 0 13pt}", "h2.cv-section-title:only-child{margin:16pt 0}",
        ".cv-section>:first-child{margin-bottom:24pt}", ".cv-section-start :first-child{padding-bottom:2em}",
        ".cv-entry,.cv-section-title{margin-bottom:2em}",
    ])
    func titleSpacing(css: String) {
        #expect(reason(css)?.hasPrefix("a section title's bottom padding and bottom margin") == true, "\(css): \(reason(css) ?? "accepted")")
    }

    @Test("a section title stays a block", arguments: [
        ".cv-section-title{display:flex;gap:3pt}", ".cv-section-title{display:grid;gap:3pt}", "h2{display:inline-block}", ":first-child{display:inline}",
    ])
    func titleDisplay(css: String) {
        #expect(reason(css)?.hasPrefix("a section title stays display: block") == true, "\(css): \(reason(css) ?? "accepted")")
    }

    @Test("a section start takes no layout and nothing below its title", arguments: [
        ".cv-section-start{padding-bottom:48pt}", ".cv-section-start{padding:4pt}", ".cv-section-start{display:grid;gap:3pt}",
        ".cv-section-start{display:flex;gap:3pt}", "div{margin-bottom:1pt}", "div.cv-section-start{margin:0 0 4pt}",
        ".cv-section-start{border-bottom:1pt solid var(--color-primary)}", ".cv-section-start{border:solid}",
        ".cv-section>:first-child{padding-bottom:2pt}",
    ])
    func start(css: String) {
        #expect(reason(css)?.hasPrefix("a section start takes") == true, "\(css): \(reason(css) ?? "accepted")")
    }

    @Test("the document and its sections stay blocks: printed, flex and grid cut lines at a page's end", arguments: [
        ".cv{display:flex;flex-direction:column;gap:3pt}", "main{display:grid;gap:3pt}", "section{display:flex;gap:3pt}",
        ".cv-section{display:grid;gap:3pt}", "[data-section=\"skills\"]{display:flex;flex-wrap:wrap;column-gap:3pt}",
        ".cv>.cv-section:last-child{display:inline-block}", "section.cv-section[data-section=\"interests\"]{display:grid;column-gap:3pt}",
    ])
    func containers(css: String) {
        #expect(reason(css)?.hasPrefix("the document and its sections stay display: block") == true, "\(css): \(reason(css) ?? "accepted")")
    }

    @Test("spacing up to the limits, and rules that cannot reach the title or the start, are accepted", arguments: [
        // The bundled designs' title rules.
        ".cv-section-title{margin-bottom:6pt}", ".cv-section-title{margin-bottom:8pt;padding-bottom:2pt;border-bottom:1pt solid var(--color-primary)}",
        // At the limits, in every unit; the space above the title is free.
        ".cv-section-title{padding-bottom:1em;margin-bottom:1em;border-bottom:0.3em solid var(--color-primary)}",
        ".cv-section-title{padding:4em 0 12pt;margin:4em 0 16px}", ".cv-section-title{margin:1rem;display:block}",
        ".cv-section-start{padding-top:8pt;margin-top:4pt;border-top:1pt solid var(--color-primary);border-bottom:none;display:block}",
        ".cv-section-start{border:0 solid var(--color-primary)}",
        ".cv-entry-title{padding-bottom:4em}", ".cv-section{padding-bottom:4em;display:block}", ".cv-skill:first-child{display:inline}",
        // Flex and grid inside an entry or a line, and on the header.
        ".cv-entry{display:grid;grid-template-columns:1fr 1fr;column-gap:3pt}", ".cv-profile{display:flex;column-gap:3pt}",
        ".cv-header{display:flex;flex-wrap:wrap;gap:3pt}", "[data-section=\"skills\"] .cv-skill{display:inline-block}",
        // A forced break inside a section start, or right after it, is ignored by the base style rather than refused.
        ".cv-section-title{break-after:page}", ".cv-entry{break-before:page}", ".cv-section{break-before:page}",
    ] + PageBreakDocument.LimitDesign.allCases.map(\.css)) // and the native page-break checks' designs at the limits
    func accepted(css: String) { #expect(reason(css) == nil, "\(css): \(reason(css) ?? "")") }
}
