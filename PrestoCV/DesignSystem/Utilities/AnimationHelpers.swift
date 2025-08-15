import SwiftUI

/// Modern SwiftUI animation helpers following Apple's best practices
/// Based on WWDC 2023 guidance - withAnimation must be in view context
struct AnimatedAction {
    
    /// Creates a clean closure that wraps an action with animation
    /// Usage: Button("Add", action: AnimatedAction.create { viewModel.add() })
    static func create(_ action: @escaping () -> Void) -> () -> Void {
        return {
            withAnimation(DesignTokens.Animations.standardEaseInOut) {
                action()
            }
        }
    }
    
    /// Creates a clean closure that wraps an indexed action with animation
    /// Usage: onDelete: AnimatedAction.indexed { viewModel.remove(at: $0) }
    static func indexed(_ action: @escaping (Int) -> Void) -> (Int) -> Void {
        return { index in
            withAnimation(DesignTokens.Animations.standardEaseInOut) {
                action(index)
            }
        }
    }
}