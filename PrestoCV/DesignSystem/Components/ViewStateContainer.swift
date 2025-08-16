import SwiftUI

/// A unified container view that handles all view states consistently
/// Works with the existing ViewState enum
struct ViewStateContainer<T, Content: View>: View {
    let viewState: ViewState<T>
    let loadingMessage: String
    let onRetry: (() async -> Void)?
    @ViewBuilder let content: (T) -> Content
    
    init(
        viewState: ViewState<T>,
        loadingMessage: String = "Loading...",
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.viewState = viewState
        self.loadingMessage = loadingMessage
        self.onRetry = onRetry
        self.content = content
    }
    
    var body: some View {
        switch viewState {
        case .idle:
            // Idle state could show a placeholder or nothing
            Color.clear
                .onAppear {
                    // Trigger initial load if onRetry is provided
                    if let onRetry = onRetry {
                        Task {
                            await onRetry()
                        }
                    }
                }
            
        case .loading:
            LoadingView.fullscreen(message: loadingMessage)
            
        case .loaded(let data):
            content(data)
            
        case .error(let message):
            if let onRetry = onRetry {
                ErrorView.generic(
                    message: message,
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
                    message: message
                )
            }
        }
    }
}

/// Extension for ViewState to provide a simpler container when data is optional
extension ViewStateContainer where T == Void {
    init(
        viewState: ViewState<T>,
        loadingMessage: String = "Loading...",
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            viewState: viewState,
            loadingMessage: loadingMessage,
            onRetry: onRetry,
            content: { _ in content() }
        )
    }
}