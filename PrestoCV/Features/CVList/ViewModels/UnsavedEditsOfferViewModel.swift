import Foundation
import PrestoCVCore
import os

private let offerLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "unsaved-edits")

/// Offers to restore the edits that an earlier run of the app kept and nobody saved or discarded, as when iOS ended
/// the app while a CV was being edited. One set of edits is offered at a time, the latest first. Edits that the stored
/// CV already holds, because the app was ended after their save and before they were removed, are removed instead.
@MainActor
final class UnsavedEditsOfferViewModel: ObservableObject {

    // MARK: - Published Properties
    /// The edits offered to restore; nil when there are none.
    @Published private(set) var offer: UnsavedEdits?
    /// The offered edits open as a separate copy: the stored CV was saved again after they were made on it, or they
    /// were restored as a copy before.
    @Published private(set) var restoresAsCopy = false
    /// The offer is on screen. It goes when the person answers it, before the answer is carried out.
    @Published var isShowingOffer = false
    /// The edits the person chose were restored or discarded in another window meanwhile: the person is told so.
    @Published var isShowingNoLongerAvailable = false

    // MARK: - Private Properties
    private let useCase: UnsavedEditsUseCaseProtocol?
    private let cvs: CVManagementUseCaseProtocol
    private let locale: Locale
    private let timeZone: TimeZone

    // MARK: - Initialization
    /// - Parameters:
    ///   - useCase: The unsaved edits of the app; nil when they cannot be kept on this device, and nothing is offered.
    ///   - locale: The language of the time in the offer: the language of the app, which the rest of the texts are in.
    ///   - timeZone: The time zone the time is told in.
    init(
        useCase: UnsavedEditsUseCaseProtocol?,
        cvs: CVManagementUseCaseProtocol,
        locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en"),
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.useCase = useCase
        self.cvs = cvs
        self.locale = locale
        self.timeZone = timeZone
    }

    // MARK: - Computed Properties

    /// What the offer says: which CV the edits change, when they were last kept, and whether they open as a copy.
    var message: String? {
        offer.map { edits in
            let format = restoresAsCopy ? "unsaved_edits.restore.message_copy" : "unsaved_edits.restore.message"
            return format.localizedWithArgs(title(of: edits), time(of: edits))
        }
    }

    // MARK: - Public Methods

    /// Looks for edits to offer. A failure to look leaves nothing offered: the edits stay where they are, for the next try.
    func checkForEditsToRestore() async {
        let next = await nextEditsToOffer()
        offer = next?.edits
        restoresAsCopy = next?.plan.opensAsCopy ?? false
        isShowingOffer = offer != nil
    }

    /// The person restores the edits: this window claims them and hands them, with its claim, to its editor, which
    /// keeps them until it saves or discards them. Edits another window holds, or that changed meanwhile, are not handed
    /// over: the person is told so.
    func restore() async -> RestoredUnsavedEdits? {
        guard let taken = await claimOffer() else {
            return nil
        }
        return RestoredUnsavedEdits(edits: taken.edits, claim: taken.claim, useCase: useCase)
    }

    /// The person discards the edits: this window claims them and removes them, and the next edits left behind, if
    /// any, are offered. Edits another window holds are left to it: the person is told so. Edits that could not be
    /// removed are let go, so they are offered again.
    func discard() async {
        guard let taken = await claimOffer(), let useCase else {
            return
        }
        await discard(taken.edits, as: taken.claim, with: useCase)
        await useCase.release(taken.claim)
        await checkForEditsToRestore()
    }

    // MARK: - Private Methods

    /// Takes the offered edits for this window. The offer goes either way; when another window has taken them, or
    /// they are no longer what was offered, the person is told so.
    private func claimOffer() async -> (edits: UnsavedEdits, claim: UnsavedEditsClaim)? {
        guard let edits = offer, let useCase else { return nil }
        offer = nil
        isShowingOffer = false
        do {
            if let claim = try await useCase.claim(edits) {
                return (edits, claim)
            }
        } catch {
            offerLogger.error("Unsaved edits could not be claimed: \(error.localizedDescription, privacy: .public)")
        }
        isShowingNoLongerAvailable = true
        return nil
    }

    /// - Returns: Whether the edits are gone. A failure is logged.
    @discardableResult
    private func discard(_ edits: UnsavedEdits, as claim: UnsavedEditsClaim, with useCase: UnsavedEditsUseCaseProtocol) async -> Bool {
        do {
            try await useCase.discard(as: claim)
            return true
        } catch {
            offerLogger.error("Unsaved edits \(edits.id, privacy: .public) could not be discarded: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func nextEditsToOffer() async -> (edits: UnsavedEdits, plan: UnsavedEdits.RestorePlan)? {
        guard let useCase else { return nil }
        do {
            while let edits = try await useCase.editsToRestore() {
                let plan = edits.restorePlan(
                    over: try await cvs.getCV(by: edits.cv.id),
                    copy: try await cvs.getCV(by: edits.copyID)
                )
                guard plan == .alreadySaved else {
                    return (edits, plan)
                }
                // Saved before the app was ended: they go, by the one window that claims them. Edits that cannot be
                // removed now are left for the next launch
                if let claim = try await useCase.claim(edits) {
                    let removed = await discard(edits, as: claim, with: useCase)
                    await useCase.release(claim)
                    guard removed else { return nil }
                }
            }
            return nil
        } catch {
            offerLogger.error("Unsaved edits could not be checked: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The CV the edits change, as its editor calls it: by the title rule of PrestoCVDomain, or "New CV" for a CV that
    /// has no title and was never stored.
    private func title(of edits: UnsavedEdits) -> String {
        edits.cv.editorTitle(isStored: edits.base != nil)
    }

    /// When the edits were last kept, as "today at 11:10" or a date, in the middle of a sentence.
    private func time(of edits: UnsavedEdits) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        formatter.formattingContext = .middleOfSentence
        return formatter.string(from: edits.keptAt)
    }
}
