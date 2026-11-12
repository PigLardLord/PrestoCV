import Testing
import PrestoCVPresentation

/// The name a row goes by in the confirmation of its removal and in its delete action: the first text among the fields
/// that name it, or a placeholder of its section, which the view words.
@MainActor
@Suite("Row name")
struct RowNameTests {

    /// The name of the first row of each section, in the order of the sections.
    func names(_ content: EditorContent) -> [RowName] {
        [content.experiences[0].rowName, content.education[0].rowName, content.skills[0].rowName,
         content.languages[0].rowName, content.certifications[0].rowName, content.profiles[0].rowName,
         content.interests[0].rowName]
    }

    @Test("a row is named by the first of its naming fields with text, trimmed, and its removal carries that name")
    func nameIsTheFirstFilledText() {
        let editor = Editing().editor(.blank)
        for section in EditorSection.allCases { editor.addRow(to: section) }
        editor.content.experiences[0].role = "  "
        editor.content.experiences[0].company = " Acme Labs "
        editor.content.experiences[0].location = "Turin"
        editor.content.education[0].degree = "Design"
        editor.content.education[0].school = "Politecnico"
        editor.content.skills[0].name = "Swift"
        editor.content.languages[0].language = "Italian"
        editor.content.certifications[0].issuer = "PMI"
        editor.content.profiles[0].link = "https://example.com/mara"
        editor.content.interests[0].text = "Cycling"

        #expect(names(editor.content) == [
            .text("Acme Labs"), .text("Design"), .text("Swift"), .text("Italian"), .text("PMI"),
            .text("https://example.com/mara"), .text("Cycling"),
        ])
        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)
        #expect(editor.pendingRemoval?.name == .text("Acme Labs"))
    }

    @Test("a row with no naming text goes by its section's placeholder, also while it holds other text")
    func blankRowHasAPlaceholder() {
        let editor = Editing().editor(.blank)
        for section in EditorSection.allCases { editor.addRow(to: section) }
        editor.content.experiences[0].description = "Led a team of five"
        editor.content.skills[0].level = 3

        #expect(names(editor.content) == EditorSection.allCases.map(RowName.placeholder))
        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)
        #expect(editor.pendingRemoval?.name == .placeholder(.experiences))
    }
}
