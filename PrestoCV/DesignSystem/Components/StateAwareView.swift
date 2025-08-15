import SwiftUI

/// A reusable view that handles loading, error, and content states
struct StateAwareView<Content: View>: View {
    let isLoading: Bool
    let errorMessage: String
    let loadingMessage: String
    let onRetry: (() async -> Void)?
    @ViewBuilder let content: () -> Content
    
    init(
        isLoading: Bool,
        errorMessage: String = "",
        loadingMessage: String = "Loading...",
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.loadingMessage = loadingMessage
        self.onRetry = onRetry
        self.content = content
    }
    
    var body: some View {
        if isLoading {
            LoadingView.fullscreen(message: loadingMessage)
        } else if !errorMessage.isEmpty {
            if let onRetry = onRetry {
                ErrorView.generic(
                    message: errorMessage,
                    onRetry: {
                        Task {
                            await onRetry()
                        }
                    }
                )
            } else {
                ErrorView(
                    icon: "exclamationmark.triangle",
                    title: "Error",
                    message: errorMessage
                )
            }
        } else {
            content()
        }
    }
}