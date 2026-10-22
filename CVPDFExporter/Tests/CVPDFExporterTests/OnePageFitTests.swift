import Testing
import Foundation
@testable import CVPDFExporter

@Suite("One page fit")
struct OnePageFitTests {

    static let designs = ["professional", "modern", "minimal"]

    // MARK: - When the renderer tries to tighten

    @Test("only a CV of two pages is printed again with its spacing tightened", arguments: [(1, false), (2, true), (3, false), (8, false)])
    func triesTighteningTwoPagesOnly(pageCount: Int, tries: Bool) {
        #expect(OnePageFit().triesTightening(pageCount: pageCount) == tries)
    }

    @Test("a renderer without steps prints every CV as its design lays it out", arguments: [1, 2, 3])
    func disabledNeverTightens(pageCount: Int) {
        #expect(!OnePageFit.disabled.triesTightening(pageCount: pageCount))
    }

    @Test("the tightened print is kept only when it takes one page", arguments: [(1, true), (2, false), (3, false)])
    func keepsTightenedOnOnePageOnly(pageCount: Int, keeps: Bool) {
        #expect(OnePageFit().keepsTightened(pageCount: pageCount) == keeps)
    }

    // MARK: - The steps

    @Test("the first step only tightens the design's spacing, and every later step adds to it")
    func stepsGrowFromTheLightest() throws {
        let steps = OnePageFit.standardSteps
        let first = try #require(steps.first)

        #expect(first.classNames == [OnePageFit.className])
        #expect(!first.shrinksBottomMargin)
        for (lighter, heavier) in zip(steps, steps.dropFirst()) {
            #expect(Set(heavier.classNames).isSuperset(of: lighter.classNames))
            #expect(heavier.classNames.count > lighter.classNames.count)
        }
        #expect(Set(steps.flatMap(\.classNames)) == OnePageFit.classNames)
    }

    @Test("the foot margin shrinks only in a step that says so, and never below its minimum")
    func footMarginHasAFloor() throws {
        let fit = OnePageFit()
        let tightening = try #require(fit.steps.first { !$0.shrinksBottomMargin })
        let shrinking = try #require(fit.steps.first { $0.shrinksBottomMargin })

        #expect(fit.bottomMargin(during: tightening, normal: 43) == 43)
        #expect(fit.bottomMargin(during: shrinking, normal: 43) == OnePageFit.minimumBottomMargin)
        #expect(fit.bottomMargin(during: shrinking, normal: 72) == OnePageFit.minimumBottomMargin)
        #expect(fit.bottomMargin(during: shrinking, normal: 20) == 20, "A margin already below the minimum is not raised")
        #expect(OnePageFit.minimumBottomMargin >= 28)
    }

    // MARK: - What the designs do under the classes

    /// A rule of a stylesheet: its selectors and its declarations
    private struct Rule {
        let selectors: [String]
        let declarations: [(property: String, value: String)]
    }

    /// The rules of a stylesheet that are not inside an at-rule, comments left out
    private static func rules(in css: String) -> [Rule] {
        var text = css
        while let start = text.range(of: "/*"), let end = text.range(of: "*/", range: start.upperBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }
        var rules: [Rule] = []
        var depth = 0, head = "", body = ""
        var insideAtRule = false
        for character in text {
            switch character {
            case "{":
                depth += 1
                if depth == 1 {
                    insideAtRule = head.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("@")
                } else {
                    body.append(character)
                }
            case "}":
                depth -= 1
                if depth == 0 {
                    if !insideAtRule { rules.append(rule(head: head, body: body)) }
                    head = ""; body = ""; insideAtRule = false
                } else if depth > 0 {
                    body.append(character)
                }
            default:
                if depth == 0 { head.append(character) } else { body.append(character) }
            }
        }
        return rules
    }

