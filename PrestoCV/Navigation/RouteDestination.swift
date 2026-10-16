/// The screen a route of the navigation path shows.
///
/// A release that does not ship AI drafting (`AIFeature.isShipped`) shows the list for its route, so a path that names
/// it, however it was built, never opens the generation screen.
enum RouteDestination: Equatable {
    case list
    case templateSelection
    case aiGeneration
    case cvEditor(cvId: String?)

    static func resolve(_ route: Route, isAIShipped: Bool) -> RouteDestination {
        switch route {
        case .onboarding, .cvList:
            return .list
        case .templateSelection:
            return .templateSelection
        case .aiGeneration:
            return isAIShipped ? .aiGeneration : .list
        case .cvEditor(let cvId):
            return .cvEditor(cvId: cvId)
        }
    }
}
