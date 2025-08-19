import SwiftUI

struct SkillLevelView: View {
    @Binding var level: Int
    let maxLevel: Int
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Image(systemName: index < level ? "star.fill" : "star")
                    .foregroundColor(index < level ? .yellow : DesignTokens.Colors.tertiary)
                    .onTapGesture {
                        // Update level to the tapped star's position + 1
                        // If tapping the same star, toggle it off (set to 0)
                        level = (index + 1) == level ? 0 : index + 1
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
    @State static var level = 3
    
    static var previews: some View {
        SkillLevelView(level: $level, maxLevel: 5)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}