import Testing
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - What the delete action and its question say

@MainActor
@Suite("Editor rows - what the delete action and its question say")
struct CVEditorRowDeleteTextsTests {

    // MARK: - The delete action names the row

    @Test("The delete action of a row names the row, so VoiceOver reads Delete Swift")
    func deleteActionNamesTheRow() {
        let rows: [(row: any EditorRow, name: String)] = [
            (Skill(name: "Swift"), "Swift"),
            (Experience(title: "Ward Nurse"), "Ward Nurse"),
            (Education(degree: "BSc Nursing"), "BSc Nursing"),
            (Language(name: "Italian"), "Italian"),
            (Certification(name: "AWS Architect"), "AWS Architect"),
            (Social(platform: "LinkedIn"), "LinkedIn"),
            (InterestEntry(text: "Chess"), "Chess"),
        ]

        for (row, name) in rows {
            #expect(row.deleteActionLabel == "accessibility.delete_row".localizedWithArgs(name))
            #expect(row.deleteActionLabel.contains(name))
        }
    }

    @Test("The delete action of a blank row names the field that the row starts with")
    func deleteActionOfABlankRow() {
        #expect(Skill().deleteActionLabel == "accessibility.delete_row".localizedWithArgs("field.skill".localized))
        #expect(InterestEntry(text: " ").deleteActionLabel == "accessibility.delete_row".localizedWithArgs("field.interest".localized))
    }

    // MARK: - The question names the kind of row

    @Test("Each kind of row has a question of its own", arguments: EditorSection.allCases)
    func everyKindHasItsOwnQuestion(section: EditorSection) {
        let title = section.deleteConfirmationTitle

        #expect(title != section.deleteConfirmationTitleKey, "The question must be in the catalog")
        let others = EditorSection.allCases.filter { $0 != section }
        #expect(others.allSatisfy { $0.deleteConfirmationTitle != title }, "Two kinds of row ask the same question")
    }

    @Test("The question and the message of a pending deletion come from its kind and its row")
    func pendingDeletionTexts() {
        let deletion = PendingDeletion(section: .certifications, index: 2, rowName: "AWS Architect", rowIdentity: "AWS Architect")

        #expect(deletion.title == EditorSection.certifications.deleteConfirmationTitle)
        #expect(deletion.message == "editor.delete_row.message".localizedWithArgs("AWS Architect"))
        #expect(deletion.message.contains("AWS Architect"))
    }

    // MARK: - The editor keeps the question while the dialog closes

    @Test("The editor holds the question of the row that was asked about, and keeps it while the dialog closes")
    func editorKeepsTheQuestionWhileTheDialogCloses() {
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: MockCVManagementUseCase())
        viewModel.cv.certifications.append(Certification(name: "AWS Architect"))

        viewModel.requestRemoval(of: .certifications, at: 0)
        #expect(viewModel.deletionTitle == EditorSection.certifications.deleteConfirmationTitle)

        viewModel.cancelDeletion()
        #expect(viewModel.pendingDeletion == nil)
        #expect(viewModel.deletionTitle == EditorSection.certifications.deleteConfirmationTitle,
                "The dialog is still on the screen while it closes: its title must not go blank")
    }

    @Test("The question follows the kind of the row that is asked about")
    func questionFollowsTheKind() {
        let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: MockCVManagementUseCase())
        viewModel.cv.skills.append(Skill(name: "Swift"))
        viewModel.cv.interests.append("Chess")

        viewModel.requestRemoval(of: .skills, at: 0)
        #expect(viewModel.deletionTitle == EditorSection.skills.deleteConfirmationTitle)
        viewModel.cancelDeletion()

        viewModel.requestRemoval(of: .interests, at: 0)
        #expect(viewModel.deletionTitle == EditorSection.interests.deleteConfirmationTitle)
    }
}
