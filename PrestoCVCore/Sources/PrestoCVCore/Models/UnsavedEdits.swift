import CryptoKit
import Foundation

/// The edits of a CV that the editor of an earlier version had not saved, kept on the device so that they outlived the
/// app when iOS ended it. The editor saves by itself now: `LeftoverEditsImport` stores what is left of them.
public struct UnsavedEdits: Codable, Sendable, Equatable, Identifiable, StorageIdentified {
    /// The editing that kept them: one editor, from the moment it opens to the moment it is left.
    public let id: UUID
    /// The CV as the editor showed it. Its id is the one the CV is stored under, or will be: a new CV gets it when its
    /// editing begins, so that its first save, and any save of these edits after a restore, stores that one CV.
    public let cv: CVModel
    /// The stored CV the edits were made on: the CV as the editor last read or saved it, or what a save that has
    /// started is storing. Nil when nothing was stored yet.
    public let base: CVModel?
    /// When they were kept, in whole seconds.
    public let keptAt: Date

    public init(id: UUID, cv: CVModel, base: CVModel?, keptAt: Date) {
        self.id = id
        self.cv = cv
        self.base = base
        self.keptAt = keptAt
    }

    /// The file name the edits are kept under, so that the storage can tell a file kept under another one.
    public var storageIdentifier: String {
        UnsavedEditsRepository.identifier(for: id)
    }
}

// MARK: - Restoring

extension UnsavedEdits {
    /// How the edits go into the CVs, given what is stored under their CV's id, and under the id of their copy, now.
    public enum RestorePlan: Equatable, Sendable {
        /// The edits were restored as a copy before, and the copy was stored: it holds them, or what the person made of
        /// them since. Nothing is stored, so nothing saved to the copy is replaced. Each write of edits restored as a
        /// copy named the copy, so edits that still name the CV they were made on are the ones the copy was made of,
        /// kept on because they could not be removed.
        case restoredAsCopy
        /// The stored CV already holds the edits, as when the app was ended after a save and before its edits were
        /// removed. There is nothing to store.
        case alreadySaved
        /// The edits replace the stored CV they were made on.
        case update
        /// Nothing is stored under the CV's id: the edits are stored under it.
        case create
        /// The stored CV changed after the edits were made on it, as when another window saved it. Storing the edits
        /// over it would replace the newer content without a word, so they are stored as a separate copy instead.
        case copy
    }

    /// The id the edits are stored under when they are stored as a copy. It is worked out from the edits, so it is the
    /// same every time: edits stored again, after they could not be removed, find the copy they were made into instead
    /// of making another.
    public var copyID: UUID {
        UUID(namedBy: "\(id.uuidString)/\(cv.id.uuidString)", in: Self.copyNamespace)
    }

    /// The namespace of the ids of copies, which no other id is made in.
    private static let copyNamespace = UUID(uuid: (
        0x5C, 0x1F, 0x3A, 0x7E, 0x2B, 0x84, 0x4D, 0x60, 0x9E, 0x15, 0xC8, 0x0A, 0x6F, 0x42, 0xD3, 0x91
    ))

    /// - Parameters:
    ///   - stored: The CV stored under the id of the edits' CV now, if there is one.
    ///   - storedCopy: The CV stored under `copyID` now, if there is one.
    public func restorePlan(over stored: CVModel?, copy storedCopy: CVModel?) -> RestorePlan {
        if storedCopy != nil {
            return .restoredAsCopy
        }
        guard let stored else {
            return .create
        }
        if stored == cv {
            return .alreadySaved
        }
        return stored == base ? .update : .copy
    }
}

// MARK: - Name-Based Identifiers

extension UUID {
    /// A name-based identifier (RFC 9562, version 5): the same name in the same namespace always gives the same one.
    init(namedBy name: String, in namespace: UUID) {
        var namespaceBytes = namespace.uuid
        var data = withUnsafeBytes(of: &namespaceBytes) { Data($0) }
        data.append(Data(name.utf8))
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self.init(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
