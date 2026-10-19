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
            title: "section.work_experience".localized,
            icon: "briefcase",
            emptyStateTitle: "empty.no_experience".localized,
            emptyStateSubtitle: "empty.experience_subtitle".localized,
            addButtonTitle: "action.add_experience".localized,
            items: $viewModel.cv.relevant_experience,
            rowContent: { experience, onDelete in
                ExperienceRowView(
                    experience: experience,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addExperience,
            onRemove: { viewModel.requestRemoval(of: .experience, at: $0) }
        )
    }
}

struct SkillsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: "section.skills".localized,
            icon: "star.circle",
            emptyStateTitle: "empty.no_skills".localized,
            emptyStateSubtitle: "empty.skills_subtitle".localized,
            addButtonTitle: "action.add_skill".localized,
            items: $viewModel.cv.skills,
            rowContent: { skill, onDelete in
                SkillRowView(
                    skill: skill,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addSkill,
            onRemove: { viewModel.requestRemoval(of: .skills, at: $0) }
        )
    }
}

struct EducationSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: "section.education".localized,
            icon: "graduationcap.circle",
            emptyStateTitle: "empty.no_education".localized,
            emptyStateSubtitle: "empty.education_subtitle".localized,
            addButtonTitle: "action.add_education".localized,
            items: $viewModel.cv.education,
            rowContent: { education, onDelete in
                EducationRowView(
                    education: education,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addEducation,
            onRemove: { viewModel.requestRemoval(of: .education, at: $0) }
        )
    }
}

#if DEBUG
#Preview {
    ExperienceSection(viewModel: PreviewDependencies.editor())
}
#endif