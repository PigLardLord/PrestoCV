import Foundation

// MARK: - One Page Fit

/// Keeps a CV that runs a little over one page on one page, instead of leaving a few lines alone on a second one.
///
/// A design says how far it tightens: under classes of the root element, its stylesheet closes up the space between
/// its blocks and its lines, within bounds that keep the page easy to read. The renderer tries the steps of `steps`,
/// from the lightest, on a CV that takes two pages with the design's own spacing, and keeps the first print that takes
/// one page. A CV that no step brings onto one page is printed as the design lays it out, with the rules of
/// `PageBreakManager`.
///
/// What no step ever does: change the size of the text, narrow the page's side margins, or take the margin at the foot
/// of the page below `minimumBottomMargin`.
public struct OnePageFit: Sendable, Equatable {

    /// The class of the root element under which a design tightens its spacing: set on every step
    public static let className = "fit-one-page"

    /// The class that a design's rules for the compact step follow: set on the steps after the first, together with `className`
    public static let compactClassName = "fit-one-page-compact"

    /// Every class a step puts on the root element
    public static let classNames: Set<String> = [className, compactClassName]

    /// The least margin at the foot of a page, in millimetres: a printer cannot print closer to the edge, and a page is
    /// easy to read with that much white below its text
    public static let minimumBottomMarginInMillimetres = 10.0

    /// The margin at the foot of a page never shrinks below this, in points: `minimumBottomMarginInMillimetres`, at 72
    /// points to the inch of 25.4 mm
    public static let minimumBottomMargin = minimumBottomMarginInMillimetres / 25.4 * 72

    /// One print of a CV with its spacing tightened
    public struct Step: Sendable, Equatable {
        /// The classes the root element has during this print
        public let classNames: [String]
        /// Whether the margin at the foot of the page shrinks, down to `minimumBottomMargin`, during this print
        public let shrinksBottomMargin: Bool

        public init(classNames: [String], shrinksBottomMargin: Bool) {
            self.classNames = classNames
            self.shrinksBottomMargin = shrinksBottomMargin
        }
    }

    /// The design's own spacing with its tightening rules, which keep the spacing a reader is used to; and then the same
    /// rules with the compact ones on top, which also set small lists on one line, and the foot margin at its minimum
    public static let standardSteps = [
        Step(classNames: [className], shrinksBottomMargin: false),
        Step(classNames: [className, compactClassName], shrinksBottomMargin: true)
    ]

    /// The steps to try, lightest first
    public let steps: [Step]

    public init(steps: [Step] = OnePageFit.standardSteps) {
        self.steps = steps
    }

    /// A renderer that prints every CV as its design lays it out
    public static let disabled = OnePageFit(steps: [])

    /// Whether a CV that takes `pageCount` pages with the design's own spacing is printed again tightened:
    /// a CV of three pages or more is longer than any tightening could bring onto one page
    public func triesTightening(pageCount: Int) -> Bool {
        pageCount == 2 && !steps.isEmpty
    }

    /// Whether the tightened print, which takes `pageCount` pages, is the one to keep
    public func keepsTightened(pageCount: Int) -> Bool {
        pageCount == 1
    }

    /// The margin at the foot of the page during `step`, given the margin the page normally has
    public func bottomMargin(during step: Step, normal: Double) -> Double {
        step.shrinksBottomMargin ? min(normal, Self.minimumBottomMargin) : normal
    }
}
