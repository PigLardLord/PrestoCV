import Foundation

extension TemplatePackage {

    /// The slot of a template's HTML that receives the stylesheet of its package
    static let customCSSSlot = "{{customCSS}}"

    /// The page this package renders: its own HTML, or the shared base page when it has none,
    /// with the stylesheet of the package in the `{{customCSS}}` slot
    var composedHTML: String {
        (htmlContent ?? BaseHTMLTemplate.html)
            .replacingOccurrences(of: Self.customCSSSlot, with: cssContent)
    }
}
