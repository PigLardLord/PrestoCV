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
    /// Holds the answer of `onboarding()` after the store was read, so that a test decides when each answer arrives.
    let onboardingGate = Gate()
    /// Holds the answer of `list()` after the store was read: the listing returned is the one read when the call started,
    /// and a failure set meanwhile is thrown when the call is let go.
    let listGate = Gate()
    let sampleCalls = Mutex(0)

    init(editing: EditingFake) { self.editing = editing }

    func list() async throws(EditFailure) -> CVListing {
        listCalls.withLock { $0 += 1 }
        let stored: CVListing
        do { stored = try await editing.store.list() } catch { throw .unavailable }
        await listGate.pass()
        if let error = listError.withLock({ $0 }) { throw error }
        return CVListing(cvs: stored.cvs, issues: issues.withLock { $0 })
    }

    func onboarding() async throws(EditFailure) -> OnboardingState {
        if let error = onboardingError.withLock({ $0 }) { throw error }
        let listing = try await list()
        let state: OnboardingState = listing.cvs.isEmpty && listing.issues.isEmpty ? .firstRun : .returning
        await onboardingGate.pass()
        return state
    }

    func samples() async throws(EditFailure) -> [CV] {
        sampleCalls.withLock { $0 += 1 }
        if let error = samplesError.withLock({ $0 }) { throw error }
        return sampleList.withLock { $0 }
    }

    func startFromSample(_ sample: CV) -> CV { sample.duplicated(as: editing.ids.next(), title: sample.title) }
}

/// A look picker that offers fixed choices, each with what the view draws it with; the classic design has no preview.
struct LookOptionsFake: LookOptionsProviding {
    static let modernPreview = Data([0x89, 0x50, 0x4E, 0x47, 0x01])
    static let ocean = LookSample.colors(
        primary: LookColor(red: 0.1, green: 0.2, blue: 0.7), background: LookColor(red: 0.9, green: 0.9, blue: 1)
    )
    static let forest = LookSample.colors(
        primary: LookColor(red: 0.1, green: 0.4, blue: 0.2), background: LookColor(red: 1, green: 1, blue: 1)
    )

    func options() -> LookOptions {
        LookOptions(
            designs: [
                LookOption(id: "classic", nameCode: "design.classic"),
                LookOption(id: "modern", nameCode: "design.modern", sample: .page(png: Self.modernPreview))
            ],
            palettes: [
                LookOption(id: "ocean", nameCode: "palette.ocean", sample: Self.ocean),
                LookOption(id: "forest", nameCode: "palette.forest", sample: Self.forest)
            ],
            fontSchemes: [
                LookOption(id: "sans", nameCode: "fonts.sans", sample: .typeface(.system)),
                LookOption(id: "serif", nameCode: "fonts.serif", sample: .typeface(.serif))
            ],
            defaultDesign: "classic",
            ownLooks: [
                "classic": DesignOwnLook(palette: "ocean", fonts: "sans"),
                "modern": DesignOwnLook(palette: "forest", fonts: "serif")
            ]
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
    let editing: EditingFake
    let browsing: BrowsingFake
    let moment = Moment()
    let storedGate = Gate()

    init() { self.init(editing: EditingFake()) }

    /// A list over the store of `editing`, so that it reads what editors stored there.
    init(editing: EditingFake) {
        self.editing = editing
        browsing = BrowsingFake(editing: editing)
    }

    /// The view's word for a CV with no title, and how it numbers a title
    static let untitled = "Untitled CV"
    /// The editor bar's own words, shorter than the list's.
    static let barUntitled = "Untitled"
    static let barNewCV = "New"

    func list() -> CVListViewModel {
        CVListViewModel(
            browsing: browsing, editing: editing, untitled: Self.untitled, barUntitled: Self.barUntitled, barNewCV: Self.barNewCV, numbered: { "\($0) (\($1))" },
            now: { [moment] in moment.date },
            editorsStored: { [storedGate] in await storedGate.pass() }
        )
    }

    func firstRun(offersImport: Bool = true) -> FirstRunViewModel { FirstRunViewModel(browsing: browsing, editing: editing, offersImport: offersImport) }

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
