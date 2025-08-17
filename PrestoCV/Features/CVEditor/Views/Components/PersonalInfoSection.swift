import SwiftUI
import PrestoCVCore

struct PersonalInfoSection: View {
    @Binding var cv: CVModel
    
    var body: some View {
        Form {
            // CV Name Section - Most Important
            Section {
                TextField(LocalizedStringKey("personal_info_cv_name"), text: $cv.name)
                    .font(DesignTokens.Typography.headline.font)
                    .fontWeight(DesignTokens.Typography.headline.fontWeight)
            } header: {
                SectionHeader(title: LocalizedString("personal_info_cv_details"))
            }
            .listRowBackground(DesignTokens.Colors.backgroundSecondary)
            
            // Personal Information - High Priority
            Section {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    LabeledTextField(label: LocalizedString("personal_info_full_name"), text: $cv.personalInfo.name)
                    
                    LabeledTextField(label: LocalizedString("personal_info_professional_title"), text: $cv.personalInfo.title)
                    
                    LabeledTextField(label: LocalizedString("personal_info_location"), text: $cv.personalInfo.location)
                    
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        LabeledTextField.email(
                            text: $cv.personalInfo.email,
                            isRequired: true
                        )
                        
                        LabeledTextField.phone(
                            text: $cv.personalInfo.phone
                        )
                    }
                    
                    LabeledTextField.url(
                        label: LocalizedString("personal_info_portfolio_url"),
                        text: $cv.personalInfo.portfolio
                    )
                }
            } header: {
                SectionHeader(title: LocalizedString("personal_info_section_title"))
            }
            
            // Professional Summary - High Priority
            Section {
                ProfessionalSummaryView(profile: $cv.personalInfo.profile)
            } header: {
                SectionHeader(title: LocalizedString("personal_info_summary_section_title"))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ProfessionalSummaryView: View {
    @Binding var profile: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(LocalizedStringKey("personal_info_professional_summary_title"))
                .font(DesignTokens.Typography.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text(LocalizedStringKey("personal_info_professional_summary_placeholder"))
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
    PersonalInfoSection(cv: .constant(CVModel()))
}