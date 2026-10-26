import Foundation
import Testing
@testable import PrestoCVImporting

/// The readers take the work of a reading; a test of one reader reads with the budget of the standard limits, and
/// fails if that budget is not enough.
extension AnalysisWork {
    static var standard: AnalysisWork { AnalysisWork(budget: ImportLimits.standard.maximumAnalysisSteps) }
}

extension Findings {
    init(document: SourceDocument) {
        self.init(document: document, work: .standard)
    }
}

extension SectionSegmenter {
    static func sections(of document: SourceDocument) -> [Section] {
        var work = AnalysisWork.standard
        do {
            return try sections(of: document, work: &work)
        } catch {
            Issue.record("The sections were not read: \(error)")
            return []
        }
    }
}

// MARK: What a reading costs

/// The CPU time the calling thread spends in `work`, in seconds. A machine that is busy with other work, as the shared
/// ones are, makes a call last longer on the clock and not in CPU time: a bound in seconds on the clock is a bound on
/// the machine as much as on the code.
func cpuSeconds(of work: () -> Void) -> Double {
    func now() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1_000_000_000
    }
    let start = now()
    work()
    return now() - start
}

/// How much more a call costs for `size` than for a quarter of it, the call being `cost(size)` seconds of CPU time, or
/// the steps of a probe that counts them. A pass over the text costs four times as much for four times the text, and a
/// pass over the text for each of its parts sixteen times as much: the same on a fast machine and on a slow one, for
/// steps; seconds of a short run are only as steady as the machine. Each cost is the least of two runs, which leaves out
/// what the first run spends on tables built when they are first used.
func growth(whole size: Int, cost: (Int) -> Double) -> (ratio: Double, seconds: Double) {
    let quarter = min(cost(size / 4), cost(size / 4))
    let whole = min(cost(size), cost(size))
    return (whole / max(quarter, 0.000_001), whole)
}

/// Halfway between the ratio of linear growth, 4, and the ratio of quadratic growth, 16.
let linearGrowthBound = 8.0

/// Expects the cost of a reading to grow with its text and not faster. A reading that costs less than 50 milliseconds at
/// the whole size is cheap whichever way it grows, and its ratio is a ratio of noise.
func expectLinear(
    _ what: String, whole size: Int, cost: (Int) -> Double, sourceLocation: SourceLocation = #_sourceLocation
) {
    let found = growth(whole: size, cost: cost)
    #expect(
        found.seconds < 0.05 || found.ratio < linearGrowthBound,
        "\(what): \(found.seconds) s of CPU for the whole, \(found.ratio) times a quarter of it",
        sourceLocation: sourceLocation
    )
}
