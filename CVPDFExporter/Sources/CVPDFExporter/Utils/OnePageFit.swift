import Foundation

// MARK: - One Page Fit

/// Keeps a CV that runs a little over one page on one page, instead of leaving a few lines alone on a second one.
///
/// A design says how far it tightens: under the `fit-one-page` class of the root element, its stylesheet closes up
/// the space between its blocks and its lines, within bounds that keep the page easy to read. A CV that takes two
/// pages with the design's own spacing is printed again with the class set, and that print is kept only when it takes
/// one page. Any other CV is printed as the design lays it out, with the rules of `PageBreakManager`.
public struct OnePageFit: Sendable {

    /// The class of the root element under which a design tightens its spacing
    public static let className = "fit-one-page"

    public init() {}

    /// Whether a CV that takes `pageCount` pages with the design's own spacing is printed again tightened:
    /// a CV of three pages or more is longer than any tightening could bring onto one page
    public func triesTightening(pageCount: Int) -> Bool {
        pageCount == 2
    }

    /// Whether the tightened print, which takes `pageCount` pages, is the one to keep
    public func keepsTightened(pageCount: Int) -> Bool {
        pageCount == 1
    }
}
