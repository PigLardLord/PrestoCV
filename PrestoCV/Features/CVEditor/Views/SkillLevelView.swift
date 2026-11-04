import SwiftUI
import PrestoCVCore

/// The stars of a skill's level. A tap on a star is handed to `onChoose`, counted from one.
struct SkillLevelView: View {
    let level: Int
    let maxLevel: Int
    let onChoose: (Int) -> Void
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Image(systemName: index < level ? "star.fill" : "star")
                    .foregroundColor(index < level ? .yellow : DesignTokens.Colors.tertiary)
                    .onTapGesture {
                        onChoose(index + 1)
                    }
                    .accessibilityLabel("accessibility.skill_level_value".localizedWithArgs(index + 1, maxLevel))
                    .accessibilityRemoveTraits(.isImage)
                    .accessibilityAddTraits(
                        (index + 1) <= level ? .isSelected : .isButton
                    )
            }
        }
        .font(DesignTokens.Typography.headline.font)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("accessibility.skill_level_selector".localized)
        .accessibilityValue("accessibility.stars_selected".localizedWithArgs(level, maxLevel))
    }
}

struct SkillLevelView_Previews: PreviewProvider {
    static var previews: some View {
        SkillLevelView(level: 3, maxLevel: Skill.maxLevel) { _ in }
            .padding()
            .previewLayout(.sizeThatFits)
    }
}