import SwiftUI
import PrestoCVCore

struct PersonalInfoSection: View {
    @Binding var cv: CVModel
    
    var body: some View {
        Form {
            // CV Name Section - Most Important
            Section {
                TextField("CV Name", text: $cv.name)
                    .font(DesignTokens.Typography.headline.font)
                    .fontWeight(DesignTokens.Typography.headline.fontWeight)
            } header: {
                SectionHeader(title: "CV Details")
            }
            .listRowBackground(DesignTokens.Colors.backgroundSecondary)
            
            // Personal Information - High Priority
            Section {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    LabeledTextField(label: "Full Name", text: $cv.personalInfo.name)
                    
                    LabeledTextField(label: "Professional Title", text: $cv.personalInfo.title)
                    
                    LabeledTextField(label: "Location", text: $cv.personalInfo.location)
                    
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
                        label: "Portfolio URL",
                        text: $cv.personalInfo.portfolio
                    )
                }
            } header: {
                SectionHeader(title: "Personal Information")
            }
            
            // Professional Summary - High Priority
            Section {
                ProfessionalSummaryView(profile: $cv.personalInfo.profile)
            } header: {
                SectionHeader(title: "Summary")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ProfessionalSummaryView: View {
    @Binding var profile: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Professional Summary")
                .font(DesignTokens.Typography.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("Describe your professional background, key skills, and career objectives")
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