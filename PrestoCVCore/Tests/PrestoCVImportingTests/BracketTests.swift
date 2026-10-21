import Foundation
import Testing
@testable import PrestoCVImporting

/// The sections that split their lines at commas, bars and dashes share one rule: nothing splits inside a pair of
/// brackets. A title that holds a comma in its brackets, "Course (Pro, Advanced)", stays whole in every one of them.
/// Every value here is invented (the corpus README).
@Suite("Brackets in the lines of every section")
struct BracketTests {

    private func imported(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    @Test("Skills: a skill keeps its brackets, and the skills after it are still split")
    func skills() throws {
        let found = try imported("Skills\nSwift (UIKit, SwiftUI), Kotlin; CI/CD (GitHub Actions | Fastlane)")
        #expect(found.cv.skills.map(\.value) == ["Swift (UIKit, SwiftUI)", "Kotlin", "CI/CD (GitHub Actions | Fastlane)"])
        #expect(found.unplaced.isEmpty)
    }

    @Test("Interests: an interest keeps its brackets")
    func interests() throws {
        let found = try imported("Hobbies\nChess (blitz, rapid), Hiking [alpine, winter] · Photography")
        #expect(found.cv.interests.map(\.value) == ["Chess (blitz, rapid)", "Hiking [alpine, winter]", "Photography"])
        #expect(found.unplaced.isEmpty)
    }

    @Test("Experience: a role keeps its brackets, and the employer after it is still read")
    func experience() throws {
        let found = try imported("""
        Experience
        Mobile Developer (iOS, Android), Example Corp | 03/2019 – 05/2021
        - Built the payment screens
        """)
        let job = try #require(found.cv.experience.first)
        #expect(job.role?.value == "Mobile Developer (iOS, Android)")
        #expect(job.employer?.value == "Example Corp")
        #expect(job.period != nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("Education: a degree keeps its brackets, and the school after it is still read")
    func education() throws {
        let found = try imported("""
        Education
        BSc Computer Science (Honours, First Class), Example University | 2010 – 2013
        """)
        let study = try #require(found.cv.education.first)
        #expect(study.degree?.value == "BSc Computer Science (Honours, First Class)")
        #expect(study.school?.value == "Example University")
        #expect(found.unplaced.isEmpty)
    }

    @Test("Courses are read as certifications: the course keeps its brackets, the issuer and the year are read")
    func courses() throws {
        let found = try imported("Courses\nSwift for Beginners (Online, Self-paced) – Example Academy, 2022")
        let course = try #require(found.cv.certifications.first)
        #expect(course.name.value == "Swift for Beginners (Online, Self-paced)")
        #expect(course.issuer?.value == "Example Academy")
        #expect(course.year?.value == 2022)
        #expect(found.unplaced.isEmpty)
    }

    @Test("Projects have no field: each line stays visible whole, with its brackets and what follows them")
    func projects() throws {
        let found = try imported("Projects\nPortfolio App (SwiftUI, CloudKit) – example.dev/portfolio, 2023")
        #expect(found.unplaced.map(\.text) == ["Portfolio App (SwiftUI, CloudKit) – example.dev/portfolio, 2023"])
        #expect(found.cv.certifications.isEmpty)
    }

    @Test("Languages: the words in a language's brackets are no language of their own")
    func languages() throws {
        let found = try imported("Languages\nEnglish (C1, fluent), Italian (B1)")
        #expect(found.cv.languages.map(\.name.value) == ["English", "Italian"])
        #expect(found.cv.languages.map { $0.level?.value } == [.c1, .b1])
    }
}
