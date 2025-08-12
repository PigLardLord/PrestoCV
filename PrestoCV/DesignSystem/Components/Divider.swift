import SwiftUI

/// A consistent divider component for separating content sections in CV views
/// Follows the design system tokens for consistent styling
struct CVDivider: View {
    let style: Style
    
    enum Style {
        case solid
        case dashed
        case inset
        
        var height: CGFloat {
            switch self {
            case .solid, .dashed: return 1
            case .inset: return 1
            }
        }
        
        var color: Color {
            DesignTokens.Colors.divider
        }
        
        var padding: CGFloat {
            switch self {
            case .solid, .dashed: return 0
            case .inset: return DesignTokens.Spacing.lg
            }
        }
    }
    
    init(style: Style = .solid) {
        self.style = style
    }
    
    var body: some View {
        if style == .dashed {
            dashedDivider
        } else {
            solidDivider
        }
    }
    
    private var solidDivider: some View {
        SwiftUI.Divider()
            .background(style.color)
            .padding(.horizontal, style.padding)
    }
    
    private var dashedDivider: some View {
        GeometryReader { geometry in
            Path { path in
                let dashPattern: [CGFloat] = [5, 5]
                let totalDashLength = dashPattern.reduce(0, +)
                let numberOfDashes = Int(geometry.size.width / totalDashLength) + 1
                
                var currentX: CGFloat = 0
                var drawingLine = true
                
                for _ in 0..<numberOfDashes {
                    for dashLength in dashPattern {
                        if drawingLine {
                            path.move(to: CGPoint(x: currentX, y: 0))
                            path.addLine(to: CGPoint(x: currentX + dashLength, y: 0))
                        }
                        currentX += dashLength
                        drawingLine.toggle()
                    }
                }
            }
            .stroke(style.color, lineWidth: style.height)
        }
        .frame(height: style.height)
        .padding(.horizontal, style.padding)
    }
}

// MARK: - Convenience Initializers
extension CVDivider {
    static func inset() -> CVDivider {
        CVDivider(style: .inset)
    }
    
    static func dashed() -> CVDivider {
        CVDivider(style: .dashed)
    }
}

// MARK: - Previews
struct CVDivider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Content above solid divider")
            
            CVDivider()
            
            Text("Content below solid divider")
            
            CVDivider.inset()
            
            Text("Content below inset divider")
            
            CVDivider.dashed()
            
            Text("Content below dashed divider")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}