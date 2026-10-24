import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Section Fixtures

private extension EditorSection {
    /// Adds a row to the section in the editor. `text` fills the field that names the row; nil leaves the row blank.
    @MainActor
    func addRow(to viewModel: CVEditorViewModel, text: String?) {
        let text = text ?? ""
        switch self {
        case .skills: viewModel.cv.skills.append(Skill(name: text))
        case .experience: viewModel.cv.relevant_experience.append(Experience(title: text))
        case .education: viewModel.cv.education.append(Education(degree: text))
        case .languages: viewModel.cv.languages.append(Language(name: text))
        case .certifications: viewModel.cv.certifications.append(Certification(name: text))
        case .social: viewModel.cv.social.append(Social(platform: text))
        case .interests: viewModel.cv.interests.append(text)
        }
    }

    /// Puts another row, with a new identity, in the place of the first row of the section. `text` fills the field that
    /// names it.
    @MainActor
    func replaceFirstRow(in viewModel: CVEditorViewModel, text: String) {
        switch self {
        case .skills: viewModel.cv.skills[0] = Skill(name: text)
        case .experience: viewModel.cv.relevant_experience[0] = Experience(title: text)
        case .education: viewModel.cv.education[0] = Education(degree: text)
        case .languages: viewModel.cv.languages[0] = Language(name: text)
        case .certifications: viewModel.cv.certifications[0] = Certification(name: text)
        case .social: viewModel.cv.social[0] = Social(platform: text)
        case .interests: viewModel.cv.interests[0] = text
        }
    }

    /// Types into the field that names the first row of the section, as the person does while the row stays the same row.
    @MainActor
    func renameFirstRow(in viewModel: CVEditorViewModel, to text: String) {
        switch self {
        case .skills: viewModel.cv.skills[0].name = text
        case .experience: viewModel.cv.relevant_experience[0].title = text
        case .education: viewModel.cv.education[0].degree = text
        case .languages: viewModel.cv.languages[0].name = text
        case .certifications: viewModel.cv.certifications[0].name = text
        case .social: viewModel.cv.social[0].platform = text
        case .interests: viewModel.cv.interests[0] = text
        }
    }

    func rowCount(in cv: CVModel) -> Int {
        switch self {
        case .skills: return cv.skills.count
        case .experience: return cv.relevant_experience.count
        case .education: return cv.education.count
        case .languages: return cv.languages.count
        case .certifications: return cv.certifications.count
        case .social: return cv.social.count
        case .interests: return cv.interests.count
        }
    }
}

// MARK: - Row Deletion Tests

@MainActor
@Suite("CVEditorViewModel Tests - deleting rows")
struct CVEditorRowDeletionTests {

    private func makeViewModel() -> CVEditorViewModel {
        CVEditorViewModel(cvId: nil, cvManagementUseCase: MockCVManagementUseCase())
    }

    // MARK: - Confirmation

    @Test("A blank row is removed at once, without asking", arguments: EditorSection.allCases)
    func blankRowIsRemovedAtOnce(section: EditorSection) {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: nil)

        viewModel.requestRemoval(of: section, at: 0)

        #expect(section.rowCount(in: viewModel.cv) == 0)
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("A row with content waits for the confirmation and keeps its place", arguments: EditorSection.allCases)
    func rowWithContentWaitsForConfirmation(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")

        viewModel.requestRemoval(of: section, at: 0)

        #expect(section.rowCount(in: viewModel.cv) == 1, "Nothing may be deleted before the user agrees")
        let deletion = try #require(viewModel.pendingDeletion)
        #expect(deletion.section == section)
        #expect(deletion.index == 0)
        #expect(deletion.rowName == "Swift")
    }

