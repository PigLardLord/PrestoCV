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
        CVEditableSection(
            title: "Languages",
            icon: "globe",
            emptyStateTitle: "No Languages Added",
            emptyStateSubtitle: "Add languages you speak and your proficiency level",
            addButtonTitle: "Add Language",
            items: $viewModel.cv.languages,
            rowContent: { language, onDelete in
                LanguageRowView(
                    language: language,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addLanguage,
            onRemove: { viewModel.removeLanguage(at: $0) }
        )
    }
}

struct CertificationsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: "Certifications",
            icon: "rosette",
            emptyStateTitle: "No Certifications Added",
            emptyStateSubtitle: "Add professional certifications and achievements",
            addButtonTitle: "Add Certification",
            items: $viewModel.cv.certifications,
            addVerticalPadding: true,
            rowContent: { certification, onDelete in
                CertificationRowView(
                    certification: certification,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addCertification,
            onRemove: { viewModel.removeCertification(at: $0) }
        )
    }
}

struct SocialLinksSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableSection(
            title: "Social Links",
            icon: "link.circle",
            emptyStateTitle: "No Social Links Added",
            emptyStateSubtitle: "Add professional social media profiles and websites",
            addButtonTitle: "Add Social Link",
            items: $viewModel.cv.social,
            rowContent: { social, onDelete in
                SocialLinkRowView(
                    social: social,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addSocial,
            onRemove: { viewModel.removeSocial(at: $0) }
        )
    }
}

struct InterestsSubsection: View {
    @ObservedObject var viewModel: CVEditorViewModel
    
    var body: some View {
        CVEditableStringSection(
            title: "Interests",
            icon: "heart.circle",
            emptyStateTitle: "No Interests Added",
            emptyStateSubtitle: "Add personal interests and hobbies",
            addButtonTitle: "Add Interest",
            items: $viewModel.cv.interests,
            rowContent: { interest, onDelete in
                InterestRowView(
                    interest: interest,
                    onDelete: onDelete
                )
            },
            onAdd: viewModel.addInterest,
            onRemove: { viewModel.removeInterest(at: $0) }
        )
    }
}

#Preview {
    let container = DependencyContainer()
    let cvManagementUseCase = try! container.makeCVManagementUseCase()
    let viewModel = CVEditorViewModel(cvId: nil, cvManagementUseCase: cvManagementUseCase)
    
    return DetailsSection(viewModel: viewModel)
}