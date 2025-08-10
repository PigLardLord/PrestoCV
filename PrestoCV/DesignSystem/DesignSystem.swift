import SwiftUI

// MARK: - Design System
/// Central export for all design system components and tokens
/// Import this file to access the complete design system

// MARK: - Design Tokens
// Already available through DesignTokens enum

// MARK: - Components
// All components are available by importing their individual files
// This file serves as documentation and a single import point if needed

// MARK: - Component Categories

/// **Layout & State Components:**
/// - `LoadingView` - Consistent loading states with accessibility
/// - `EmptyStateView` - Configurable empty states with actions
/// - `ErrorView` - Error handling with retry functionality

/// **Interactive Components:**
/// - `PrimaryButton` - Main call-to-action buttons
/// - `SecondaryButton` - Secondary actions with multiple styles

/// **Usage Examples:**
/// ```swift
/// // Using design tokens directly
/// Text("Hello")
///     .typography(.headline)
///     .foregroundColor(DesignTokens.Colors.primary)
///     .padding(DesignTokens.Spacing.md)
///
/// // Using components
/// PrimaryButton(title: "Create CV", icon: "plus") {
///     // Action
/// }
///
/// EmptyStateView.noCVs {
///     // Create CV action
/// }
/// ```

// MARK: - Design System Principles

/// **Color Usage:**
/// - Use semantic colors that adapt to light/dark mode
/// - Primary colors for main content, secondary for supporting text
/// - Accent color for interactive elements and branding

/// **Typography:**
/// - Use semantic typography scales for consistency
/// - Headlines for titles, body for content, callout for secondary text
/// - All fonts include proper weight and accessibility support

/// **Spacing:**
/// - Use the spacing scale for consistent layout rhythm
/// - xs/sm for tight spacing, md/lg for standard spacing, xl+ for generous spacing
/// - Avoid magic numbers - always use defined spacing tokens

/// **Accessibility:**
/// - All components include proper accessibility labels and traits
/// - Touch targets meet minimum size requirements (44pt+)
/// - Color contrast follows WCAG guidelines
/// - Components work with Dynamic Type sizing

/// **Performance:**
/// - Views are optimized to minimize recomputations
/// - Animations use efficient transitions
/// - Components are lightweight and composable