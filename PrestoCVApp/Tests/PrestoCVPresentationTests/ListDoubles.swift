import Foundation
import Synchronization
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The browsing port on the in-memory store of an `EditingFake`, plus the store issues, samples and failures a test sets.
final class BrowsingFake: CVBrowsing {
    private let editing: EditingFake
    let issues = Mutex<[StoreIssue]>([])
    let listError = Mutex<EditFailure?>(nil)
    let onboardingError = Mutex<EditFailure?>(nil)
    let sampleList = Mutex<[CV]>([])
    let samplesError = Mutex<EditFailure?>(nil)
    let listCalls = Mutex(0)
    let sampleCalls = Mutex(0)

    init(editing: EditingFake) { self.editing = editing }

    func list() async throws(EditFailure) -> CVListing {
        listCalls.withLock { $0 += 1 }
        if let error = listError.withLock({ $0 }) { throw error }
        let stored: CVListing
        do { stored = try await editing.store.list() } catch { throw .unavailable }
        return CVListing(cvs: stored.cvs, issues: issues.withLock { $0 })
    }

    func onboarding() async throws(EditFailure) -> OnboardingState {
        if let error = onboardingError.withLock({ $0 }) { throw error }
        let listing = try await list()
        return listing.cvs.isEmpty && listing.issues.isEmpty ? .firstRun : .returning
    }

    func samples() async throws(EditFailure) -> [CV] {
        sampleCalls.withLock { $0 += 1 }
        if let error = samplesError.withLock({ $0 }) { throw error }
        return sampleList.withLock { $0 }
    }

    func startFromSample(_ sample: CV) -> CV { sample.duplicated(as: editing.ids.next(), title: sample.title) }
}

/// A look picker that offers fixed choices.
struct LookOptionsFake: LookOptionsProviding {
    func options() -> LookOptions {
        LookOptions(
            designs: [LookOption(id: "classic", nameCode: "design.classic"), LookOption(id: "modern", nameCode: "design.modern")],
            palettes: [LookOption(id: "ocean", nameCode: "palette.ocean"), LookOption(id: "forest", nameCode: "palette.forest")],
            fontSchemes: [LookOption(id: "sans", nameCode: "fonts.sans"), LookOption(id: "serif", nameCode: "fonts.serif")],
            defaultDesign: "classic", defaultPalette: "ocean", defaultFonts: "sans"
        )
    }
}

/// A moment a test moves by hand.
@MainActor
final class Moment {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

/// The list, the first run and the look picker on the fakes. The editors have always stored, unless a test closes the gate.
@MainActor
struct Browsing {
    let editing = EditingFake()
    let browsing: BrowsingFake
    let moment = Moment()
    let storedGate = Gate()

    init() { browsing = BrowsingFake(editing: editing) }

    /// The view's word for a CV with no title, and how it numbers a title
    static let untitled = "Untitled CV"

    func list() -> CVListViewModel {
        CVListViewModel(
            browsing: browsing, editing: editing, untitled: Self.untitled, numbered: { "\($0) (\($1))" },
            now: { [moment] in moment.date },
            editorsStored: { [storedGate] in await storedGate.pass() }
        )
    }

    func firstRun() -> FirstRunViewModel { FirstRunViewModel(browsing: browsing, editing: editing) }

    func look(of cv: CV) -> LookViewModel {
        LookViewModel(reference: CVReference(id: cv.id), editing: editing, options: LookOptionsFake())
    }

    func reference(_ cv: CV) -> CVReference { CVReference(id: cv.id) }

    /// A CV in the store with a person, titled by `title`, and the look `design` when given.
    func stored(title: String, fullName: String = "Mara Ellison", design: DesignChoice? = nil) async throws -> CV {
        try await editing.store.create(CV(
            id: editing.ids.next(), title: title, personal: PersonalDetails(fullName: fullName), design: design
        ))
    }

    /// A list that has read the store.
    func loadedList() async -> CVListViewModel {
        let list = list()
        await list.load()
        return list
    }
}
