import Foundation

/// Which positions of the PDF text a placed text has taken.
struct SpanClaims {
    private var taken: [Bool]

    init(count: Int) { taken = [Bool](repeating: false, count: count) }

    func isFree(_ start: Int, length: Int) -> Bool { !taken[start..<start + length].contains(true) }

    mutating func claim(_ start: Int, length: Int) { setTaken(true, start, length) }

    mutating func release(_ start: Int, length: Int) { setTaken(false, start, length) }

    private mutating func setTaken(_ value: Bool, _ start: Int, _ length: Int) {
        for position in start..<start + length { taken[position] = value }
    }
}

/// A depth-first search for a span of the PDF text for every expected text, none shared, within a step budget.
/// Identical texts take increasing positions, so their permutations are never explored twice, and a choice that leaves
/// a later text without any free span is undone at once.
struct SpanSearch {
    static let defaultStepBudget = 100_000

    private let stepBudget: Int
    private let texts: [ExpectedText]
    private let groups: [Range<Int>]
    private var claims: SpanClaims
    private var chosen: [Int]
    private var steps = 0
    private var exhausted = false

    init(_ expected: ExpectedTexts, pdfLength: Int, stepBudget: Int = SpanSearch.defaultStepBudget) {
        self.stepBudget = stepBudget
        texts = expected.items
        groups = expected.groups
        claims = SpanClaims(count: pdfLength)
        chosen = [Int](repeating: -1, count: expected.items.count)
    }

    /// Whether every text has a span of its own. A search that exceeds its budget finds none.
    mutating func placesEveryText() -> Bool {
        everyLaterTextCanStillBePlaced(after: -1) && place(0)
    }

    private mutating func place(_ index: Int) -> Bool {
        guard index < texts.count else { return true }
        guard consumeStep() else { return false }
        return placeOnSomeSpan(index)
    }

    private mutating func placeOnSomeSpan(_ index: Int) -> Bool {
        for start in candidateStarts(ofTextAt: index) {
            if tryPlace(index, at: start) { return true }
            if exhausted { return false }
        }
        return false
    }

    private mutating func consumeStep() -> Bool {
        steps += 1
        exhausted = steps > stepBudget
        return !exhausted
    }

    /// Claims the span and places the later texts; the claim is released unless they all fit.
    private mutating func tryPlace(_ index: Int, at start: Int) -> Bool {
        claims.claim(start, length: texts[index].length)
        chosen[index] = start
        if everyLaterTextCanStillBePlaced(after: index), place(index + 1) { return true }
        claims.release(start, length: texts[index].length)
        return false
    }

    private func candidateStarts(ofTextAt index: Int) -> [Int] {
        let continuesGroup = index > 0 && texts[index].needle == texts[index - 1].needle
        let floor = continuesGroup ? chosen[index - 1] : -1
        return texts[index].candidates.filter { $0 > floor && claims.isFree($0, length: texts[index].length) }
    }

    /// A necessary condition: every group of identical later texts still has at least as many disjoint free spans as
    /// it has members left to place.
    private func everyLaterTextCanStillBePlaced(after placed: Int) -> Bool {
        for group in groups where group.upperBound > placed + 1 {
            let remaining = group.upperBound - max(group.lowerBound, placed + 1)
            let floor = group.contains(placed) ? chosen[placed] : -1
            guard texts[group.lowerBound].disjointSpans(after: floor, free: claims) >= remaining else { return false }
        }
        return true
    }
}
