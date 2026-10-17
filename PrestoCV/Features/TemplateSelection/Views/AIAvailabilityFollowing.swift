import SwiftUI

extension View {
    /// Keeps the AI choice of `viewModel` up to date while the view is on screen. The availability is read again
    /// whenever the view comes into view and whenever the app comes back to the front, as it does after the person
    /// turned Apple Intelligence on in Settings. While the model downloads, the choice turns on by itself when it is
    /// ready.
    func followingAIAvailability(of viewModel: NewCVChoicesViewModel) -> some View {
        modifier(AIAvailabilityFollowing(viewModel: viewModel))
    }
}

private struct AIAvailabilityFollowing: ViewModifier {
    @ObservedObject var viewModel: NewCVChoicesViewModel
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            // The screen may have been away: the choice is read again whenever it comes back into view
            .task {
                viewModel.refreshAIAvailability()
            }
            // Turning Apple Intelligence on happens in Settings: the choice is read again on the way back
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.refreshAIAvailability()
                }
            }
            // While the model downloads, the choice turns on by itself when it is ready. The task starts again when
            // the entry changes, and ends with the screen.
            .task(id: viewModel.aiEntry) {
                await viewModel.followAIAvailability()
            }
    }
}
