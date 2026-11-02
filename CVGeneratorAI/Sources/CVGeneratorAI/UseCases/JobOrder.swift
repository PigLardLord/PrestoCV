import Foundation

/// The order in which a CV lists the jobs of a grounded draft (#202): the latest first, read as everywhere else in the draft
/// (`JobRecency.latestFirst`), so the job the summary opens with is the one the CV lists first.
///
/// It reads only what the grounded draft keeps, so a year the description does not back orders nothing. A job with no year keeps
/// its place among the others, as the model listed them, and so do jobs of the same years.
enum JobOrder {
    /// The draft with its jobs in the order of a CV, and all the rest as it is.
    static func ordered(_ draft: CVData) -> CVData {
        CVData(
            personalInfo: draft.personalInfo, summary: draft.summary, experience: ordered(draft.experience), education: draft.education,
            skills: draft.skills, languages: draft.languages, certifications: draft.certifications, interests: draft.interests
        )
    }

    static func ordered(_ jobs: [Experience]) -> [Experience] {
        JobRecency.latestFirst(jobs).map { jobs[$0] }
    }
}
