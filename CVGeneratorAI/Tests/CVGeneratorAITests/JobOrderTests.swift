import Testing
import Foundation
@testable import CVGeneratorAI

/// The order in which the CV lists the jobs of a grounded draft (#202).
@Suite("JobOrder: the current job first, then the newest")
struct JobOrderTests {
    private func job(_ company: String, from start: String? = nil, to end: String? = nil, current: Bool = false) -> Experience {
        Experience(company: company, startDate: start, endDate: end, current: current)
    }

    private func companies(_ jobs: [Experience]) -> [String] {
        JobOrder.ordered(jobs).map(\.company)
    }

    @Test("The job that goes on now comes first, with or without its years")
    func currentFirst() {
        #expect(companies([job("Nursery", from: "2012", to: "2016"), job("School", from: "2016", current: true)]) == ["School", "Nursery"])
        #expect(companies([job("Nursery"), job("School", current: true)]) == ["School", "Nursery"])
    }

    @Test("The other jobs come by their latest year, the newest first")
    func newestFirst() {
        let jobs = [job("Alpha", from: "2010", to: "2012"), job("Beta", from: "2012", to: "2016"), job("Gamma", from: "2016", to: "2019")]

        #expect(companies(jobs) == ["Gamma", "Beta", "Alpha"])
    }

    @Test("The latest year is that of the end, else that of the start")
    func endElseStart() {
        #expect(companies([job("Beta", from: "2016"), job("Alpha", from: "2010", to: "2018")]) == ["Alpha", "Beta"])
        #expect(companies([job("Alpha", to: "2016 – 2018"), job("Beta", from: "2017")]) == ["Alpha", "Beta"])
    }

    @Test("A job without a year keeps its place among the others")
    func undatedJobKeepsItsPlace() {
        let jobs = [job("Beta", from: "2012", to: "2014"), job("Alpha"), job("Gamma", from: "2016", to: "2019")]

        #expect(companies(jobs) == ["Gamma", "Alpha", "Beta"])
        #expect(companies([job("Molinette"), job("Sorriso", from: "2016", to: "2019")]) == ["Molinette", "Sorriso"])
    }

    @Test("Jobs of the same latest year keep the model's order, and so do two jobs that go on now")
    func sameYearKeepsTheOrder() {
        #expect(companies([job("Alpha", from: "2012", to: "2016"), job("Beta", from: "2014", to: "2016")]) == ["Alpha", "Beta"])
        #expect(companies([job("Alpha", from: "2015", current: true), job("Beta", from: "2019", current: true)]) == ["Beta", "Alpha"])
        #expect(companies([job("Alpha", current: true), job("Beta", current: true)]) == ["Alpha", "Beta"])
    }

    @Test("The draft keeps everything but the order of its jobs")
    func draftKeepsItsOtherSections() {
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria Rossi"), summary: "Teacher.",
            experience: [job("Nursery", from: "2012", to: "2016"), job("School", from: "2016", current: true)],
            education: [Education(degree: "Education Sciences")], skills: [Skill(name: "first aid")], languages: [Language(name: "Italian")],
            certifications: [Certification(name: "BLS")], interests: ["chess"])

        let ordered = JobOrder.ordered(draft)

        #expect(ordered.experience.map(\.company) == ["School", "Nursery"])
        #expect(ordered == CVData(
            personalInfo: draft.personalInfo, summary: draft.summary, experience: draft.experience.reversed(), education: draft.education,
            skills: draft.skills, languages: draft.languages, certifications: draft.certifications, interests: draft.interests))
    }
}
