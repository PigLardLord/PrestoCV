import SwiftUI
import PrestoCVCore

struct DetailsSection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Form {
            // Languages Section
            LanguagesSubsection(viewModel: viewModel)
            
            // Certifications Section
            CertificationsSubsection(viewModel: viewModel)
            
            // Social Links Section
            SocialLinksSubsection(viewModel: viewModel)
            
            // Interests Section
            InterestsSubsection(viewModel: viewModel)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct LanguagesSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.languages.isEmpty {
                CVEmptyStateView(
                    icon: "globe",
                    title: "No Languages Added",
                    subtitle: "Add languages you speak and your proficiency level"
                )
            } else {
                ForEach(viewModel.cv.languages.indices, id: \.self) { index in
                    LanguageRowView(
                        language: $viewModel.cv.languages[index],
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.removeLanguage(at: index)
                            }
                        }
                    )
                }
                .onDelete { indices in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.cv.languages.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Language", icon: "plus.circle.fill") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.addLanguage()
                }
            }
        } header: {
            SectionHeader(title: "Languages")
        }
    }
}

struct CertificationsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.certifications.isEmpty {
                CVEmptyStateView(
                    icon: "rosette",
                    title: "No Certifications Added",
                    subtitle: "Add professional certifications and achievements"
                )
            } else {
                ForEach(viewModel.cv.certifications.indices, id: \.self) { index in
                    CertificationRowView(
                        certification: $viewModel.cv.certifications[index],
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.removeCertification(at: index)
                            }
                        }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete { indices in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.cv.certifications.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Certification", icon: "plus.circle.fill") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.addCertification()
                }
            }
        } header: {
            SectionHeader(title: "Certifications")
        }
    }
}

struct SocialLinksSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.social.isEmpty {
                CVEmptyStateView(
                    icon: "link.circle",
                    title: "No Social Links Added",
                    subtitle: "Add professional social media profiles and websites"
                )
            } else {
                ForEach(viewModel.cv.social.indices, id: \.self) { index in
                    SocialLinkRowView(
                        social: $viewModel.cv.social[index],
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.removeSocial(at: index)
                            }
                        }
                    )
                }
                .onDelete { indices in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.cv.social.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Social Link", icon: "plus.circle.fill") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.addSocial()
                }
            }
        } header: {
            SectionHeader(title: "Social Links")
        }
    }
}

struct InterestsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        Section {
            if viewModel.cv.interests.isEmpty {
                CVEmptyStateView(
                    icon: "heart.circle",
                    title: "No Interests Added",
                    subtitle: "Add personal interests and hobbies"
                )
            } else {
                ForEach(viewModel.cv.interests.indices, id: \.self) { index in
                    InterestRowView(
                        interest: $viewModel.cv.interests[index],
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.removeInterest(at: index)
                            }
                        }
                    )
                }
                .onDelete { indices in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.cv.interests.remove(atOffsets: indices)
                    }
                }
            }
            
            AddButton(title: "Add Interest", icon: "plus.circle.fill") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.addInterest()
                }
            }
        } header: {
            SectionHeader(title: "Interests")
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return DetailsSection(viewModel: viewModel)
}