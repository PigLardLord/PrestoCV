import Foundation

/// How late a job is, read one way wherever the draft takes the latest job (the order of the jobs, the opening of a summary, the job
/// that takes the duties the person said with no job): by the year of the end date, whatever else the date says ("2018" is later than
/// "March 2015", "gennaio 2018" than "marzo 2016"); a job that goes on now is the latest of all; the year of the start settles a tie.
struct JobRecency: Comparable, Sendable {
    /// Whether the job goes on now: the person says so, or the job has no end date.
    let isOngoing: Bool
    let endYear: Int?
    let startYear: Int?

    init(_ job: Experience) {
        isOngoing = job.current || job.endDate.presentValue == nil
        endYear = Self.year(in: job.endDate)
        startYear = Self.year(in: job.startDate)
    }

    /// The latest run of four digits of `date`, as the year it names.
    static func year(in date: String?) -> Int? {
        guard let date else { return nil }
        return Digits.runs(in: Digits.ascii(date)).filter { $0.count == 4 }.compactMap { Int($0) }.max()
    }

    /// The numbers of `jobs`, the latest first, the earlier in the draft first on a tie.
    static func latestFirst(_ jobs: [Experience]) -> [Int] {
        let recency = jobs.map(JobRecency.init)
        return jobs.indices.sorted { left, right in
            recency[left] == recency[right] ? left < right : recency[left] > recency[right]
        }
    }

    static func < (left: JobRecency, right: JobRecency) -> Bool {
        (left.isOngoing ? 1 : 0, left.endYear ?? Int.min, left.startYear ?? Int.min)
            < (right.isOngoing ? 1 : 0, right.endYear ?? Int.min, right.startYear ?? Int.min)
    }
}
