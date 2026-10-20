import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - AppRouter Navigation Tests

@MainActor
@Suite("AppRouter Navigation Tests")
struct AppRouterTests {

    // MARK: - Navigate To Root and Back

    @Test("navigateToRoot clears the whole navigation path, and is safe on an empty one")
    func navigateToRootClearsPath() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)

        router.navigateToRoot()
        #expect(router.navigationPath.count == 0)

        router.navigateToRoot()
        #expect(router.navigationPath.count == 0)
    }

    @Test("navigateBack removes only the last screen, and does nothing on an empty path")
    func navigateBackRemovesLastItem() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)

        router.navigateBack()
        #expect(router.navigationPath.count == 1)

        router.navigateBack()
        router.navigateBack()
        #expect(router.navigationPath.count == 0)
    }

    @Test("navigate appends the route to the path")
    func navigateAppendsRoute() {
        let router = AppRouter()

        router.navigate(to: .templateSelection)

        #expect(router.navigationPath.count == 1)
        #expect(router.currentRoute == .templateSelection)
    }

    // MARK: - Opening the Editor

    @Test("A new CV opens on its template, in place of the screens that led to it, so Back returns to the list")
    func newCVReplacesTheScreensThatLedToIt() {
        let router = AppRouter()
        router.navigate(to: .templateSelection)
        let template = CVModel(name: "Sample Template")

        router.navigateToEditorWithTemplate(template)

        #expect(router.currentRoute == .cvEditor(.new(template: template)), "The route carries the template")
        #expect(router.navigationPath.count == 1, "Only the editor is above the list")
    }

    @Test("An AI draft opens as a draft, in place of the AI screen, so Back returns to the list")
    func draftReplacesTheAIScreen() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)
        router.navigate(to: .aiGeneration)
        let draft = CVModel(name: "Drafted by AI")

        router.navigateToEditorWithAIDraft(draft)

        #expect(router.currentRoute == .cvEditor(.draft(draft)))
        #expect(router.navigationPath.count == 1)
    }

    @Test("Picking a CV of the list opens it as stored")
    func pickingACVOpensIt() {
        let router = AppRouter()
        let cvId = UUID().uuidString

        router.openEditor(.stored(cvId: cvId))

        #expect(router.currentRoute == .cvEditor(.stored(cvId: cvId)))
        #expect(router.navigationPath.count == 1)
    }

    @Test("Each editor opens on its own request: nothing of the one before reaches the next")
    func eachEditorOpensOnItsOwnRequest() {
        let router = AppRouter()
        router.navigateToEditorWithAIDraft(CVModel(name: "Drafted by AI"))
        router.navigateToRoot()
        let template = CVModel(name: "Template")

        router.navigateToEditorWithTemplate(template)

        #expect(router.currentRoute == .cvEditor(.new(template: template)), "A template must not open as a draft")
    }

    // MARK: - AI Drafting Release Switch

    @Test("With AI drafting not shipped, navigating to it leaves the path and the route unchanged")
    func aiRouteIsRefusedWhenNotShipped() {
        let router = AppRouter(isAIShipped: false)
        router.navigate(to: .templateSelection)

        router.navigate(to: .aiGeneration)

        #expect(router.navigationPath.count == 1, "The AI route must not be appended")
        #expect(router.currentRoute == .templateSelection)
    }

    @Test("With AI drafting not shipped, a path given the AI route directly does not open the generation screen")
    func aiRouteInsertedDirectlyShowsTheList() {
        let router = AppRouter(isAIShipped: false)

        router.navigationPath.append(Route.aiGeneration)

        #expect(router.destination(for: .aiGeneration) == .list)
    }

    @Test("With AI drafting not shipped, the other routes navigate as before")
    func otherRoutesNavigateWhenNotShipped() {
        let router = AppRouter(isAIShipped: false)

        router.navigate(to: .templateSelection)
        router.navigateToEditorWithTemplate(CVModel())

        #expect(router.navigationPath.count == 1)
        guard case .cvEditor(.new) = router.currentRoute else {
            Issue.record("The editor should open on a new CV, not \(router.currentRoute)")
            return
        }
    }

    @Test("With AI drafting shipped, navigating to it opens the generation screen")
    func aiRouteNavigatesWhenShipped() {
        let router = AppRouter(isAIShipped: true)
        router.navigate(to: .templateSelection)

        router.navigate(to: .aiGeneration)

        #expect(router.navigationPath.count == 2)
        #expect(router.currentRoute == .aiGeneration)
        #expect(router.destination(for: .aiGeneration) == .aiGeneration)
    }
}
