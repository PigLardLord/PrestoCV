import Testing
@testable import PrestoCV
import PrestoCVCore

@Suite("RouteDestination Tests - the screen each route shows, and the release switch of AI drafting")
struct RouteDestinationTests {

    static let blankCV = EditorRequest.new(template: CVModel(), notice: nil)

    @Test("With AI drafting shipped, every route shows its own screen", arguments: [
        (Route.onboarding, RouteDestination.list),
        (.cvList, .list),
        (.templateSelection, .templateSelection),
        (.aiGeneration, .aiGeneration),
        (.importCV, .importCV),
        (.cvEditor(RouteDestinationTests.blankCV), .cvEditor(RouteDestinationTests.blankCV)),
        (.cvEditor(.stored(cvId: "saved")), .cvEditor(.stored(cvId: "saved"))),
    ])
    func everyRouteShowsItsScreen(route: Route, expected: RouteDestination) {
        #expect(RouteDestination.resolve(route, isAIShipped: true) == expected)
    }

    @Test("With AI drafting not shipped, its route shows the list instead of the generation screen")
    func aiRouteShowsTheListWhenNotShipped() {
        #expect(RouteDestination.resolve(.aiGeneration, isAIShipped: false) == .list)
    }

    @Test("With AI drafting not shipped, the other routes still show their own screen", arguments: [
        (Route.templateSelection, RouteDestination.templateSelection),
        (.importCV, .importCV),
        (.cvEditor(RouteDestinationTests.blankCV), .cvEditor(RouteDestinationTests.blankCV)),
        (.cvList, .list),
    ])
    func otherRoutesAreUntouchedWhenNotShipped(route: Route, expected: RouteDestination) {
        #expect(RouteDestination.resolve(route, isAIShipped: false) == expected)
    }
}
