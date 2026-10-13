import PrestoCVCore

/// What the root of the app shows.
///
/// The list of CVs is always the root. A user with no CV sees it with its empty state, so there is
/// no second root to come back to after the first CV is saved.
enum RootDestination: Equatable {
    case loading
    case list
    case error(message: String)

    static func resolve(_ state: OnboardingState) -> RootDestination {
        switch state {
        case .loading:
            return .loading
        case .firstTime, .returning:
            return .list
        case .error(let error):
            return .error(message: error.localizedDescription)
        }
    }
}
