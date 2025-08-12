import SwiftUI

/// A reusable text field component with a label above it
/// Follows the design system tokens for consistent styling
struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.footnote.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            TextField(placeholder, text: $text)
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
    }
}

struct LabeledTextField_Previews: PreviewProvider {
    @State static var text = "Sample text"
    
    static var previews: some View {
        LabeledTextField(label: "Label", text: $text, placeholder: "Enter text")
            .padding()
            .previewLayout(.sizeThatFits)
    }
}