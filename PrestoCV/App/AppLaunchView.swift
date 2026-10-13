import SwiftUI
import PrestoCVCore

/// Shows the app once its dependencies are built, or the reason they could not be, with a retry.
struct AppLaunchView: View {
    @StateObject private var viewModel: AppLaunchViewModel

    init(makeDependencyContainer: @escaping @MainActor () -> DependencyContainerProtocol) {
        self._viewModel = StateObject(
            wrappedValue: AppLaunchViewModel(makeDependencyContainer: makeDependencyContainer)
        )
    }

    var body: some View {
        switch viewModel.phase {
        case .ready(let dependencies):
            AppRootView(dependencies: dependencies)
                .task { await viewModel.start() }
        case .failed(let message):
            ErrorView.generic(message: message, onRetry: viewModel.retry)
        }
    }
}
