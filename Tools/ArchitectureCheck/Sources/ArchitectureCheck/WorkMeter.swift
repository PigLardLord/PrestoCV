/// Counts the steps of a search and says when a budget is spent, so that a file built to make the search explode ends it.
/// A search that runs out of budget gives up, and what it was looking for is not found.
final class WorkMeter {
    let budget: Int
    private(set) var steps = 0

    init(budget: Int) { self.budget = budget }

    /// Records steps, whether or not the budget allows them.
    func charge(_ count: Int = 1) { steps += count }

    /// Whether more than the budget has been spent.
    var isExhausted: Bool { steps > budget }
}
