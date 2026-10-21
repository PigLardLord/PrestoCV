/// The work of a PDF's page analysis, in steps: each pass over its words, lines or cells counts the steps it takes. A
/// PDF's geometry is untrusted input (R8): an analysis that would run past its budget refuses the layout, and one whose
/// task is cancelled stops at its next count.
struct AnalysisWork {
    private let budget: Int
    private var steps = 0

    init(budget: Int) {
        self.budget = budget
    }

    /// Counts the steps of a pass.
    /// - Throws: `CancellationError` once the task is cancelled; `ImportError.tooLarge` past the budget.
    mutating func count(_ steps: Int) throws {
        try Task.checkCancellation()
        self.steps += steps
        guard self.steps <= budget else { throw ImportError.tooLarge }
    }

    /// The steps of a sort of `count` elements, or of as many binary searches in them.
    static func sortSteps(_ count: Int) -> Int {
        count * (Int.bitWidth - max(count, 1).leadingZeroBitCount)
    }
}
