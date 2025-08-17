import SwiftUI
import PrestoCVCore

struct ExperienceSection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Form {
            // Work Experience - Most Important
            WorkExperienceSubsection(viewModel: viewModel)
            
            // Skills Section
            SkillsSubsection(viewModel: viewModel)
            
            // Education Section
            EducationSubsection(viewModel: viewModel)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct WorkExperienceSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: String(localized: "Work Experience"),
            icon: "briefcase",
            emptyStateTitle: String(localized: "No Experience Added"),
            emptyStateSubtitle: String(localized: "Add your work experience to showcase your professional background"),
            addButtonTitle: String(localized: "Add Experience"),
            items: $viewModel.cv.relevant_experience,
            rowContent: { experience, onDelete in
                ExperienceRowView(
                    experience: experience,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addExperience,
            onRemove: { viewModel.removeExperience(at: $0) }
        )
    }
}

struct SkillsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: String(localized: "Skills"),
            icon: "star.circle",
            emptyStateTitle: String(localized: "No Skills Added"),
            emptyStateSubtitle: String(localized: "Add your technical and professional skills"),
            addButtonTitle: String(localized: "Add Skill"),
            items: $viewModel.cv.skills,
            rowContent: { skill, onDelete in
                SkillRowView(
                    skill: skill,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addSkill,
            onRemove: { viewModel.removeSkill(at: $0) }
        )
    }
}

struct EducationSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: String(localized: "Education"),
            icon: "graduationcap.circle",
            emptyStateTitle: String(localized: "No Education Added"),
            emptyStateSubtitle: String(localized: "Add your educational background and qualifications"),
            addButtonTitle: String(localized: "Add Education"),
            items: $viewModel.cv.education,
            rowContent: { education, onDelete in
                EducationRowView(
                    education: education,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addEducation,
            onRemove: { viewModel.removeEducation(at: $0) }
        )
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return ExperienceSection(viewModel: viewModel)
}