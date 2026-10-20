import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

/// A draft the AI wrote opens in the editor as a new CV that was never stored: whatever it holds, leaving asks first,
/// and Save stores it.
@MainActor
@Suite("AI draft in the editor Tests")
struct AIDraftEditorTests {
    private let labels = AIDraftLabels(present: "Oggi")

    private func editor(opening draft: CVData, useCase: MockCVManagementUseCase = MockCVManagementUseCase()) -> CVEditorViewModel {
        let cv = AIDraftMapper(labels: labels, languageOfText: { _ in nil }).map(draft, writtenIn: "A description.")
        return CVEditorViewModel(cvId: nil, initialCV: cv, cvManagementUseCase: useCase)
    }

    private static let drafts: [(String, CVData)] = [
        ("name", CVData(personalInfo: CVGeneratorAI.PersonalInfo(name: "Maria Rossi"))),
        ("title", CVData(personalInfo: CVGeneratorAI.PersonalInfo(title: "Teacher"))),
        ("email", CVData(personalInfo: CVGeneratorAI.PersonalInfo(email: "maria@example.com"))),
        ("phone", CVData(personalInfo: CVGeneratorAI.PersonalInfo(phone: "+39 333 123 4567"))),
        ("location", CVData(personalInfo: CVGeneratorAI.PersonalInfo(location: "Bologna"))),
        ("website", CVData(personalInfo: CVGeneratorAI.PersonalInfo(website: "mariarossi.dev"))),
        ("LinkedIn", CVData(personalInfo: CVGeneratorAI.PersonalInfo(linkedin: "linkedin.com/in/maria"))),
        ("GitHub", CVData(personalInfo: CVGeneratorAI.PersonalInfo(github: "github.com/maria"))),
        ("summary", CVData(summary: "A teacher.")),
        ("experience", CVData(experience: [CVGeneratorAI.Experience(title: "Teacher", company: "Don Milani")])),
        ("education", CVData(education: [CVGeneratorAI.Education(degree: "Education Sciences")])),
        ("skills", CVData(skills: [CVGeneratorAI.Skill(name: "Chess")])),
        ("languages", CVData(languages: [CVGeneratorAI.Language(name: "Italian", proficiency: .native)])),
        ("certifications", CVData(certifications: [CVGeneratorAI.Certification(name: "BLS")])),
        ("interests", CVData(interests: ["Hiking"])),
    ]

    @Test("Whatever the draft holds, the editor counts it as unsaved and asks before leaving",
          arguments: drafts)
    func leavingAsksFirst(label: String, draft: CVData) {
        let viewModel = editor(opening: draft)

        #expect(viewModel.hasMeaningfulContent, "\(label)")
        #expect(viewModel.hasUnsavedChanges, "\(label)")
        #expect(viewModel.isSaveButtonEnabled, "\(label)")
        #expect(viewModel.requestLeaving() == false, "\(label): Leaving must ask first")
        #expect(viewModel.showingCancelConfirmation, "\(label)")
    }

    @Test("Saving the draft stores it as a new CV, after which leaving asks nothing")
    func savingStoresTheDraft() async {
        let useCase = MockCVManagementUseCase()
        let viewModel = editor(opening: CVData(personalInfo: CVGeneratorAI.PersonalInfo(phone: "+39 333 123 4567")), useCase: useCase)

        let saved = await viewModel.saveCV()

        #expect(saved)
        #expect(await useCase.createCVCallCount == 1)
        #expect(await useCase.createdCVs.first?.personalInfo.phone == "+39 333 123 4567")
        #expect(viewModel.hasUnsavedChanges == false)
        #expect(viewModel.requestLeaving() == true)
    }
}
