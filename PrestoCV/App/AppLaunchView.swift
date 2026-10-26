import SwiftUI

/// Shows the app once its dependencies are built, or the reason they could not be, with a retry.
struct AppLaunchView: View {
    @StateObject private var viewModel: AppLaunchViewModel

    /// - Parameter viewModel: Made once for each window, by the app's entry point.
    init(viewModel: @autoclosure @escaping () -> AppLaunchViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
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
