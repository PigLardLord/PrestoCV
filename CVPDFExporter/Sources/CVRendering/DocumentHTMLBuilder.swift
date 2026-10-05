import Foundation
import CVDocumentModel
import CVDesignCatalog

/// The builder's output: the HTML and the exact text it contains, one entry per text node. The text is
/// what the PDF must contain, occurrence by occurrence (see `DocumentCompleteness`).
public struct RenderedDocument: Sendable, Equatable {
    public let html: String
    public let textNodes: [String]
}

/// Builds the markup contract's HTML for a document (ADR 0011). Every value is escaped, links survive only as parsed
/// `WebLink`s, and the document's language reaches the page only when it has the shape of a BCP 47 tag.
public struct DocumentHTMLBuilder: Sendable {
    public init() {}

    /// Every link prints its destination as text, so completeness covers it even where the PDF drops the
    /// clickable annotation; the base style lets that text wrap, since designs cannot set overflow-wrap.
    static let baseStyle = "a{overflow-wrap:anywhere}"

    /// Anything that is not the shape of a language tag becomes "und" (undetermined).
    static func languageTag(_ raw: String) -> String {
        LanguageTag.isWellFormed(raw) ? raw : "und"
    }

    /// The document as an HTML page.
    public func build(_ document: CVDocument, style: DocumentStyle, headings: Headings) -> String {
        render(document, style: style, headings: headings).html
    }

    /// The document as an HTML page, with the text nodes the page contains.
    ///
    /// - Parameters:
    ///   - document: the document to print; it is not validated here.
    ///   - style: the design's stylesheet, with the palette and fonts chosen for it.
    ///   - headings: the section titles in the document's language.
    public func render(_ document: CVDocument, style: DocumentStyle, headings: Headings) -> RenderedDocument {
        let body = body(of: document, headings: headings)
        let page = HTML.element(.html, attributes: [(.lang, Self.languageTag(document.language))], children: [
            head(title: document.person.name, style: style),
            .element(.body, children: [body]),
        ])
        return RenderedDocument(html: "<!DOCTYPE html>" + page.rendered, textNodes: body.textNodes)
    }

    private func head(title: String, style: DocumentStyle) -> HTML {
        .element(.head, children: [
            .element(.meta, attributes: [(.charset, "utf-8")]),
            .element(.title, children: [.text(title)]),
            .trustedStyle(Self.baseStyle),
            .trustedStyle(style.palette.customProperties + style.fonts.customProperties),
            .trustedStyle(style.stylesheet.css),
        ])
    }

    private func body(of document: CVDocument, headings: Headings) -> HTML {
        let sections = SectionHTML(headings: headings)
        let children = [header(of: document.person)] + document.sections.compactMap(sections.render)
        return .element(.main, attributes: [(.class, "cv"), (.dataSchema, "\(document.schemaVersion)")], children: children)
    }

    private func header(of person: Person) -> HTML {
        var children: [HTML] = [.element(.h1, class: "cv-name", text: person.name)]
        children += HTML.optionalParagraph(class: "cv-title", text: person.professionalTitle)
        children += HTML.optionalParagraph(class: "cv-contact", text: person.email)
        children += HTML.optionalParagraph(class: "cv-phone", text: person.phone)
        children += HTML.optionalParagraph(class: "cv-location", text: person.location)
        children += HTML.optionalAnchor(class: "cv-website", to: person.website)
        return .element(.header, class: "cv-header", children: children)
    }
}
