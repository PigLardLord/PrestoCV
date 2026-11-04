import Foundation

/// How late a job is, read one way wherever the draft takes the latest job (the order in which the CV lists the jobs, the opening of
/// a summary, the job that takes the duties the person said with no job): a job the person says goes on now is the latest of all,
/// then a job with no end date, which may go on; then the year of the end date, whatever else the date says ("2018" is later than
/// "March 2015", "gennaio 2018" than "marzo 2016"); the year of the start settles a tie.
struct JobRecency: Comparable, Sendable {
    /// Whether the job goes on: the person says so, it has no end date (it may go on), or it has ended.
    enum Standing: Int, Comparable, Sendable {
        case ended, open, current

        static func < (left: Standing, right: Standing) -> Bool { left.rawValue < right.rawValue }
    }

    let standing: Standing
    let endYear: Int?
    let startYear: Int?

    init(_ job: Experience) {
        standing = job.current ? .current : job.endDate.presentValue == nil ? .open : .ended
        endYear = Self.year(in: job.endDate)
        startYear = Self.year(in: job.startDate)
    }

    /// Whether a date of the job names a year, so the job has a place among the others.
    var isDated: Bool { endYear != nil || startYear != nil }

    /// The latest run of four digits of `date`, as the year it names.
    static func year(in date: String?) -> Int? {
        guard let date else { return nil }
        return Digits.runs(in: Digits.ascii(date)).filter { $0.count == 4 }.compactMap { Int($0) }.max()
    }

    /// The numbers of `jobs`, the latest first: the current ones, then the others, each sorted in the places it takes, the earlier in
    /// the draft first on a tie. A job with no year keeps its place: nothing tells where it belongs, and the model lists the jobs in an
    /// order of its own (the description's, or the newest first). The CV lists the jobs in this order (`JobOrder`), so the latest job
    /// of the draft is the one the CV lists first.
    static func latestFirst(_ jobs: [Experience]) -> [Int] {
        let recency = jobs.map(JobRecency.init)
        let groups = [jobs.indices.filter { jobs[$0].current }, jobs.indices.filter { !jobs[$0].current }]
        return groups.flatMap { numbers in
            let places = numbers.indices.filter { recency[numbers[$0]].isDated }
            let sorted = places.map { numbers[$0] }.sorted { left, right in
                recency[left] == recency[right] ? left < right : recency[left] > recency[right]
            }
            var ordered = numbers
            for (place, number) in zip(places, sorted) {
                ordered[place] = number
            }
            return ordered
        }
    }

    static func < (left: JobRecency, right: JobRecency) -> Bool {
        (left.standing, left.endYear ?? Int.min, left.startYear ?? Int.min)
            < (right.standing, right.endYear ?? Int.min, right.startYear ?? Int.min)
    }
}
