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
            title: String(localized: "section.work_experience"),
            icon: "briefcase",
            emptyStateTitle: String(localized: "empty.no_experience"),
            emptyStateSubtitle: String(localized: "empty.experience_subtitle"),
            addButtonTitle: String(localized: "action.add_experience"),
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
            title: String(localized: "section.skills"),
            icon: "star.circle",
            emptyStateTitle: String(localized: "empty.no_skills"),
            emptyStateSubtitle: String(localized: "empty.skills_subtitle"),
            addButtonTitle: String(localized: "action.add_skill"),
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
            title: String(localized: "section.education"),
            icon: "graduationcap.circle",
            emptyStateTitle: String(localized: "empty.no_education"),
            emptyStateSubtitle: String(localized: "empty.education_subtitle"),
            addButtonTitle: String(localized: "action.add_education"),
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