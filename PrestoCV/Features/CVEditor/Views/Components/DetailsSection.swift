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
            title: String(localized: "section.languages"),
            icon: "globe",
            emptyStateTitle: String(localized: "empty.no_languages"),
            emptyStateSubtitle: String(localized: "empty.languages_subtitle"),
            addButtonTitle: String(localized: "action.add_language"),
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
            title: String(localized: "section.certifications"),
            icon: "rosette",
            emptyStateTitle: String(localized: "empty.no_certifications"),
            emptyStateSubtitle: String(localized: "empty.certifications_subtitle"),
            addButtonTitle: String(localized: "action.add_certification"),
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
            title: String(localized: "section.social_links"),
            icon: "link.circle",
            emptyStateTitle: String(localized: "empty.no_social_links"),
            emptyStateSubtitle: String(localized: "empty.social_links_subtitle"),
            addButtonTitle: String(localized: "action.add_social_link"),
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
            title: String(localized: "section.interests"),
            icon: "heart.circle",
            emptyStateTitle: String(localized: "empty.no_interests"),
            emptyStateSubtitle: String(localized: "empty.interests_subtitle"),
            addButtonTitle: String(localized: "action.add_interest"),
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