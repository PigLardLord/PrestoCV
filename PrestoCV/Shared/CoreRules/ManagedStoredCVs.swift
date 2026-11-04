import Foundation
import PrestoCVCore
import protocol PrestoCVApplication.StoredCVs
import struct PrestoCVApplication.LookChange

/// The app's stored CVs, as `ChangeStoredCV` of PrestoCVApplication reads and writes them: through the CV management of
/// PrestoCVCore.
struct ManagedStoredCVs: StoredCVs {
    let cvs: CVManagementUseCaseProtocol

    func load(_ id: UUID) async throws -> CVModel? {
        try await cvs.getCV(by: id)
    }

    func update(_ cv: CVModel) async throws -> CVModel {
        try await cvs.updateCV(cv)
    }

    func renaming(_ cv: CVModel, to title: String) -> CVModel {
        var renamed = cv
        renamed.name = title
        return renamed
    }

    func settingDocumentLanguage(of cv: CVModel, to tag: String?) -> CVModel {
        var changed = cv
        changed.documentLanguage = tag
        return changed
    }

    func settingLook(of cv: CVModel, to change: LookChange) -> CVModel {
        var changed = cv
        changed.look = CVLook.applying(change, to: cv.look)
        return changed
    }
}
