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
            title: "section.languages".localized,
            icon: "globe",
            emptyStateTitle: "empty.no_languages".localized,
            emptyStateSubtitle: "empty.languages_subtitle".localized,
            addButtonTitle: "action.add_language".localized,
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
            title: "section.certifications".localized,
            icon: "rosette",
            emptyStateTitle: "empty.no_certifications".localized,
            emptyStateSubtitle: "empty.certifications_subtitle".localized,
            addButtonTitle: "action.add_certification".localized,
            items: $viewModel.cv.certifications,
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
            title: "section.social_links".localized,
            icon: "link.circle",
            emptyStateTitle: "empty.no_social_links".localized,
            emptyStateSubtitle: "empty.social_links_subtitle".localized,
            addButtonTitle: "action.add_social_link".localized,
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
        CVEditableSection(
            title: "section.interests".localized,
            icon: "heart.circle",
            emptyStateTitle: "empty.no_interests".localized,
            emptyStateSubtitle: "empty.interests_subtitle".localized,
            addButtonTitle: "action.add_interest".localized,
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