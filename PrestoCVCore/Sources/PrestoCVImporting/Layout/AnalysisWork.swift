/// The work of reading a CV, in steps: each pass over a PDF's words, lines or cells, and each search over the lines of
/// a section, counts the steps it takes. The text of a CV, pasted or read from a PDF, is untrusted input (R8): a
/// reading that would run past its budget refuses the text, and one whose task is cancelled stops at its next count.
/// A PDF is analysed and read within one budget.
struct AnalysisWork {
    private let budget: Int
    private(set) var steps = 0

    init(budget: Int) {
        self.budget = budget
    }

    /// Counts the steps of a pass.
    /// - Throws: `CancellationError` once the task is cancelled; `LimitReached` with its steps past the budget.
    mutating func count(_ steps: Int) throws {
        try Task.checkCancellation()
        self.steps += steps
        guard self.steps <= budget else { throw LimitReached(.steps) }
    }

    /// The steps of a sort of `count` elements, or of as many binary searches in them.
    static func sortSteps(_ count: Int) -> Int {
        count * (Int.bitWidth - max(count, 1).leadingZeroBitCount)
    }
}
