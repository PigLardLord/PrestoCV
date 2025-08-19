import SwiftUI

/// A unified container view that handles all view states consistently
/// Works with the existing ViewState enum
struct ViewStateContainer<T, Content: View>: View {
    let viewState: ViewState<T>
    let loadingMessage: LocalizedStringKey
    let onRetry: (() async -> Void)?
    @ViewBuilder let content: (T) -> Content
    
    init(
        viewState: ViewState<T>,
        loadingMessage: LocalizedStringKey = "common.processing",
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
            idleStateView
        case .loading:
            loadingStateView
        case .loaded(let data):
            loadedStateView(data: data)
        case .error(let message):
            errorStateView(message: message)
        }
    }
    
    // MARK: - State Views
    
    @ViewBuilder
    private var idleStateView: some View {
        Color.clear
            .onAppear(perform: triggerInitialLoadIfNeeded)
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        LoadingView.fullscreen(message: loadingMessage)
    }
    
    @ViewBuilder
    private func loadedStateView(data: T) -> some View {
        content(data)
    }
    
    @ViewBuilder
    private func errorStateView(message: String) -> some View {
        if onRetry != nil {
            ErrorView.generic(
                message: message,
                onRetry: createRetryAction
            )
        } else {
            ErrorView(
                icon: "exclamationmark.triangle",
                title: "common.error".localized,
                message: message
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func triggerInitialLoadIfNeeded() {
        guard let onRetry = onRetry else { return }
        Task {
            await onRetry()
        }
    }
    
    private func createRetryAction() {
        guard let onRetry = onRetry else { return }
        Task {
            await onRetry()
        }
    }
}

/// Extension for ViewState to provide a simpler container when data is optional
extension ViewStateContainer where T == Void {
    init(
        viewState: ViewState<T>,
        loadingMessage: LocalizedStringKey = "common.processing",
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