import SwiftUI
import PrestoCVCore

struct PersonalInfoSection: View {
    @Binding var cv: CVModel
    @Binding var documentLanguage: DocumentLanguage?
    /// The automatic choice with the language it stands for: "Automatic (English)"
    let automaticLanguageTitle: String
    /// The language chosen, or what automatic stands for
    let documentLanguageTitle: String
    let nameStatus: FieldStatus
    let emailStatus: FieldStatus
    let phoneStatus: FieldStatus
    let portfolioStatus: FieldStatus
    /// Tells the editor that the person left a contact field, which checks it
    let onLeave: (ContactField) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    /// E-mail and phone side by side where the screen is wide, one above the other where it is not, so that
    /// neither is cut off.
    private var contactFields: some View {
        let layout = horizontalSizeClass == .regular
            ? AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
        return layout {
            LabeledTextField.email(
                text: $cv.personalInfo.email,
                state: emailStatus.fieldState,
                onLeave: { onLeave(.email) }
            )
            
            LabeledTextField.phone(
                text: $cv.personalInfo.phone,
                state: phoneStatus.fieldState,
                onLeave: { onLeave(.phone) }
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
                    .accessibilityLabel("field.cv_name".localized)

                documentLanguageRow
            } header: {
                SectionHeader(title: "section.cv_details".localized)
            }
            .listRowBackground(DesignTokens.Colors.backgroundSecondary)
            
            // Personal Information - High Priority
            Section {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    LabeledTextField(label: "field.full_name".localized, text: $cv.personalInfo.name, state: nameStatus.fieldState)
                    
                    LabeledTextField(label: "field.professional_title".localized, text: $cv.personalInfo.title)
                    
                    LabeledTextField(label: "field.location".localized, text: $cv.personalInfo.location)
                    
                    contactFields
                    
                    LabeledTextField.url(
                        label: "field.portfolio_url".localized,
                        text: $cv.personalInfo.portfolio,
                        state: portfolioStatus.fieldState,
                        onLeave: { onLeave(.portfolio) }
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

// MARK: - Document Language

private extension PersonalInfoSection {
    /// The label, and the language in a menu: beside it, or under it at the accessibility sizes. The system's menu
    /// picker cuts a value longer than its line in the middle ("Auto…nglish)"); this one makes it smaller instead.
    var documentLanguageRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
        return layout {
            WholeWordsText("field.document_language".localized)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The label is for the eye only: the menu says it, with the language, so that VoiceOver reads the
                // row once, in one stop, as it read the system's picker. The text has no accessibility element at
                // all: hidden, it would still be in the tree that UI tests search.
                .accessibilityRepresentation { EmptyView() }

            Menu {
                Picker(selection: $documentLanguage) {
                    Text(automaticLanguageTitle).tag(DocumentLanguage?.none)
                    ForEach(DocumentLanguage.allCases) { language in
                        Text(language.nativeName).tag(Optional(language))
                    }
                } label: {
                    Text("field.document_language".localized)
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(documentLanguageTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                .foregroundColor(DesignTokens.Colors.secondary)
            }
            // The language takes its room first, as the system's picker does; the label wraps into what is left
            .layoutPriority(1)
            .accessibilityLabel("field.document_language".localized)
            .accessibilityValue(documentLanguageTitle)
            // The form makes the menu the element of the whole row, and the middle of the row can be the label or
            // the space before the menu: activating the row lands on the menu instead
            .accessibilityActivationPoint(.center)
        }
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
        WholeWordsText(title)
            .font(DesignTokens.Typography.title3.font)
            .fontWeight(DesignTokens.Typography.title3.fontWeight)
            .foregroundColor(DesignTokens.Typography.title3.color)
            .textCase(nil)
    }
}

#Preview {
    PersonalInfoSection(
        cv: .constant(CVModel()),
        documentLanguage: .constant(nil),
        automaticLanguageTitle: "Automatic (English)",
        documentLanguageTitle: "Automatic (English)",
        nameStatus: FieldStatus(validity: .none, isRequired: true, note: .required),
        emailStatus: FieldStatus(validity: .none, isRequired: false, note: nil),
        phoneStatus: FieldStatus(validity: .none, isRequired: false, note: .phoneHelp),
        portfolioStatus: FieldStatus(validity: .none, isRequired: false, note: .webAddressHelp),
        onLeave: { _ in }
    )
}