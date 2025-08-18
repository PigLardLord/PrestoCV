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
                    TextField(String(localized: "field.job_title"), text: $experience.title)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    TextField(String(localized: "field.company"), text: $experience.company)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.error)
                }
                .buttonStyle(.plain)
            }
            
            // Location and Period
            HStack {
                TextField(String(localized: "field.location"), text: $experience.location)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                
                Spacer()
                
                TextField(String(localized: "field.period"), text: $experience.period)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                    .multilineTextAlignment(.trailing)
            }
            
            // Description
            Divider()
                .padding(.vertical, DesignTokens.Spacing.xxs)
            
            Text(String(localized: "field.description"))
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
                TextField(String(localized: "field.skill"), text: $skill.name)
                    .font(DesignTokens.Typography.subheadline.font)
                Spacer()
                DeleteButton(action: onDelete)
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
                    TextField(String(localized: "field.degree"), text: $education.degree)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    TextField(String(localized: "field.school"), text: $education.school)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                    
                    TextField(String(localized: "field.period"), text: $education.period)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.tertiary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.error)
                }
                .buttonStyle(.plain)
            }
            
            // Description
            if !education.description.isEmpty {
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                
                Text(String(localized: "field.description"))
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
                TextField(String(localized: "field.language"), text: $language.name)
                    .font(DesignTokens.Typography.body.font)
                
                Spacer()
                
                DeleteButton(action: onDelete)
            }
            
            HStack {
                Text(String(localized: "field.level"))
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                Spacer()
                
                Picker("field.language_level", selection: $language.level) {
                    ForEach(LanguageProficiencyLevel.allCases, id: \.self) { level in
                        Text(String(localized: String.LocalizationValue(level.localizationKey)))
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
                TextField(String(localized: "field.certification_name"), text: $certification.name)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(action: onDelete)
            }
            
            TextField(String(localized: "field.issuer"), text: $certification.issuer)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField(String(localized: "field.year"), text: Binding(
                    get: { String(certification.year) },
                    set: { newValue in
                        certification.year = Int(newValue) ?? 0
                    }
                ))
                .keyboardType(.numberPad)
                .font(DesignTokens.Typography.callout.font)
                .frame(maxWidth: DesignTokens.InputSize.textFieldWidth)
                
                Spacer()
                
                TextField(String(localized: "field.url"), text: $certification.url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(String(localized: "field.description"))
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
            TextField(String(localized: "field.platform"), text: $social.platform)
                .font(DesignTokens.Typography.body.font)
                .frame(maxWidth: DesignTokens.InputSize.textFieldMaxWidth)
            
            TextField(String(localized: "field.url"), text: $social.url)
                .textContentType(.URL)
                .keyboardType(.URL)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.accent)
            
            DeleteButton(action: onDelete)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct InterestRowView: View {
    @Binding var interest: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            TextField(String(localized: "field.interest"), text: $interest)
                .font(DesignTokens.Typography.body.font)
            
            Spacer()
            
            DeleteButton(action: onDelete)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Helper Components

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(DesignTokens.IconSize.small.font)
                .foregroundColor(DesignTokens.Colors.error)
        }
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
            
            Text(subtitle)
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
                .multilineTextAlignment(.center)
        }
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