import SwiftUI

// MARK: - Reusable Loading View Component
/// A consistent loading view component used throughout the app
/// with proper accessibility support and design token integration
struct LoadingView: View {
    let message: LocalizedStringKey
    let style: Style
    
    init(
        message: LocalizedStringKey = LocalizedStringKey("common.processing"),
        style: Style = .default
    ) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(style.progressViewScale)
                .progressViewStyle(CircularProgressViewStyle(tint: style.tintColor))
            
            Text(message)
                .typography(.callout)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(LocalizedStringKey("common.processing"))
        }
        .frame(maxWidth: .infinity, maxHeight: style.fillsContainer ? .infinity : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LocalizedStringKey("common.processing"))
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Style Options
    enum Style {
        case `default`
        case compact
        case fullscreen
        case button
        
        var progressViewScale: CGFloat {
            switch self {
            case .default, .fullscreen: return 1.0
            case .compact: return 0.9
            case .button: return 0.8
            }
        }
        
        var tintColor: Color {
            switch self {
            case .default, .compact, .fullscreen: return DesignTokens.Colors.accent
                case .button: return DesignTokens.Colors.primaryButtonForeground
            }
        }
        
        var fillsContainer: Bool {
            switch self {
            case .fullscreen: return true
            case .default, .compact, .button: return false
            }
        }
    }
}

// MARK: - Convenience Initializers
extension LoadingView {
    
    /// Creates a fullscreen loading view
    static func fullscreen(message: LocalizedStringKey = LocalizedStringKey("common.processing")) -> LoadingView {
        LoadingView(message: message, style: .fullscreen)
    }
    
    /// Creates a compact loading view for inline use
    static func compact(message: LocalizedStringKey = LocalizedStringKey("")) -> LoadingView {
        LoadingView(message: message, style: .compact)
    }
    
    /// Creates a loading view for use inside buttons
    static func button() -> LoadingView {
        LoadingView(message: LocalizedStringKey(""), style: .button)
    }
}

// MARK: - Previews
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default style
            LoadingView()
                .previewDisplayName("Default")
                .padding()
            
            // Fullscreen style
            LoadingView.fullscreen(message: LocalizedStringKey("cv.creating"))
                .previewDisplayName("Fullscreen")
            
            // Compact style
            LoadingView.compact(message: LocalizedStringKey("common.save"))
                .previewDisplayName("Compact")
                .padding()
            
            // Button style
            HStack {
                LoadingView.button()
                Text(LocalizedStringKey("common.processing"))
            }
            .foregroundColor(.white)
            .padding()
            .background(DesignTokens.Colors.accent)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .previewDisplayName("Button Style")
            
            // Custom message
            LoadingView(message: LocalizedStringKey("onboarding.create.button"))
                .previewDisplayName("Custom Message")
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