    @Test("Confirming removes the row and clears the request", arguments: EditorSection.allCases)
    func confirmingRemovesTheRow(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        viewModel.requestRemoval(of: section, at: 0)
        let deletion = try #require(viewModel.pendingDeletion)

        viewModel.confirmDeletion(deletion)

        #expect(section.rowCount(in: viewModel.cv) == 0, "The last row of the section must be removable")
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("Cancelling keeps the row and clears the request", arguments: EditorSection.allCases)
    func cancellingKeepsTheRow(section: EditorSection) {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        viewModel.requestRemoval(of: section, at: 0)

        viewModel.cancelDeletion()

        #expect(section.rowCount(in: viewModel.cv) == 1)
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("Only the confirmed row of several is removed")
    func onlyTheConfirmedRowIsRemoved() throws {
        let viewModel = makeViewModel()
        viewModel.cv.skills = [Skill(name: "Swift"), Skill(name: "Kotlin"), Skill(name: "Rust")]

        viewModel.requestRemoval(of: .skills, at: 1)
        viewModel.confirmDeletion(try #require(viewModel.pendingDeletion))

        #expect(viewModel.cv.skills.map(\.name) == ["Swift", "Rust"])
    }

    @Test("Removing a confirmed row of a stored CV is stored like any other change")
    func confirmedRemovalIsStored() async throws {
        let mockUseCase = MockCVManagementUseCase()
        let storedCV = CVModel(
            id: UUID(),
            name: "Stored CV",
            personalInfo: PersonalInfo(name: "Jane Doe"),
            skills: [Skill(name: "Swift")]
        )
        await mockUseCase.storeCV(storedCV)
        let viewModel = CVEditorViewModel(cvId: storedCV.id.uuidString, cvManagementUseCase: mockUseCase)
        await viewModel.loadCV()

        viewModel.requestRemoval(of: .skills, at: 0)
        viewModel.confirmDeletion(try #require(viewModel.pendingDeletion))
        await viewModel.saveNow()

        #expect(await mockUseCase.updatedCVs.map(\.skills.count) == [0])
    }

    // MARK: - Guards

    @Test("A request for a row that does not exist does nothing", arguments: EditorSection.allCases)
    func requestForMissingRowDoesNothing(section: EditorSection) {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")

        viewModel.requestRemoval(of: section, at: -1)
        viewModel.requestRemoval(of: section, at: 1)

        #expect(section.rowCount(in: viewModel.cv) == 1)
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("An answer that comes twice removes one row, not the row that slid into its place", arguments: EditorSection.allCases)
    func anAnswerThatComesTwiceRemovesOneRow(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        section.addRow(to: viewModel, text: "Kotlin")
        viewModel.requestRemoval(of: section, at: 0)
        let deletion = try #require(viewModel.pendingDeletion)

        viewModel.confirmDeletion(deletion)
        viewModel.confirmDeletion(deletion)

        #expect(section.rowCount(in: viewModel.cv) == 1, "The second answer is about a row that is gone: Kotlin was not asked about")
    }

    @Test("An answer is not carried out on another row that has taken the place of the one asked about",
          arguments: EditorSection.allCases)
    func anAnswerIsNotCarriedOutOnAnotherRow(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        viewModel.requestRemoval(of: section, at: 0)
        let deletion = try #require(viewModel.pendingDeletion)
        // An interest is its text, so another interest has another text; every other row is told apart by more than its name
        section.replaceFirstRow(in: viewModel, text: section == .interests ? "Kotlin" : "Swift")

        viewModel.confirmDeletion(deletion)

        #expect(section.rowCount(in: viewModel.cv) == 1, "Another row is not the row that was asked about")
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("An answer that comes after the question was cancelled removes nothing", arguments: EditorSection.allCases)
    func anAnswerAfterCancellingRemovesNothing(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        viewModel.requestRemoval(of: section, at: 0)
        let deletion = try #require(viewModel.pendingDeletion)
        viewModel.cancelDeletion()

        viewModel.confirmDeletion(deletion)

        #expect(section.rowCount(in: viewModel.cv) == 1, "The person said no, and a late yes of the same question is not theirs")
    }

    @Test("An answer to a question that another question has replaced removes nothing", arguments: EditorSection.allCases)
    func anAnswerToAReplacedQuestionRemovesNothing(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        section.addRow(to: viewModel, text: "Kotlin")
        viewModel.requestRemoval(of: section, at: 0)
        let first = try #require(viewModel.pendingDeletion)
        viewModel.requestRemoval(of: section, at: 1)

        viewModel.confirmDeletion(first)

        #expect(section.rowCount(in: viewModel.cv) == 2)
        #expect(viewModel.pendingDeletion?.rowName == "Kotlin", "The question that is asked now is still asked")
    }

    /// A guard: the row asked about is the same row after its text changed, so the answer still removes it. An interest
    /// is a plain string, which is its own identity, so it is left out.
    @Test("An answer still removes the row asked about when its text has changed",
          arguments: EditorSection.allCases.filter { $0 != .interests })
    func anAnswerRemovesTheSameRowAfterItWasEdited(section: EditorSection) throws {
        let viewModel = makeViewModel()
        section.addRow(to: viewModel, text: "Swift")
        viewModel.requestRemoval(of: section, at: 0)
        let deletion = try #require(viewModel.pendingDeletion)
        section.renameFirstRow(in: viewModel, to: "Swift Pro")

        viewModel.confirmDeletion(deletion)

        #expect(section.rowCount(in: viewModel.cv) == 0)
    }

    @Test("Confirming a row that is already gone does nothing", arguments: EditorSection.allCases)
    func confirmingAMissingRowDoesNothing(section: EditorSection) {
        let viewModel = makeViewModel()

        viewModel.confirmDeletion(PendingDeletion(section: section, index: 0, rowName: "Swift", rowIdentity: "Swift"))

        #expect(section.rowCount(in: viewModel.cv) == 0)
        #expect(viewModel.pendingDeletion == nil)
    }

    // MARK: - What counts as blank

    @Test("A row holding only spaces is blank")
    func rowWithOnlySpacesIsBlank() {
        let viewModel = makeViewModel()
        viewModel.cv.relevant_experience = [Experience(title: "   ")]

        viewModel.requestRemoval(of: .experience, at: 0)

        #expect(viewModel.cv.relevant_experience.isEmpty)
        #expect(viewModel.pendingDeletion == nil)
    }

    @Test("A skill with a level but no name is not blank")
    func skillWithOnlyALevelIsNotBlank() {
        let viewModel = makeViewModel()
        viewModel.cv.skills = [Skill(name: "", level: 3)]

        viewModel.requestRemoval(of: .skills, at: 0)

        #expect(viewModel.cv.skills.count == 1)
        #expect(viewModel.pendingDeletion != nil)
    }

    @Test("An experience with only a description is not blank and is named after its field")
    func experienceWithOnlyADescriptionIsNotBlank() {
        let viewModel = makeViewModel()
        viewModel.cv.relevant_experience = [Experience(description: "Led the migration")]

        viewModel.requestRemoval(of: .experience, at: 0)

        #expect(viewModel.pendingDeletion?.rowName == "field.job_title".localized)
    }

    @Test("A row is named after the first field that holds something")
    func rowIsNamedAfterTheFirstFilledField() {
        #expect(Experience(title: "Engineer", company: "Acme").displayName == "Engineer")
        #expect(Experience(title: " ", company: "Acme").displayName == "Acme")
        #expect(Education(school: "MIT").displayName == "MIT")
        #expect(Certification(issuer: "AWS").displayName == "AWS")
        #expect(Social(url: "https://example.com").displayName == "https://example.com")
        #expect(InterestEntry(text: "Chess").displayName == "Chess")
        #expect(Skill().displayName == "field.skill".localized)
        #expect(InterestEntry(text: "").displayName == "field.interest".localized)
    }
}
