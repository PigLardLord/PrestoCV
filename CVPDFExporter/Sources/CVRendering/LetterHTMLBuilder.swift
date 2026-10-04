import Foundation
import CVDocumentModel

/// Why a letter could not be turned into markup.
public enum LetterBuildFailure: Error, Equatable, Sendable {
    /// The letter is not one that can be rendered; the reason is the validator's.
    case invalid(String)
    case conventions(LetterConventionsCatalog.Failure)
    /// The built-in stylesheet was refused by the CSS policy. A test holds it to the policy, so this is a defect.
    case stylesheet(String)
}

/// Produces the cover letter's markup from a `LetterDocument` with the typed builder of ADR 0011: closed tags, per-scalar
/// escaping, links only as parsed `WebLink`s. The structure is specified in markup-contract.md and pinned by golden files.
/// The page writes the salutation, the valediction, the labels and the date from the language's conventions (R13); every
/// other text node is a field of the document. One built-in stylesheet styles it, for every design.
public struct LetterHTMLBuilder: Sendable {
    public init() {}

    /// The builder's own style, as the CV's builder has one: links wrap, and the line breaks of a paragraph and of the closing are
    /// printed. `white-space` is not in the property allow-list, so neither the letter's stylesheet nor a design can set it; the
    /// text is the builder's constant, and it passes through no validation.
    static let baseStyle = DocumentHTMLBuilder.baseStyle + ".letter-paragraph,.letter-closing{white-space:pre-line}"

    /// The letter must pass `LetterDocumentValidator`: a letter that can be rendered is one whose language has conventions,
    /// whose date exists and whose salutation has the name it needs.
    public func render(_ letter: LetterDocument) throws(LetterBuildFailure) -> RenderedDocument {
        do { try LetterDocumentValidator.validate(letter) } catch { throw .invalid(error.reason) }
        let conventions: LetterConventions
        do { conventions = try LetterConventionsCatalog.conventions(for: letter.language) } catch { throw .conventions(error) }
        return try render(letter, conventions: conventions)
    }

    func render(_ letter: LetterDocument, conventions: LetterConventions) throws(LetterBuildFailure) -> RenderedDocument {
        guard let dateLine = conventions.dateLine(place: letter.place, date: letter.date) else { throw .invalid("the date does not exist") }
        guard let salutation = conventions.salutation(letter.recipient.formOfAddress, familyName: letter.recipient.familyName) else {
            throw .invalid("the recipient's family name is required")
        }
        let sheet = try LetterStyle.stylesheet()

        var children: [HTML] = [sender(letter.sender)]
        if let recipient = recipient(letter.recipient) { children.append(recipient) }
        children.append(line(.p, .dateline, dateLine))
        if let reference = present(letter.reference) {
            children.append(node(.p, .reference, [node(.span, .referenceLabel, [.text(conventions.referenceLabel)]), .separator,
                                                  node(.span, .referenceValue, [.text(reference)])]))
        }
        if let subject = present(letter.subject) { children.append(line(.h1, .subject, subject)) }
        children.append(line(.p, .salutation, salutation))
        children += letter.body.compactMap { present($0) }.map { line(.p, .paragraph, $0) }
        if let closing = present(letter.closing) { children.append(line(.p, .closing, closing)) }
        children.append(line(.p, .valediction, conventions.valediction(letter.recipient.formOfAddress)))
        children.append(line(.p, .signature, letter.name))
        let attachments = letter.attachments.compactMap { present($0) }
        if !attachments.isEmpty {
            children.append(node(.section, .attachments, [line(.h2, .attachmentsTitle, conventions.attachmentsLabel)] + attachments.map { line(.p, .attachment, $0) }))
        }

        let body = node(.main, .letter, attrs: [(.dataSchema, "\(letter.schemaVersion)")], children)
        let tree = HTML.element(.html, attributes: [(.lang, DocumentHTMLBuilder.languageTag(letter.language))], children: [
            .element(.head, children: [
                .element(.meta, attributes: [(.charset, "utf-8")]),
                .element(.title, children: [.text(present(letter.subject) ?? letter.name)]),
                .trustedStyle(Self.baseStyle),
                .trustedStyle(LetterStyle.customProperties),
                .trustedStyle(sheet.css),
            ]),
            .element(.body, children: [body]),
        ])
        return RenderedDocument(html: "<!DOCTYPE html>" + tree.rendered, textNodes: body.textNodes)
    }

    // MARK: Blocks

    private func sender(_ person: Person) -> HTML {
        var children: [HTML] = [line(.p, .senderName, person.name)]
        for (cls, value) in [(LetterClass.senderTitle, person.professionalTitle), (.senderEmail, person.email), (.senderPhone, person.phone),
                             (.senderLocation, person.location)] {
            if let value = present(value) { children.append(line(.p, cls, value)) }
        }
        if let website = person.website, let link = WebLink(website) { children.append(node(.a, .senderWebsite, attrs: [(.href, link.url)], [.text(link.url)])) }
        return node(.header, .sender, children)
    }

    /// nil when there is nothing to print: a neutral recipient with no name, company or address.
    private func recipient(_ recipient: LetterRecipient) -> HTML? {
        var children: [HTML] = []
        if let name = present(recipient.name) { children.append(line(.p, .recipientName, name)) }
        if let company = present(recipient.company) { children.append(line(.p, .recipientCompany, company)) }
        children += recipient.address.compactMap { present($0) }.map { line(.p, .recipientAddress, $0) }
        return children.isEmpty ? nil : node(.section, .recipient, children)
    }

    // MARK: Helpers

    /// The value, unless it is missing or blank.
    private func present(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private func node(_ tag: Tag, _ cls: LetterClass, attrs: [(Attr, String)] = [], _ children: [HTML]) -> HTML { el(tag, cls.rawValue, attrs, children) }
    private func line(_ tag: Tag, _ cls: LetterClass, _ text: String) -> HTML { node(tag, cls, [.text(text)]) }
}
