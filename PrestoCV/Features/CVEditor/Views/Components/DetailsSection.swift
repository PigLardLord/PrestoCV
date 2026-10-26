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
            rowContent: { language in
                LanguageRowView(language: language)
            },
            deleteLabel: { $0.deleteActionLabel },
            onAdd: viewModel.addLanguage,
            onRemove: { viewModel.requestRemoval(of: .languages, at: $0) }
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
            rowContent: { certification in
                CertificationRowView(certification: certification)
            },
            deleteLabel: { $0.deleteActionLabel },
            onAdd: viewModel.addCertification,
            onRemove: { viewModel.requestRemoval(of: .certifications, at: $0) }
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
            rowContent: { social in
                SocialLinkRowView(social: social)
            },
            deleteLabel: { $0.deleteActionLabel },
            onAdd: viewModel.addSocial,
            onRemove: { viewModel.requestRemoval(of: .social, at: $0) }
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
            rowContent: { interest in
                InterestRowView(interest: interest)
            },
            deleteLabel: { InterestEntry(text: $0).deleteActionLabel },
            onAdd: viewModel.addInterest,
            onRemove: { viewModel.requestRemoval(of: .interests, at: $0) }
        )
    }
}

#if DEBUG
#Preview {
    DetailsSection(viewModel: PreviewDependencies.editor())
}
#endif