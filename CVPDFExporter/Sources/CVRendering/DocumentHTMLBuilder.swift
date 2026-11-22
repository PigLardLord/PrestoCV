import Foundation
import CVDocumentModel
import CVDesignCatalog

public struct Headings: Sendable, Equatable {
    public var experience, education, skills, languages, certifications, profiles, interests, summary, present: String
    public var native: String
    public func levelName(_ level: LanguageItem.Level) -> String { level == .native ? native : level.rawValue.uppercased() }
}

/// The builder's output: the HTML and the exact text it contains, one entry per text node. The text is
/// what the PDF must contain, occurrence by occurrence (see `DocumentCompleteness`).
public struct RenderedDocument: Sendable, Equatable {
    public let html: String
    public let textNodes: [String]
}

public struct DocumentHTMLBuilder: Sendable {
    public init() {}

    /// BCP 47-shaped language tags only; anything else becomes "und" (undetermined).
    static func languageTag(_ raw: String) -> String {
        raw.fullyMatches(#"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}"#) ? raw : "und"
    }

    public func build(_ doc: CVDocument, stylesheet: ValidatedStylesheet, palette: Palette,
                      fonts: FontScheme = .system, headings: Headings) -> String {
        render(doc, stylesheet: stylesheet, palette: palette, fonts: fonts, headings: headings).html
    }

    /// The builder's own rules, which a design cannot override, since it cannot use `!important`:
    /// - Every link prints its destination as text, so completeness covers it even where the PDF drops the clickable
    ///   annotation; the base style lets that text wrap, since designs cannot set overflow-wrap.
    /// - A section's title is never alone at the foot of a page (#467). Neither print path honours `break-after: avoid`,
    ///   so the title, kept whole, holds an empty block that may not break across pages, as tall as what must follow its
    ///   last line: where that room is not left, the title moves to the next page with its section. The block reaches the
    ///   title's bottom padding, bottom border and bottom margin at the markup contract's limits, then the next line
    ///   (2.5em or 30pt; 23pt at most in the bundled designs), or at least 150pt when the first entry has a description,
    ///   for its head (title, organisation, place, dates) and first line (143pt at most). Its negative bottom margin
    ///   gives back all but 1px, which makes a title whose block was pushed cross the page's end, so that it moves whole.
    /// - A forced break between a title and what follows it is ignored: after the title, before what follows it in the
    ///   section's start, and around an inline section's start. A break before a section, or after a first entry, stays.
    /// - A block section's start, its title and first block, never breaks across pages where it fits on one, so a short
    ///   first entry moves with its title; a longer start breaks inside, so the entry starts under its title.
    /// - Nothing follows the last line: no bottom margin along the last elements, on `.cv` or on the body, and no bottom
    ///   padding on `.cv`. Space after the last line makes both print paths push out a blank page when the last page is
    ///   full; the page's own margin is the space at its foot (#467).
    /// - The text keeps the design's sizes. On an iPhone, WebKit's text autosizing enlarges the text of a page wider than
    ///   the screen (a 24px title to 30px), and with it on, the iOS print path left titles alone at a page's foot that
    ///   it keeps with their sections once it is off (#467).
    static let baseStyle = "html{-webkit-text-size-adjust:none!important}a{overflow-wrap:anywhere}"
        + ".cv-section-start{break-inside:avoid!important}.cv-section-start>*{break-inside:auto!important}"
        + ".cv-section-start>.cv-section-title{display:flow-root!important;break-inside:avoid!important}"
        + ".cv-section-title::after{content:\"\";display:block;height:\(reserve);margin-bottom:calc(1px - \(reserve));break-inside:avoid}"
        + ".cv-section-start:has(>.cv-entry>.cv-entry-description)>.cv-section-title::after"
        + "{height:\(descriptionReserve);margin-bottom:calc(1px - \(descriptionReserve))}"
        + ".cv-section-title{break-after:auto!important}.cv-section-title~*,.cv-section-title~* *{break-before:auto!important}"
        + ".cv-section-start:has(>.cv-section-title:only-child){break-after:auto!important}"
        + ".cv-section-start:has(>.cv-section-title:only-child)+*{break-before:auto!important}"
        + "body,.cv{margin-bottom:0!important}.cv{padding-bottom:0!important}"
        + (1...maxDepth).map { ".cv" + String(repeating: ">:last-child", count: $0) }.joined(separator: ",")
        + "{margin-bottom:0!important}"

    /// How deep the builder nests elements below `main.cv`: a section, its start, an entry, then a line of the entry
    /// (`p.cv-language > span` is as deep). The builder tests measure it on a document with every kind of section.
    static let maxDepth = 4

    /// Room for the title's bottom padding and bottom margin and its bottom border, at what the markup contract lets a
    /// design set there, then for what must follow the title's last line: the next line, or the head and first line of
    /// a first entry with a description. Each part is in the title's em or in pt, whichever is larger (#467).
    static let reserve = room(following: "max(2.5em,30pt)")
    static let descriptionReserve = room(following: "max(2.5em,150pt)")

    private static func room(following next: String) -> String {
        "calc(2*\(atLeast(MarkupContract.titleBottomSpacing)) + \(atLeast(MarkupContract.borderWidth)) + \(next))"
    }

    private static func atLeast(_ limit: MarkupContract.Limit) -> String {
        func css(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(d) }
        return "max(\(css(limit.em))em,\(css(limit.pt))pt)"
    }

    public func render(_ doc: CVDocument, stylesheet: ValidatedStylesheet, palette: Palette,
                       fonts: FontScheme = .system, headings: Headings) -> RenderedDocument {
        let body = el(.main, "cv", [(.dataSchema, "\(doc.schemaVersion)")],
                      [header(doc.person)] + doc.sections.compactMap { section($0, headings) })
        let tree = HTML.element(.html, attributes: [(.lang, Self.languageTag(doc.language))], children: [
            .element(.head, children: [
                .element(.meta, attributes: [(.charset, "utf-8")]),
                .element(.title, children: [.text(doc.person.name)]),
                .trustedStyle(Self.baseStyle),
                .trustedStyle(palette.customProperties + fonts.customProperties),
                .trustedStyle(stylesheet.css),
            ]),
            .element(.body, children: [body]),
        ])
        return RenderedDocument(html: "<!DOCTYPE html>" + tree.rendered, textNodes: body.textNodes)
    }

    private func header(_ p: Person) -> HTML {
        var children: [HTML] = [el(.h1, "cv-name", [], [.text(p.name)])]
        func line(_ value: String?, _ cls: String) { if let v = value, !v.isEmpty { children.append(el(.p, cls, [], [.text(v)])) } }
        line(p.professionalTitle, "cv-title")
        line(p.email, "cv-contact")
        line(p.phone, "cv-phone")
        line(p.location, "cv-location")
        if let w = p.website, let link = WebLink(w) { children.append(el(.a, "cv-website", [(.href, link.url)], [.text(link.url)])) }
        return el(.header, "cv-header", [], children)
    }

    private func section(_ s: Section, _ h: Headings) -> HTML? {
        /// A section starts with `div.cv-section-start`, its title and `start`, which the base style keeps together (#467);
        /// `rest` follows it. A section with no entry is left out.
        func wrap(_ kind: String, _ title: String, _ items: [HTML], start: [HTML], rest: [HTML]) -> HTML? {
            items.isEmpty ? nil : el(.section, "cv-section", [(.dataSection, kind)],
                                     [el(.div, "cv-section-start", [], [el(.h2, "cv-section-title", [], [.text(title)])] + start)] + rest)
        }
        func blocks(_ kind: String, _ title: String, _ items: [HTML]) -> HTML? {
            wrap(kind, title, items, start: Array(items.prefix(1)), rest: Array(items.dropFirst()))
        }
        /// Inline entries (skills, profiles, interests) share their lines, so their start is the title alone and the
        /// entries follow it, separated by one space: a block of them could be longer than a page.
        func inline(_ kind: String, _ title: String, _ items: [HTML]) -> HTML? {
            wrap(kind, title, items, start: [],
                 rest: items.enumerated().flatMap { $0.offset == 0 ? [$0.element] : [.separator, $0.element] })
        }
        func date(_ d: DocumentDate) -> String {
            guard let m = d.month else { return "\(d.year)" }
            return (m < 10 ? "0\(m)" : "\(m)") + "/\(d.year)"
        }
        func period(_ p: DocumentPeriod?) -> [HTML] {
            guard let p else { return [] }
            let text: String
            switch p.end {
            case .present: text = "\(date(p.start)) – \(h.present)"
            case .date(let e): text = "\(date(p.start)) – \(date(e))"
            case .unspecified: text = date(p.start)          // ended, end not given: never shown as "present"
            }
            return [el(.p, "cv-entry-period", [], [.text(text)])]
        }
        func optional(_ tag: Tag, _ cls: String, _ value: String?) -> [HTML] {
            guard let v = value, !v.isEmpty else { return [] }
            return [el(tag, cls, [], [.text(v)])]
        }
        /// The person's line breaks reach the page as paragraphs: one `<p>` per non-blank line (#21). A blank line adds
        /// nothing, since the paragraphs are already apart.
        func paragraphs(_ cls: String, _ value: String?) -> [HTML] {
            (value ?? "").split(separator: "\n", omittingEmptySubsequences: true)
                .filter { !$0.allSatisfy(\.isWhitespace) }
                .map { el(.p, cls, [], [.text(String($0))]) }
        }
        switch s {
        case .summary(let text):
            return blocks("summary", h.summary, paragraphs("cv-summary", text))
        case .experience(let items):
            return blocks("experience", h.experience, items.map { i in
                el(.article, "cv-entry", [], optional(.h3, "cv-entry-title", i.role) + optional(.p, "cv-entry-subtitle", i.company)
                   + optional(.p, "cv-entry-location", i.location) + period(i.period) + paragraphs("cv-entry-description", i.description))
            })
        case .education(let items):
            return blocks("education", h.education, items.map { i in
                el(.article, "cv-entry", [], optional(.h3, "cv-entry-title", i.degree) + optional(.p, "cv-entry-subtitle", i.school)
                   + period(i.period) + paragraphs("cv-entry-description", i.description))
            })
        case .skills(let items):
            return inline("skills", h.skills, items.map { i in
                el(.span, "cv-skill", i.rating.map { [(.dataRating, "\($0)")] } ?? [], [.text(i.name)])
            })
        case .languages(let items):
            return blocks("languages", h.languages, items.map { i in
                el(.p, "cv-language", [], [.text(i.language + " "), el(.span, "cv-language-level", [], [.text(h.levelName(i.level))])])
            })
        case .certifications(let items):
            return blocks("certifications", h.certifications, items.map { i in
                var children = optional(.h3, "cv-entry-title", i.name) + optional(.p, "cv-entry-subtitle", i.issuer)
                if let y = i.year { children.append(el(.p, "cv-entry-period", [], [.text("\(y)")])) }
                children += paragraphs("cv-entry-description", i.description)
                if let u = i.url, let link = WebLink(u) { children.append(el(.a, "cv-entry-link", [(.href, link.url)], [.text(link.url)])) }
                return el(.article, "cv-entry", [], children)
            })
        case .profiles(let links):
            return inline("profiles", h.profiles, links.compactMap { l in
                guard let link = WebLink(l.url) else { return nil }
                return el(.a, "cv-profile", [(.href, link.url)], [el(.span, "cv-profile-platform", [], [.text(l.platform)]), .separator,
                                                                 el(.span, "cv-profile-url", [], [.text(link.url)])])
            })
        case .interests(let items):
            return inline("interests", h.interests, items.map { el(.span, "cv-interest", [], [.text($0)]) })
        }
    }
}
