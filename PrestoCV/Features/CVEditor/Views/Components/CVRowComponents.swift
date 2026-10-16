import SwiftUI
import PrestoCVCore

// MARK: - Shared Row Components

/// Lays its children side by side, and one above the other at the largest text sizes, where a row would cut them off.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let spacing: CGFloat
    /// Receives whether the children are stacked
    @ViewBuilder let content: (_ isStacked: Bool) -> Content
    
    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout {
            content(isStacked)
        }
    }
}

struct ExperienceRowView: View {
    @Binding var experience: Experience
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Title and Delete button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    GrowingTextField("field.job_title".localized, text: $experience.title)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    GrowingTextField("field.company".localized, text: $experience.company)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
                
                Spacer()
                
                DeleteButton(label: experience.displayName, action: onDelete)
            }
            
            // Location and Period
            AdaptiveStack(spacing: DesignTokens.Spacing.sm) { isStacked in
                GrowingTextField("field.location".localized, text: $experience.location)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                GrowingTextField("field.period".localized, text: $experience.period)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.tertiary)
                    .multilineTextAlignment(isStacked ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: isStacked ? .leading : .trailing)
            }
            
            RowDescriptionEditor(text: $experience.description)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

/// The description box of a row. It is always there, so a description can be typed, cleared and typed again.
struct RowDescriptionEditor: View {
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.xxs)
            
            Text("field.description".localized)
                .font(.caption2)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: DesignTokens.InputSize.textEditorMinHeight)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityLabel("field.description".localized)
        }
    }
}

struct SkillRowView: View {
    @Binding var skill: Skill
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                GrowingTextField("field.skill".localized, text: $skill.name)
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
                    GrowingTextField("field.degree".localized, text: $education.degree)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    GrowingTextField("field.school".localized, text: $education.school)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                    
                    GrowingTextField("field.period".localized, text: $education.period)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.tertiary)
                }
                
                Spacer()
                
                DeleteButton(label: education.displayName, action: onDelete)
            }
            
            RowDescriptionEditor(text: $education.description)
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
                GrowingTextField("field.language".localized, text: $language.name)
                    .font(DesignTokens.Typography.body.font)
                
                Spacer()
                
                DeleteButton(label: language.displayName, action: onDelete)
            }
            
            // The picker names itself: one "Level" label, not a second one beside it. Every level fits beside the
            // chevrons of the menu without breaking a word, so the rows of all languages share one size.
            WholeWordsFit(
                fitting: LanguageProficiencyLevel.allCases.map { $0.localizationKey.localized },
                beside: Image(systemName: "chevron.up.chevron.down")
            ) {
                Picker("field.level", selection: $language.level) {
                    ForEach(LanguageProficiencyLevel.allCases, id: \.self) { level in
                        Text(level.localizationKey.localized)
                            .tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(DesignTokens.Colors.accent)
            }
            .font(DesignTokens.Typography.callout.font)
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
                GrowingTextField("field.certification_name".localized, text: $certification.name)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                DeleteButton(label: certification.displayName, action: onDelete)
            }
            
            GrowingTextField("field.issuer".localized, text: $certification.issuer)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            AdaptiveStack(spacing: DesignTokens.Spacing.sm) { _ in
                TextField("field.year".localized, text: Binding(
                    get: { String(certification.year) },
                    set: { newValue in
                        certification.year = Int(newValue) ?? 0
                    }
                ))
                .keyboardType(.numberPad)
                .font(DesignTokens.Typography.callout.font)
                .frame(maxWidth: DesignTokens.InputSize.textFieldWidth, alignment: .leading)
                .accessibilityLabel("field.year".localized)
                
                GrowingTextField("field.url".localized, text: $certification.url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            AdaptiveStack(spacing: DesignTokens.Spacing.md) { isStacked in
                GrowingTextField("field.platform".localized, text: $social.platform)
                    .font(DesignTokens.Typography.body.font)
                    .frame(maxWidth: isStacked ? .infinity : DesignTokens.InputSize.textFieldMaxWidth, alignment: .leading)
                
                GrowingTextField("field.url".localized, text: $social.url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
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
            GrowingTextField("field.interest".localized, text: $interest)
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
            
            WholeWordsText(title)
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
            Label {
                WholeWordsText(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(DesignTokens.Typography.callout.font)
            .fontWeight(.medium)
            .padding(.vertical, DesignTokens.Spacing.sm)
            // The whole row still takes the tap, as it did when the form drew the button
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(AccentTextButtonStyle())
    }
}