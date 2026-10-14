import SwiftUI
import PrestoCVCore

// MARK: - Shared Row Components

struct ExperienceRowView: View {
    @Binding var experience: Experience
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Title and Delete button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    TextField("field.job_title".localized, text: $experience.title)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    TextField("field.company".localized, text: $experience.company)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
                
                Spacer()
                
                DeleteButton(label: experience.displayName, action: onDelete)
            }
            
            // Location and Period
            HStack {
                TextField("field.location".localized, text: $experience.location)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                
                Spacer()
                
                TextField("field.period".localized, text: $experience.period)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                    .multilineTextAlignment(.trailing)
            }
            
            // Description
            Divider()
                .padding(.vertical, DesignTokens.Spacing.xxs)
            
            Text("field.description".localized)
                .font(.caption2)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            TextEditor(text: $experience.description)
                .font(.body)
                .frame(minHeight: DesignTokens.InputSize.textEditorMinHeight)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct SkillRowView: View {
    @Binding var skill: Skill
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                TextField("field.skill".localized, text: $skill.name)
                    .font(DesignTokens.Typography.subheadline.font)
                Spacer()
                DeleteButton(label: skill.displayName, action: onDelete)
            }
            
            SkillLevelView(
                level: $skill.level,
                maxLevel: 5
            )
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct EducationRowView: View {
    @Binding var education: Education
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Degree and Delete button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    TextField("field.degree".localized, text: $education.degree)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    TextField("field.school".localized, text: $education.school)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                    
                    TextField("field.period".localized, text: $education.period)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.tertiary)
                }
                
                Spacer()
                
                DeleteButton(label: education.displayName, action: onDelete)
            }
            
            // Description
            if !education.description.isEmpty {
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                
                Text("field.description".localized)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                
                TextEditor(text: $education.description)
                    .font(.body)
                    .frame(minHeight: DesignTokens.InputSize.textEditorMinHeight)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

struct LanguageRowView: View {
    @Binding var language: Language
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("field.language".localized, text: $language.name)
                    .font(DesignTokens.Typography.body.font)
                
                Spacer()
                
                DeleteButton(label: language.displayName, action: onDelete)
            }
            
            HStack {
                Text("field.level".localized)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                Spacer()
                
                Picker("field.language_level", selection: $language.level) {
                    ForEach(LanguageProficiencyLevel.allCases, id: \.self) { level in
                        Text(level.localizationKey.localized)
                            .tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(DesignTokens.Typography.callout.font)
                .tint(DesignTokens.Colors.accent)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct CertificationRowView: View {
    @Binding var certification: Certification
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("field.certification_name".localized, text: $certification.name)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(label: certification.displayName, action: onDelete)
            }
            
            TextField("field.issuer".localized, text: $certification.issuer)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField("field.year".localized, text: Binding(
                    get: { String(certification.year) },
                    set: { newValue in
                        certification.year = Int(newValue) ?? 0
                    }
                ))
                .keyboardType(.numberPad)
                .font(DesignTokens.Typography.callout.font)
                .frame(maxWidth: DesignTokens.InputSize.textFieldWidth)
                
                Spacer()
                
                TextField("field.url".localized, text: $certification.url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("field.description".localized)
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $certification.description)
                    .frame(minHeight: DesignTokens.InputSize.textEditorMinHeight)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: DesignTokens.BorderWidth.thin)
                    )
            }
        }
        .cardStyle()
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct SocialLinkRowView: View {
    @Binding var social: Social
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            TextField("field.platform".localized, text: $social.platform)
                .font(DesignTokens.Typography.body.font)
                .frame(maxWidth: DesignTokens.InputSize.textFieldMaxWidth)
            
            TextField("field.url".localized, text: $social.url)
                .textContentType(.URL)
                .keyboardType(.URL)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.accent)
            
            DeleteButton(label: social.displayName, action: onDelete)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct InterestRowView: View {
    @Binding var interest: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            TextField("field.interest".localized, text: $interest)
                .font(DesignTokens.Typography.body.font)
            
            Spacer()
            
            DeleteButton(label: InterestEntry(text: interest).displayName, action: onDelete)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Helper Components

/// The trash button of a row. Borderless, so that a tap on the rest of the row never reaches it, and
/// large enough to be hit without hitting a neighbour.
struct DeleteButton: View {
    /// What the button deletes, for VoiceOver.
    let label: String
    let action: () -> Void
    @Environment(\.rowDeletionAnchor) private var deletionAnchor
    @State private var frames = ScreenFrames<String>()
    private let frameKey = "trash"
    
    var body: some View {
        Button {
            deletionAnchor.rect = frames.rect(for: frameKey)
            action()
        } label: {
            Image(systemName: "trash")
                .font(DesignTokens.IconSize.small.font)
                .foregroundColor(DesignTokens.Colors.error)
                .frame(
                    width: DesignTokens.InputSize.minimumTapTarget,
                    height: DesignTokens.InputSize.minimumTapTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .trackingScreenFrame(of: frameKey, in: frames)
        .accessibilityLabel("accessibility.delete_row".localizedWithArgs(label))
    }
}

struct CVEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignTokens.IconSize.large.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            Text(title)
                .font(DesignTokens.Typography.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
                .multilineTextAlignment(.center)
        }
        // The icon and the title centre in the width of the row, as the subtitle does
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}

struct AddButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DesignTokens.Typography.callout.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.accent)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}