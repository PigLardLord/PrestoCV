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
            title: String(localized: "Languages"),
            icon: "globe",
            emptyStateTitle: String(localized: "No Languages Added"),
            emptyStateSubtitle: String(localized: "Add languages you speak and your proficiency level"),
            addButtonTitle: String(localized: "Add Language"),
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
            title: String(localized: "Certifications"),
            icon: "rosette",
            emptyStateTitle: String(localized: "No Certifications Added"),
            emptyStateSubtitle: String(localized: "Add professional certifications and achievements"),
            addButtonTitle: String(localized: "Add Certification"),
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
            title: String(localized: "Social Links"),
            icon: "link.circle",
            emptyStateTitle: String(localized: "No Social Links Added"),
            emptyStateSubtitle: String(localized: "Add professional social media profiles and websites"),
            addButtonTitle: String(localized: "Add Social Link"),
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
            title: String(localized: "Interests"),
            icon: "heart.circle",
            emptyStateTitle: String(localized: "No Interests Added"),
            emptyStateSubtitle: String(localized: "Add personal interests and hobbies"),
            addButtonTitle: String(localized: "Add Interest"),
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