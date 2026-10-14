import SwiftUI
import PrestoCVCore

struct PersonalInfoSection: View {
    @Binding var cv: CVModel
    @Binding var documentLanguage: DocumentLanguage?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// E-mail and phone side by side where the screen is wide, one above the other where it is not, so that
    /// neither is cut off.
    private var contactFields: some View {
        let layout = horizontalSizeClass == .regular
            ? AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
        return layout {
            LabeledTextField.email(
                text: $cv.personalInfo.email,
                isRequired: true
            )
            
            LabeledTextField.phone(
                text: $cv.personalInfo.phone
            )
        }
    }
    
    var body: some View {
        Form {
            // CV Name Section - Most Important
            Section {
                TextField("field.cv_name", text: $cv.name)
                    .font(DesignTokens.Typography.headline.font)
                    .fontWeight(DesignTokens.Typography.headline.fontWeight)

                Picker("field.document_language", selection: $documentLanguage) {
                    Text("language.automatic").tag(DocumentLanguage?.none)
                    ForEach(DocumentLanguage.allCases) { language in
                        Text(language.nativeName).tag(Optional(language))
                    }
                }
            } header: {
                SectionHeader(title: "section.cv_details".localized)
            }
            .listRowBackground(DesignTokens.Colors.backgroundSecondary)
            
            // Personal Information - High Priority
            Section {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    LabeledTextField(label: "field.full_name".localized, text: $cv.personalInfo.name)
                    
                    LabeledTextField(label: "field.professional_title".localized, text: $cv.personalInfo.title)
                    
                    LabeledTextField(label: "field.location".localized, text: $cv.personalInfo.location)
                    
                    contactFields
                    
                    LabeledTextField.url(
                        label: "field.portfolio_url".localized,
                        text: $cv.personalInfo.portfolio
                    )
                }
            } header: {
                SectionHeader(title: "section.personal_info".localized)
            }
            
            // Professional Summary - High Priority
            Section {
                ProfessionalSummaryView(profile: $cv.personalInfo.profile)
            } header: {
                SectionHeader(title: "section.summary".localized)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ProfessionalSummaryView: View {
    @Binding var profile: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("field.professional_summary")
                .font(DesignTokens.Typography.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("field.professional_summary_placeholder")
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(DesignTokens.Colors.secondary)
                .padding(.bottom, DesignTokens.Spacing.xs)
            
            TextEditor(text: $profile)
                .frame(minHeight: DesignTokens.InputSize.textEditorMinHeight + DesignTokens.Spacing.lg)
                .scrollContentBackground(.hidden)
                .background(DesignTokens.Colors.backgroundTertiary)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(DesignTokens.Colors.border, lineWidth: DesignTokens.BorderWidth.thin)
                )
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(DesignTokens.Typography.title3.font)
            .fontWeight(DesignTokens.Typography.title3.fontWeight)
            .foregroundColor(DesignTokens.Typography.title3.color)
            .textCase(nil)
    }
}

#Preview {
    PersonalInfoSection(cv: .constant(CVModel()), documentLanguage: .constant(nil))
}