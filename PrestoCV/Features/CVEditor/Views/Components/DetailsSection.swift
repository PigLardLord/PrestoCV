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
                        onDelete: { animatedRemoveLanguage(at: index) }
                    )
                }
                .onDelete(perform: animatedDeleteLanguages)
            }
            
            AddButton(title: "Add Language", icon: "plus.circle.fill", action: animatedAddLanguage)
        } header: {
            SectionHeader(title: "Languages")
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animatedAddLanguage() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addLanguage()
        }
    }
    
    private func animatedRemoveLanguage(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeLanguage(at: index)
        }
    }
    
    private func animatedDeleteLanguages(at indices: IndexSet) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.cv.languages.remove(atOffsets: indices)
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
                        onDelete: { animatedRemoveCertification(at: index) }
                    )
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onDelete(perform: animatedDeleteCertifications)
            }
            
            AddButton(title: "Add Certification", icon: "plus.circle.fill", action: animatedAddCertification)
        } header: {
            SectionHeader(title: "Certifications")
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animatedAddCertification() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addCertification()
        }
    }
    
    private func animatedRemoveCertification(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeCertification(at: index)
        }
    }
    
    private func animatedDeleteCertifications(at indices: IndexSet) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.cv.certifications.remove(atOffsets: indices)
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
                        onDelete: { animatedRemoveSocial(at: index) }
                    )
                }
                .onDelete(perform: animatedDeleteSocial)
            }
            
            AddButton(title: "Add Social Link", icon: "plus.circle.fill", action: animatedAddSocial)
        } header: {
            SectionHeader(title: "Social Links")
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animatedAddSocial() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addSocial()
        }
    }
    
    private func animatedRemoveSocial(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeSocial(at: index)
        }
    }
    
    private func animatedDeleteSocial(at indices: IndexSet) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.cv.social.remove(atOffsets: indices)
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
                        onDelete: { animatedRemoveInterest(at: index) }
                    )
                }
                .onDelete(perform: animatedDeleteInterests)
            }
            
            AddButton(title: "Add Interest", icon: "plus.circle.fill", action: animatedAddInterest)
        } header: {
            SectionHeader(title: "Interests")
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animatedAddInterest() {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.addInterest()
        }
    }
    
    private func animatedRemoveInterest(at index: Int) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.removeInterest(at: index)
        }
    }
    
    private func animatedDeleteInterests(at indices: IndexSet) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            viewModel.cv.interests.remove(atOffsets: indices)
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return DetailsSection(viewModel: viewModel)
}