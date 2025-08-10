import SwiftUI

// MARK: - Design System Tokens
// This file defines all design tokens used throughout the app
// to ensure consistency and maintainability

public enum DesignTokens {
    
    // MARK: - Spacing
    public enum Spacing {
        /// 2pt
        static let xxxs: CGFloat = 2
        /// 4pt
        static let xxs: CGFloat = 4
        /// 8pt
        static let xs: CGFloat = 8
        /// 12pt
        static let sm: CGFloat = 12
        /// 16pt
        static let md: CGFloat = 16
        /// 20pt
        static let lg: CGFloat = 20
        /// 24pt
        static let xl: CGFloat = 24
        /// 32pt
        static let xxl: CGFloat = 32
        /// 40pt
        static let xxxl: CGFloat = 40
        /// 48pt
        static let xxxxl: CGFloat = 48
        /// 64pt
        static let xxxxxl: CGFloat = 64
        /// 80pt
        static let xxxxxxl: CGFloat = 80
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        /// 4pt
        static let xs: CGFloat = 4
        /// 8pt
        static let sm: CGFloat = 8
        /// 12pt
        static let md: CGFloat = 12
        /// 16pt
        static let lg: CGFloat = 16
        /// 20pt
        static let xl: CGFloat = 20
        /// 24pt
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Typography
    public enum Typography {
        // System font sizes with semantic names
        case largeTitle
        case title1
        case title2
        case title3
        case headline
        case body
        case callout
        case subheadline
        case footnote
        case caption1
        case caption2
        
        // Custom sizes for specific use cases
        case hero        // Extra large for onboarding/empty states
        case buttonText  // Optimized for button labels
        
        var font: Font {
            switch self {
            case .largeTitle: return .largeTitle
            case .title1: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .body: return .body
            case .callout: return .callout
            case .subheadline: return .subheadline
            case .footnote: return .footnote
            case .caption1: return .caption
            case .caption2: return .caption2
            case .hero: return .system(size: 80, weight: .medium, design: .default)
            case .buttonText: return .headline
            }
        }
        
        var weight: Font.Weight {
            switch self {
            case .largeTitle, .title1, .title2, .headline, .buttonText:
                return .bold
            case .title3:
                return .semibold
            case .hero:
                return .medium
            case .body, .callout, .subheadline, .footnote, .caption1, .caption2:
                return .regular
            }
        }
    }
    
    // MARK: - Colors
    public enum Colors {
        // Semantic colors that adapt to light/dark mode
        static let primary: Color = .primary
        static let secondary: Color = .secondary
        static let accent: Color = .accentColor
        static let background: Color = Color(.systemBackground)
        static let secondaryBackground: Color = Color(.secondarySystemBackground)
        static let tertiaryBackground: Color = Color(.tertiarySystemBackground)
        
        // State colors
        static let success: Color = .green
        static let warning: Color = .orange
        static let error: Color = .red
        static let info: Color = .blue
        
        // Button colors
        static let primaryButtonText: Color = .white
        static let secondaryButtonText: Color = .accentColor
        static let disabledButtonText: Color = Color(.systemGray3)
        static let disabledButtonBackground: Color = Color(.systemGray5)
    }
    
    // MARK: - Icon Sizes
    public enum IconSize {
        case small      // 16pt
        case medium     // 24pt
        case large      // 32pt
        case xlarge     // 48pt
        case hero       // 80pt for onboarding/empty states
        
        var size: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            case .xlarge: return 48
            case .hero: return 80
            }
        }
        
        var font: Font {
            return .system(size: size)
        }
    }
    
    // MARK: - Shadow
    public enum Shadow {
        case none
        case small
        case medium
        case large
        
        var radius: CGFloat {
            switch self {
            case .none: return 0
            case .small: return 2
            case .medium: return 4
            case .large: return 8
            }
        }
        
        var offset: (x: CGFloat, y: CGFloat) {
            switch self {
            case .none: return (0, 0)
            case .small: return (0, 1)
            case .medium: return (0, 2)
            case .large: return (0, 4)
            }
        }
        
        var opacity: Double {
            switch self {
            case .none: return 0
            case .small: return 0.1
            case .medium: return 0.15
            case .large: return 0.2
            }
        }
    }
}


// MARK: - View Extensions for Easy Access
extension View {
    
    
    // MARK: - Typography
    func typography(_ style: DesignTokens.Typography) -> some View {
        self
            .font(style.font)
            .fontWeight(style.weight)
    }
    
    
    // MARK: - Shadow
    func designShadow(_ shadow: DesignTokens.Shadow) -> some View {
        self.shadow(
            color: .black.opacity(shadow.opacity),
            radius: shadow.radius,
            x: shadow.offset.x,
            y: shadow.offset.y
        )
    }
}