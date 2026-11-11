import Testing
import PrestoCVPresentation

/// What a row shows in the form when it opens on a page of its own: the texts that name it, its years, the other texts
/// of the line under them, and a language's level. Blank texts and the spaces around them are left out, so the view
/// joins what is there.
@MainActor
@Suite("Entry summary")
struct EntrySummaryTests {

    /// An editor of a blank CV with one row in the section.
    func editor(with section: EditorSection) -> EditorViewModel {
        let editor = Editing().editor(.blank)
        editor.addRow(to: section)
        return editor
    }

    // MARK: Years

    @Test("a job from one year to another shows both years")
    func span() {
        let editor = editor(with: .experiences)
        editor.content.experiences[0].period.start.year = "2015"
        editor.content.experiences[0].period.end.year = " 2019 "

        #expect(editor.content.experiences[0].summary.years == .span(from: "2015", to: "2019"))
    }

    @Test("a job that goes on shows the year it started")
    func ongoing() {
        let editor = editor(with: .experiences)
        editor.content.experiences[0].period.start.year = "2019"
        editor.content.experiences[0].period.isCurrent = true

        #expect(editor.content.experiences[0].summary.years == .ongoing(since: "2019"))
    }

    @Test("a job that goes on with no start year shows no years")
    func ongoingWithoutStart() {
        let editor = editor(with: .experiences)
        editor.content.experiences[0].period.isCurrent = true

        #expect(editor.content.experiences[0].summary.years == nil)
    }

    @Test("a study that starts and ends in the same year shows it once")
    func sameYear() {
        let editor = editor(with: .education)
        editor.content.education[0].period.start.year = "2015"
        editor.content.education[0].period.end.year = "2015"

        #expect(editor.content.education[0].summary.years == .year("2015"))
    }

    @Test("a period with only one of its years shows that year", arguments: [true, false])
    func oneYear(startOnly: Bool) {
        let editor = editor(with: .education)
        if startOnly {
            editor.content.education[0].period.start.year = "2012"
        } else {
            editor.content.education[0].period.end.year = "2012"
        }

        #expect(editor.content.education[0].summary.years == .year("2012"))
    }

    @Test("a period with no years shows none, spaces included")
    func noYears() {
        let editor = editor(with: .education)
        editor.content.education[0].period.start.year = "  "

        #expect(editor.content.education[0].summary.years == nil)
    }

    @Test("a certification shows the year it was issued")
    func certificationYear() {
        let editor = editor(with: .certifications)
        editor.content.certifications[0].name = "Forklift licence"
        editor.content.certifications[0].issued.year = "2021"

        let summary = editor.content.certifications[0].summary

        #expect(summary.title == ["Forklift licence"])
        #expect(summary.years == .year("2021"))
    }

    @Test("a certification with no year shows none")
    func certificationWithoutYear() {
        let editor = editor(with: .certifications)

        #expect(editor.content.certifications[0].summary.years == nil)
    }

    // MARK: Texts

    @Test("a job shows its role and company, trimmed, and its city under them")
    func jobTexts() {
        let editor = editor(with: .experiences)
        editor.content.experiences[0].role = " Store Manager "
        editor.content.experiences[0].company = "Elbe Cargo"
        editor.content.experiences[0].location = "Hamburg\n"

        let summary = editor.content.experiences[0].summary

        #expect(summary.title == ["Store Manager", "Elbe Cargo"])
        #expect(summary.details == ["Hamburg"])
        #expect(summary.level == nil)
    }

    @Test("a blank text is left out of the title and the line")
    func blanksAreLeftOut() {
        let editor = editor(with: .experiences)
        editor.content.experiences[0].role = "   "
        editor.content.experiences[0].company = "Nordlicht Markt"

        let summary = editor.content.experiences[0].summary

        #expect(summary.title == ["Nordlicht Markt"])
        #expect(summary.details.isEmpty)
    }

    @Test("a row with nothing in it has no title, which the view words")
    func emptyTitle() {
        let editor = editor(with: .education)

        let summary = editor.content.education[0].summary

        #expect(summary.title.isEmpty)
        #expect(summary.years == nil)
        #expect(summary.details.isEmpty)
    }

    @Test("a language shows the code of its level, which the view words")
    func languageLevel() {
        let editor = editor(with: .languages)
        editor.content.languages[0].language = "German"
        editor.content.languages[0].proficiency = "native"

        let summary = editor.content.languages[0].summary

        #expect(summary.title == ["German"])
        #expect(summary.level == "native")
        #expect(summary.years == nil)
    }

    @Test("a language with no level picked shows none")
    func languageWithoutLevel() {
        let editor = editor(with: .languages)
        editor.content.languages[0].language = "Danish"

        #expect(editor.content.languages[0].summary.level == nil)
    }

    @Test("a profile shows its platform, and its link under it")
    func profile() {
        let editor = editor(with: .profiles)
        editor.content.profiles[0].platform = "Portfolio"
        editor.content.profiles[0].link = "example.com/lena-hartmann"

        let summary = editor.content.profiles[0].summary

        #expect(summary.title == ["Portfolio"])
        #expect(summary.details == ["example.com/lena-hartmann"])
    }

    @Test("a skill and an interest show their one text")
    func oneTextRows() {
        let editor = Editing().editor(.blank)
        editor.addRow(to: .skills)
        editor.addRow(to: .interests)
        editor.content.skills[0].name = "Scheduling"
        editor.content.interests[0].text = "Sailing"

        #expect(editor.content.skills[0].summary.title == ["Scheduling"])
        #expect(editor.content.interests[0].summary.title == ["Sailing"])
    }
}