    private static func rule(head: String, body: String) -> Rule {
        let selectors = head.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let declarations = body.split(separator: ";").compactMap { declaration -> (property: String, value: String)? in
            guard let colon = declaration.firstIndex(of: ":") else { return nil }
            return (declaration[..<colon].trimmingCharacters(in: .whitespacesAndNewlines),
                    declaration[declaration.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return Rule(selectors: selectors, declarations: declarations)
    }

    /// The rules of a design that apply only while the root element has a class of a step
    private static func fitRules(of id: String) throws -> [Rule] {
        let url = try #require(
            Bundle.module.url(forResource: id, withExtension: "mcvt", subdirectory: "Templates/Bundled"),
            "Bundled template '\(id)' should be in the module bundle"
        )
        let package = try JSONDecoder().decode(TemplatePackage.self, from: Data(contentsOf: url))
        return rules(in: package.cssContent).filter { rule in
            rule.selectors.contains { selector in OnePageFit.classNames.contains { selector.contains(".\($0)") } }
        }
    }

    private static func points(_ value: String) -> Double? {
        guard value.hasSuffix("pt") else { return nil }
        return Double(value.dropLast(2))
    }

    @Test("every bundled design says how it tightens its spacing, in every step", arguments: designs)
    func bundledDesignsTighten(id: String) throws {
        let rules = try Self.fitRules(of: id)

        for className in OnePageFit.classNames.sorted() {
            #expect(rules.contains { $0.selectors.contains { $0.contains(".\(className)") } }, "\(id) has no rules for .\(className)")
        }
    }

    @Test("a rule of a step starts at the root element, so that it cannot reach a page that is not tightened", arguments: designs)
    func fitRulesStartAtTheRoot(id: String) throws {
        for rule in try Self.fitRules(of: id) {
            for selector in rule.selectors {
                #expect(selector.hasPrefix("html."), "\(id): \(selector) does not start at the root element")
            }
        }
    }

    /// What a step may set: the space between lines and blocks, and how a small list is laid out. Never a size of text,
    /// a width, a zoom or a transform. The side margins of the page are the page setup's, not the design's.
    private static let allowedProperties: Set<String> = [
        "line-height", "padding", "padding-top", "padding-bottom", "margin", "margin-top", "margin-bottom",
        "margin-left", "margin-right", "gap", "row-gap", "display", "vertical-align"
    ]

    @Test("a step changes the spacing and the layout of lists, never the size of the text or the width of the page", arguments: designs)
    func stepsKeepTextSizeAndWidth(id: String) throws {
        for rule in try Self.fitRules(of: id) {
            for (property, value) in rule.declarations {
                let allowed = Self.allowedProperties.contains(property) || property.hasPrefix("--spacing-")
                #expect(allowed, "\(id): \(rule.selectors.joined(separator: ", ")) sets \(property): \(value)")
            }
        }
    }

    @Test("a step never sets lines closer than a fifth above the size of the text", arguments: designs)
    func lineHeightHasAFloor(id: String) throws {
        let values = try Self.fitRules(of: id).flatMap { $0.declarations.filter { $0.property == "line-height" }.map(\.value) }

        #expect(!values.isEmpty)
        for value in values {
            #expect((Double(value) ?? 0) >= 1.2, "\(id): line-height \(value) is below 1.2")
        }
    }

    /// The least space a design keeps, in its tightest step, at a place where blocks follow each other, in points
    struct SpacingFloor: Sendable, CustomTestStringConvertible {
        let design: String, selector: String, property: String, minimum: Double
        var testDescription: String { "\(design) \(selector) \(property) >= \(minimum)pt" }
    }

    static let floors = [
        SpacingFloor(design: "professional", selector: ".section + .section", property: "margin-top", minimum: 8),
        SpacingFloor(design: "professional", selector: ".item + .item", property: "margin-top", minimum: 5),
        SpacingFloor(design: "minimal", selector: "html.\(OnePageFit.compactClassName)", property: "--spacing-lg", minimum: 14),
        SpacingFloor(design: "minimal", selector: "html.\(OnePageFit.compactClassName)", property: "--spacing-md", minimum: 9),
        SpacingFloor(design: "modern", selector: "section + section", property: "margin-top", minimum: 6),
        SpacingFloor(design: "modern", selector: ".job-entry + .job-entry", property: "margin-top", minimum: 4)
    ]

    @Test("the tightest step keeps the least space between sections and between entries", arguments: floors)
    func spacingHasAFloor(floor: SpacingFloor) throws {
        let values = try Self.fitRules(of: floor.design)
            .filter { rule in rule.selectors.contains { $0.contains(floor.selector) } }
            .flatMap { $0.declarations.filter { $0.property == floor.property }.map(\.value) }

        #expect(!values.isEmpty, "\(floor.design) has no \(floor.property) for \(floor.selector)")
        for value in values {
            #expect((Self.points(value) ?? 0) >= floor.minimum, "\(floor.design): \(floor.selector) has \(floor.property) \(value), below \(floor.minimum)pt")
        }
    }
}
