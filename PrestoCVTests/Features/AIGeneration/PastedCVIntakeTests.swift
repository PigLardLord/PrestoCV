import Testing
import Foundation
@testable import PrestoCV
import PrestoCVCore
import PrestoCVImporting
import DiagnosticTrace

@Suite("PastedCVIntake - a text given to the AI draft that is already a CV")
struct PastedCVIntakeTests {

    /// An invented CV, pasted as the person has it
    private static let pastedCV = """
    Marcus Hale
    Line Cook
    marcus.hale@example.com | +44 7700 900123
    Leeds, UK

    Summary
    Reliable cook with eight years in busy kitchens.

    Experience
    Line Cook, The Copper Pot, Leeds
    03/2019 – Present
    • Prepared mise en place for 120 covers a night
    • Trained two new commis chefs

    Commis Chef, Harbour Inn, Hull
    2016 – 2019
    • Made sauces and soups
    • Kept the cold room stocked

    Education
    Level 2 Diploma in Professional Cookery, Leeds College, 2016

    Skills
    Knife skills, Food safety, Stock control

    Languages
    English – Native
    Polish – B2
    """

    /// An invented description of the same work, in the person's sentences
    private static let freeDescription = """
    I am a line cook with eight years of experience. I have worked at a restaurant in Leeds since 2019 and before that I was \
    a commis chef at an inn in Hull. I speak English and a bit of Polish. I want a CV to apply for a sous chef job.
    """

    private func intake(limits: ImportLimits = .standard, log: LogSpy = LogSpy()) -> PastedCVIntake {
        PastedCVIntake(
            importer: ImportCV(pdfReader: ScriptedPDFReader(), limits: limits, logger: log, clock: ContinuousClock(), tracer: NoTracer()),
            mapper: ImportedCVMapper()
        )
    }

    @Test("A pasted CV is read by the import: its jobs, duties and languages stay as the person wrote them")
    func pastedCVIsReadAsWritten() throws {
        let read = intake().read(Self.pastedCV)

        let draft = try #require(read, "A text with five sections under their headings and three dated entries is a CV")
        let jobs = draft.cv.relevant_experience
        #expect(jobs.map(\.title) == ["Line Cook", "Commis Chef"], "Every job stays, in the order the CV lists them")
        #expect(jobs.map(\.company) == ["The Copper Pot", "Harbour Inn"])
        #expect(jobs.map(\.period) == ["03/2019 – Present", "2016 – 2019"], "The periods keep the CV's own words")
        #expect(
            jobs.first?.description == "• Prepared mise en place for 120 covers a night\n• Trained two new commis chefs",
            "The duties are the pasted ones, word for word"
        )
        #expect(draft.cv.languages.map(\.name) == ["English", "Polish"], "Both languages stay")
        #expect(draft.cv.languages.map(\.level) == [.native, .b2])
    }

    @Test("A free description is left to the AI draft")
    func freeDescriptionIsLeft() {
        let read = intake().read(Self.freeDescription)

        #expect(read == nil, "Sentences with no heading are a description, not a CV")
    }

    @Test("A text the import refuses, too long for its limits or with no letter, is left to the AI draft without an error")
    func refusedTextIsLeft() {
        let tight = ImportLimits(
            maximumPDFBytes: 1, maximumPages: 1, maximumCharacters: 10,
            maximumWords: 1, maximumLines: 1, maximumCells: 1, maximumAnalysisSteps: 1
        )

        let tooLong = intake(limits: tight).read(Self.pastedCV)
        let noLetter = intake().read(" \n 2019 – 2021 \n")

        #expect(tooLong == nil, "Over the import's limits the text goes to the AI draft, whose own limit words the refusal")
        #expect(noLetter == nil, "A text the import finds empty goes to the AI draft")
    }

    @Test("Reading a pasted CV logs counts only: nothing of its text reaches the log")
    func nothingOfTheTextIsLogged() {
        let log = LogSpy()

        _ = intake(log: log).read(Self.pastedCV)

        let lines = log.lines
        let leaked = ["Marcus", "Hale", "example.com", "7700", "Copper Pot", "mise en place", "Leeds", "Polish"].filter { written in
            lines.contains { $0.contains(written) }
        }
        #expect(!lines.isEmpty, "The import logs what it read, as counts")
        #expect(leaked.isEmpty, "The log never holds the person's text (ADR 0030)")
    }
}
