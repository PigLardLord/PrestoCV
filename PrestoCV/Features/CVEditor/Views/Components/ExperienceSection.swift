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
        Section {
            if viewModel.cv.relevant_experience.isEmpty {
                CVEmptyStateView(
                    icon: "briefcase",
                    title: "No Experience Added",
                    subtitle: "Add your work experience to showcase your professional background"
                )
            } else {
                ForEach(viewModel.cv.relevant_experience.indices, id: \.self) { index in
                    ExperienceRowView(
                        experience: $viewModel.cv.relevant_experience[index],
                        onDelete: { animatedRemoveExperience(at: index) }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete { indices in
                    viewModel.cv.relevant_experience.remove(atOffsets: indices)
                }
            }
            
            AddButton(title: "Add Experience", icon: "plus.circle.fill", action: animatedAddExperience)
        } header: {
            SectionHeader(title: "Work Experience")
        }
    }
    
    private func animatedAddExperience() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addExperience()
        }
    }
    
    private func animatedRemoveExperience(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeExperience(at: index)
        }
    }
}

struct SkillsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.skills.isEmpty {
                CVEmptyStateView(
                    icon: "star.circle",
                    title: "No Skills Added",
                    subtitle: "Add your technical and professional skills"
                )
            } else {
                ForEach(viewModel.cv.skills.indices, id: \.self) { index in
                    SkillRowView(
                        skill: $viewModel.cv.skills[index],
                        onDelete: { animatedRemoveSkill(at: index) }
                    )
                }
                .onDelete { indices in
                    viewModel.cv.skills.remove(atOffsets: indices)
                }
            }
            
            AddButton(title: "Add Skill", icon: "plus.circle.fill", action: animatedAddSkill)
        } header: {
            SectionHeader(title: "Skills")
        }
    }
    
    private func animatedAddSkill() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addSkill()
        }
    }
    
    private func animatedRemoveSkill(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeSkill(at: index)
        }
    }
}

struct EducationSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.education.isEmpty {
                CVEmptyStateView(
                    icon: "graduationcap.circle",
                    title: "No Education Added",
                    subtitle: "Add your educational background and qualifications"
                )
            } else {
                ForEach(viewModel.cv.education.indices, id: \.self) { index in
                    EducationRowView(
                        education: $viewModel.cv.education[index],
                        onDelete: { animatedRemoveEducation(at: index) }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete { indices in
                    viewModel.cv.education.remove(atOffsets: indices)
                }
            }
            
            AddButton(title: "Add Education", icon: "plus.circle.fill", action: animatedAddEducation)
        } header: {
            SectionHeader(title: "Education")
        }
    }
    
    private func animatedAddEducation() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addEducation()
        }
    }
    
    private func animatedRemoveEducation(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeEducation(at: index)
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return ExperienceSection(viewModel: viewModel)
}