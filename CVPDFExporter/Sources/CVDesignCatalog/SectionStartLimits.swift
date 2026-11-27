/// What a design may set on a section's title, on its start and on what holds them (#467). The builder reserves room below
/// the title's last line for the title's bottom padding, bottom border and bottom margin and for the line that follows, and
/// keeps the title whole; a design that sets more below the title, or lays the title or the start out as anything but a
/// block, could leave the title alone at the foot of a page. Neither can a section or the document be a flex or grid
/// container: printed, such a container cuts its lines at a page's end and leaves a start at a page's foot. The check reads
/// the canonical rule, so every spelling of a value counts.
enum SectionStartLimits {
    static let titleSpacing = "a section title's bottom padding and bottom margin are at most 1em or 12pt each (#467)"
    static let titleDisplay = "a section title stays display: block (#467)"
    static let start = "a section start takes no display other than block and no bottom padding, border or margin (#467)"
    static let container = "the document and its sections stay display: block, since flex and grid cut lines at a page's end (#467)"

    /// `selectors` and `declarations` are canonical: selectors joined by ",", declarations `name:value` joined by ";".
    static func check(selectors: String, declarations: String) throws(CSSRejection) {
        let subjects = selectors.split(separator: ",").map(Compound.init(subjectOf:))
        let rules = declarations.split(separator: ";").map { d in
            let parts = d.split(separator: ":", maxSplits: 1)
            return (name: String(parts[0]), values: parts[1].split(separator: " ").map(String.init))
        }
        if subjects.contains(where: { $0.couldMatch(element: "h2", className: "cv-section-title") }) {
            for rule in rules { try title(rule.name, rule.values) }
        }
        if subjects.contains(where: { $0.couldMatch(element: "div", className: "cv-section-start") }) {
            for rule in rules { try start(rule.name, rule.values) }
        }
        if subjects.contains(where: { $0.couldMatch(element: "main", className: "cv")
            || $0.couldMatch(element: "section", className: "cv-section", attributes: ["data-section"]) }),
           rules.contains(where: { $0.name == "display" && $0.values != ["block"] }) {
            throw CSSRejection(reason: container)
        }
    }

    private static func title(_ name: String, _ values: [String]) throws(CSSRejection) {
        let limit = MarkupContract.titleBottomSpacing
        let bounds = LengthBounds(pt: 0...limit.pt, em: 0...limit.em, percent: nil)
        switch name {
        case "display" where values != ["block"]: throw CSSRejection(reason: titleDisplay)
        case "padding-bottom", "margin-bottom", "padding", "margin":
            try require(bottom(name, values), within: bounds, else: titleSpacing)
        default: break
        }
    }

    private static func start(_ name: String, _ values: [String]) throws(CSSRejection) {
        let zero = LengthBounds(pt: 0...0, em: 0...0, percent: nil)
        switch name {
        case "display" where values != ["block"]: throw CSSRejection(reason: start)
        case "padding-bottom", "margin-bottom", "padding", "margin":
            try require(bottom(name, values), within: zero, else: start)
        case "border", "border-bottom":
            // A border is drawn when its style is not none; with no width it is medium (3px).
            let style = values.first { propertyKeywords["border", default: []].contains($0) }
            let width = values.first { $0 != style && !$0.hasPrefix("var(") }
            if let style, style != "none" { try require(width ?? "medium", within: zero, else: start) }
        default: break
        }
    }

    /// The bottom component of a padding or margin: the only value, or the third of `top horizontal bottom [left]`.
    private static func bottom(_ name: String, _ values: [String]) -> String {
        name.hasSuffix("-bottom") || values.count < 3 ? values[0] : values[2]
    }

    /// Throws `reason` unless `value` is one length within `bounds`.
    private static func require(_ value: String, within bounds: LengthBounds, else reason: String) throws(CSSRejection) {
        do {
            let tokens = try CSSTokenizer.tokenize(value)
            guard tokens.count == 1 else { throw CSSRejection(reason: reason) }
            _ = try CSSValue.length(tokens[0], bounds)
        } catch {
            throw CSSRejection(reason: reason)
        }
    }

    /// The rightmost compound of a canonical selector, the element it styles: what could it match, ignoring its
    /// pseudo-classes, which only narrow it?
    struct Compound {
        var element: String?
        var classes: Set<String> = []
        var attributes: Set<String> = []

        init(subjectOf selector: Substring) {
            let compound = selector.split(whereSeparator: { " >+~".contains($0) }).last ?? ""
            let name = compound.prefix { $0.isLetter || $0.isNumber }
            element = name.isEmpty ? nil : String(name)
            for part in compound.split(separator: "[", omittingEmptySubsequences: false).dropFirst() { attributes.insert(String(part.prefix { $0 != "=" })) }
            var rest = compound.dropFirst(name.count)
            while let dot = rest.firstIndex(of: ".") {
                let className = rest[rest.index(after: dot)...].prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                classes.insert(String(className))
                rest = rest[className.endIndex...]
            }
        }

        func couldMatch(element e: String, className: String, attributes allowed: Set<String> = []) -> Bool {
            (element == nil || element == e) && classes.isSubset(of: [className]) && attributes.isSubset(of: allowed)
        }
    }
}
