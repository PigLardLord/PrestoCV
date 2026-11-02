import Foundation

/// The order in which a CV lists the jobs of a grounded draft (#202): the jobs that go on now first, then the others by their
/// latest year (the end, else the start), the newest first.
///
/// It reads only what the grounded draft keeps, so a year the description does not back orders nothing. A job with no year keeps
/// its place among the others, as the model listed them, and so do jobs of the same year: nothing tells where they belong, and the
/// model lists the jobs in an order of its own (the description's, or the newest first) that moving them would only break.
enum JobOrder {
    /// The draft with its jobs in the order of a CV, and all the rest as it is.
    static func ordered(_ draft: CVData) -> CVData {
        CVData(
            personalInfo: draft.personalInfo, summary: draft.summary, experience: ordered(draft.experience), education: draft.education,
            skills: draft.skills, languages: draft.languages, certifications: draft.certifications, interests: draft.interests
        )
    }

    static func ordered(_ jobs: [Experience]) -> [Experience] {
        newestFirst(jobs.filter(\.current)) + newestFirst(jobs.filter { !$0.current })
    }

    /// The jobs that have a year, sorted by it in the places they take; those without one stay where they are.
    private static func newestFirst(_ jobs: [Experience]) -> [Experience] {
        let dated = jobs.indices.compactMap { index in latestYear(of: jobs[index]).map { (index: index, year: $0) } }
        let sorted = dated.sorted { $0.year != $1.year ? $0.year > $1.year : $0.index < $1.index }

        var ordered = jobs
        for (place, job) in zip(dated, sorted) {
            ordered[place.index] = jobs[job.index]
        }
        return ordered
    }

    private static func latestYear(of job: Experience) -> Int? {
        JobRecency.year(in: job.endDate) ?? JobRecency.year(in: job.startDate)
    }
}
