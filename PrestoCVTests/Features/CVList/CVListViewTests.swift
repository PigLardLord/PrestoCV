import Testing
import Foundation
@testable import PrestoCV

// MARK: - CVListView Delete Button Tests

@Suite("CVListView Delete Button - Bug Fix Verification")
struct CVListViewTests {

    // MARK: - Helper Methods

    /// Returns the path to CVListView.swift in the main app target
    private func getCVListViewFilePath() -> URL {
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Remove CVListViewTests.swift
            .deletingLastPathComponent()  // Remove CVList
            .deletingLastPathComponent()  // Remove Features
            .deletingLastPathComponent()  // Remove PrestoCVTests
            .appendingPathComponent("PrestoCV")
            .appendingPathComponent("Features")
            .appendingPathComponent("CVList")
            .appendingPathComponent("Views")
            .appendingPathComponent("CVListView.swift")
    }

    // MARK: - Bug Fix: Delete Button Role Should Be .none to Prevent Flickering

    @Test("CVListView source code verification - delete button uses role .none")
    func deleteButtonUsesNoneRole() async throws {
        // This test verifies that the delete button in swipeActions uses role: .none
        // instead of role: .destructive to prevent the SwiftUI flickering bug
        // where the row disappears when the confirmationDialog appears.
        //
        // Bug context:
        // - Using role: .destructive triggers SwiftUI's automatic delete animation
        // - This animation clears state and causes confirmationDialog to flicker/disappear
        // - Workaround: Use role: .none with manual .tint(DesignTokens.Colors.error)
        //
        // References:
        // - https://stackoverflow.com/questions/71442998/swiftui-confirmationdialog-disappearing-after-one-second
        // - https://stackoverflow.com/questions/74393006/swiftui-confirmationdialog-on-list-listrow-is-working-on-ios-15-but-is-unrelia

        let content = try String(contentsOf: getCVListViewFilePath(), encoding: .utf8)

        // Verify the delete button uses role: .none
        #expect(content.contains("Button(role: .none, action: onDelete)"), "Delete button should use 'role: .none' to prevent SwiftUI flickering bug")

        // Verify manual tinting is applied
        #expect(content.contains(".tint(DesignTokens.Colors.error)") || content.contains(".tint(DesignTokens.Colors.destructive)"), "Delete button should have manual tinting with DesignTokens.Colors.error")
    }

    @Test("CVListView should NOT use role .destructive for delete button")
    func deleteButtonDoesNotUseDestructiveRole() async throws {
        // This test ensures we never reintroduce the bug by accidentally
        // changing back to role: .destructive on the delete button

        let content = try String(contentsOf: getCVListViewFilePath(), encoding: .utf8)

        // Check for the problematic pattern in swipeActions
        // We need to be careful to only check the delete button, not the confirmation dialog button
        let lines = content.components(separatedBy: .newlines)
        var inSwipeActions = false
        var foundProblematicPattern = false

        for line in lines {
            // Track when we enter swipeActions block
            if line.contains(".swipeActions") {
                inSwipeActions = true
            }

            // Track when we exit swipeActions block
            if inSwipeActions && line.contains("}") && !line.contains("{") {
                // Check if this is the closing brace of swipeActions
                if line.trimmingCharacters(in: .whitespaces).starts(with: "}") {
                    inSwipeActions = false
                }
            }

            // Check for destructive role in swipeActions (but not in confirmationDialog)
            if inSwipeActions &&
               line.contains("Button(role: .destructive") &&
               line.contains("onDelete") {
                foundProblematicPattern = true
                break
            }
        }

        #expect(!foundProblematicPattern, "Delete button in swipeActions should NOT use 'role: .destructive'")
    }

    @Test("Confirmation dialog should still use destructive role")
    func confirmationDialogUsesDestructiveRole() async throws {
        // The confirmation dialog button (inside confirmationDialog modifier)
        // SHOULD use role: .destructive - the bug only affects swipeActions

        let content = try String(contentsOf: getCVListViewFilePath(), encoding: .utf8)

        // Verify confirmationDialog still has proper destructive button
        #expect(content.contains("confirmationDialog"), "CVListView should have a confirmationDialog for delete confirmation")

        // The confirmation dialog should have a destructive button
        // This is correct and doesn't cause the bug
        let hasDestructiveInDialog = content.contains("role: .destructive") && content.contains("confirmationDialog")

        #expect(hasDestructiveInDialog, "Confirmation dialog should have a destructive button (role: .destructive)")
    }

    @Test("Design tokens are used instead of hardcoded colors")
    func usesDesignTokensForColors() async throws {
        // Verify that design tokens are used instead of hardcoded colors
        // per the project's UI rules

        let content = try String(contentsOf: getCVListViewFilePath(), encoding: .utf8)

        // Should not have hardcoded .red in swipeActions
        let lines = content.components(separatedBy: .newlines)
        var inSwipeActions = false
        var hasHardcodedRed = false

        for line in lines {
            if line.contains(".swipeActions") {
                inSwipeActions = true
            }

            if inSwipeActions && line.contains("}") && !line.contains("{") {
                if line.trimmingCharacters(in: .whitespaces).starts(with: "}") {
                    inSwipeActions = false
                }
            }

            // Check for hardcoded .red (but allow Color.red in comments)
            if inSwipeActions &&
               (line.contains(".tint(.red)") || line.contains(".tint(Color.red)")) &&
               !line.trimmingCharacters(in: .whitespaces).starts(with: "//") {
                hasHardcodedRed = true
                break
            }
        }

        #expect(!hasHardcodedRed, "Should use DesignTokens.Colors.error instead of hardcoded .red color")

        // Should use DesignTokens.Colors.error or similar
        #expect(content.contains("DesignTokens.Colors.error") || content.contains("DesignTokens.Colors.destructive"), "Should use design token for error/destructive color")
    }
}
