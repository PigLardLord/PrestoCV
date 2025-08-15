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
                        onDelete: {
                            withAnimation(DesignTokens.Animations.standardEaseInOut) {
                                viewModel.removeExperience(at: index)
                            }
                        }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete { indices in
                    withAnimation(DesignTokens.Animations.standardEaseInOut) {
                        viewModel.cv.relevant_experience.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Experience", icon: "plus.circle.fill") {
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    viewModel.addExperience()
                }
            }
        } header: {
            SectionHeader(title: "Work Experience")
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
                        onDelete: {
                            withAnimation(DesignTokens.Animations.standardEaseInOut) {
                                viewModel.removeSkill(at: index)
                            }
                        }
                    )
                }
                .onDelete { indices in
                    withAnimation(DesignTokens.Animations.standardEaseInOut) {
                        viewModel.cv.skills.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Skill", icon: "plus.circle.fill") {
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    viewModel.addSkill()
                }
            }
        } header: {
            SectionHeader(title: "Skills")
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
                        onDelete: {
                            withAnimation(DesignTokens.Animations.standardEaseInOut) {
                                viewModel.removeEducation(at: index)
                            }
                        }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete { indices in
                    withAnimation(DesignTokens.Animations.standardEaseInOut) {
                        viewModel.cv.education.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Education", icon: "plus.circle.fill") {
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    viewModel.addEducation()
                }
            }
        } header: {
            SectionHeader(title: "Education")
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return ExperienceSection(viewModel: viewModel)
}