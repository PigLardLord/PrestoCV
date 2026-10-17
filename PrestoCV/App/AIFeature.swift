/// Release switch for AI drafting.
///
/// Setting `isShipped` to false hides the AI draft on every device, on the first run and on the "New CV" screen, and keeps
/// the generation screen out of reach of any navigation (`AppRouter`, `RouteDestination`), leaving the rest of the app
/// untouched.
enum AIFeature {
    static let isShipped = true
}
