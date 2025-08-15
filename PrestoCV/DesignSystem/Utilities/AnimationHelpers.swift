import SwiftUI

/// Reusable animation helpers for common UI patterns
extension View {
    
    /// Executes an action with the standard ease-in-out animation
    /// - Parameter action: The action to execute with animation
    func animated(_ action: @escaping () -> Void) {
        withAnimation(DesignTokens.Animations.standardEaseInOut) {
            action()
        }
    }
}