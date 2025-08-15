import SwiftUI
import PrestoCVCore

// MARK: - Shared Row Components

struct ExperienceRowView: View {
    @Binding var experience: Experience
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("Job Title", text: $experience.title)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(action: onDelete)
            }
            
            TextField("Company", text: $experience.company)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField("Location", text: $experience.location)
                Spacer()
                TextField("Period", text: $experience.period)
                    .multilineTextAlignment(.trailing)
            }
            .font(DesignTokens.Typography.callout.font)
            .foregroundColor(DesignTokens.Colors.tertiary)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $experience.description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
}

struct SkillRowView: View {
    @Binding var skill: Skill
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                TextField("Skill", text: $skill.name)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("Degree", text: $education.degree)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(action: onDelete)
            }
            
            TextField("School", text: $education.school)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            TextField("Period", text: $education.period)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $education.description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
}

struct LanguageRowView: View {
    @Binding var language: Language
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            TextField("Language", text: $language.name)
                .font(DesignTokens.Typography.body.font)
            
            TextField("Level", text: $language.level)
                .multilineTextAlignment(.trailing)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.secondary)
                .frame(maxWidth: 100)
            
            DeleteButton(action: onDelete)
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
                TextField("Certification Name", text: $certification.name)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(action: onDelete)
            }
            
            TextField("Issuer", text: $certification.issuer)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField("Year", text: Binding(
                    get: { String(certification.year) },
                    set: { newValue in
                        certification.year = Int(newValue) ?? 0
                    }
                ))
                .keyboardType(.numberPad)
                .font(DesignTokens.Typography.callout.font)
                .frame(maxWidth: 80)
                
                Spacer()
                
                TextField("URL", text: $certification.url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $certification.description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
}

struct SocialLinkRowView: View {
    @Binding var social: Social
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            TextField("Platform", text: $social.platform)
                .font(DesignTokens.Typography.body.font)
                .frame(maxWidth: 100)
            
            TextField("URL", text: $social.url)
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
            TextField("Interest", text: $interest)
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