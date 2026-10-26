import SwiftUI

// MARK: - Reusable Loading View Component
/// A consistent loading view component used throughout the app
/// with proper accessibility support and design token integration
struct LoadingView: View {
    let message: LocalizedStringKey
    /// What VoiceOver reads for the whole view. It reads "Processing..." unless the view says better what it waits for.
    let voiceOverLabel: LocalizedStringKey
    let style: Style
    
    init(
        message: LocalizedStringKey = "common.processing".asLoclizedKey,
        voiceOverLabel: LocalizedStringKey = "common.processing".asLoclizedKey,
        style: Style = .default
    ) {
        self.message = message
        self.voiceOverLabel = voiceOverLabel
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
                .accessibilityLabel("common.processing".asLoclizedKey)
        }
        .frame(maxWidth: .infinity, maxHeight: style.fillsContainer ? .infinity : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
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
    static func fullscreen(message: LocalizedStringKey = "common.processing".asLoclizedKey) -> LoadingView {
        LoadingView(message: message, style: .fullscreen)
    }
    
    /// Creates a compact loading view for inline use
    static func compact() -> LoadingView {
        LoadingView(style: .compact)
    }
    
    /// Creates a loading view for use inside buttons
    static func button() -> LoadingView {
        LoadingView(style: .button)
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
            LoadingView.fullscreen(message: "common.loading".asLoclizedKey)
                .previewDisplayName("Fullscreen")
            
            // Compact style
            LoadingView.compact()
                .previewDisplayName("Compact")
                .padding()
            
            // Button style
            HStack {
                LoadingView.button()
                Text("common.processing".asLoclizedKey)
            }
            .foregroundColor(DesignTokens.Colors.primaryButtonForeground)
            .padding()
            .background(DesignTokens.Colors.primaryButtonBackground)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .previewDisplayName("Button Style")
            
            // Custom message
            LoadingView(message: "onboarding.create.button".asLoclizedKey)
                .previewDisplayName("Custom Message")
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
