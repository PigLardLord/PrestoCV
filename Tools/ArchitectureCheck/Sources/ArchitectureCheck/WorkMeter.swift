/// Counts the steps of a search and says when a budget is spent, so that a file built to make the search explode ends it.
/// A search that runs out of budget gives up, and what it was looking for is not found.
final class WorkMeter {
    let budget: Int
    private(set) var steps = 0

    init(budget: Int) { self.budget = budget }

    /// Records steps; false once more than the budget has been spent.
    @discardableResult
    func spend(_ count: Int = 1) -> Bool {
        steps += count
        return !isExhausted
    }

    var isExhausted: Bool { steps > budget }
}
