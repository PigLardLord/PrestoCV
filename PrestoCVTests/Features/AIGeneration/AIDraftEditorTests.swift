import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

/// A draft the AI wrote opens in the editor as a new CV that was never stored: whatever it holds, the editor stores it
/// as it is, with nothing for the person to save.
@MainActor
@Suite("AI draft in the editor Tests")
struct AIDraftEditorTests {
    private let labels = AIDraftLabels(present: "Oggi")

    private func editor(opening draft: CVData, useCase: MockCVManagementUseCase = MockCVManagementUseCase()) -> CVEditorViewModel {
        let cv = AIDraftMapper(labels: labels, languageOfText: { _ in nil }).map(draft, writtenIn: "A description.")
        return CVEditorViewModel(cvId: nil, initialCV: cv, notice: .aiDraft, cvManagementUseCase: useCase)
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

    @Test("Whatever the draft holds, leaving the editor stores it as a new CV, once", arguments: drafts)
    func leavingStoresTheDraft(label: String, draft: CVData) async {
        let useCase = MockCVManagementUseCase()
        let viewModel = editor(opening: draft, useCase: useCase)

        #expect(viewModel.hasMeaningfulContent, "\(label)")
        await viewModel.saveNow()
        await viewModel.saveNow()

        #expect(await useCase.createdCVs == [viewModel.cv], "\(label)")
        #expect(viewModel.showsSavedOnDevice, "\(label)")
    }
}
