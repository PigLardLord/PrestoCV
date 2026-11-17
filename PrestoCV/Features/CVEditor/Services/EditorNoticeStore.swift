import Foundation
import os

private let noticeLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "editor")

/// Where the notice of an imported CV is kept once the CV is stored, until the person dismisses it (ADR 0027). It lists the
/// values to check and the person's own text that fits no field, which nothing else keeps, so the person can come back to
/// it after leaving the editor.
protocol EditorNoticeStore: Sendable {
    /// The notice kept for the CV, or nil when none is kept.
    func notice(ofCVWithId id: UUID) async -> EditorNotice?
    /// Keeps `notice` for the CV, in place of the one kept before. Throws when the notice could not be written, so that the
    /// editor shows the save as failed and writes it again with the next save.
    func keep(_ notice: EditorNotice, forCVWithId id: UUID) async throws
    /// Forgets the notice of the CV, if one is kept.
    func forget(cvWithId id: UUID) async
    /// The CVs that have a notice kept, so that the notice of a CV that is gone can be forgotten.
    func keptCVIds() async -> [UUID]
}

/// Keeps each CV's notice in a small JSON file of its own, named after the CV's id, in a folder of Application Support,
/// protected as the CVs are. Forgetting a notice removes its file, so the person's text leaves the device with it; a damaged
/// file affects one notice only, and is removed when it is read. A notice that cannot be written is logged and reported to
/// the caller; a file that cannot be read or removed is logged, and the notice is lost, never the CV.
actor FileEditorNoticeStore: EditorNoticeStore {
    private let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func notice(ofCVWithId id: UUID) -> EditorNotice? {
        let file = fileURL(of: id)
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            noticeLogger.error("A kept import notice could not be read: \(error.localizedDescription, privacy: .private)")
            return nil
        }
        do {
            return try JSONDecoder().decode(EditorNotice.self, from: data)
        } catch {
            noticeLogger.error("A kept import notice is damaged, and is removed: \(error.localizedDescription, privacy: .private)")
            remove(file)
            return nil
        }
    }

    func keep(_ notice: EditorNotice, forCVWithId id: UUID) throws {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            let data = try JSONEncoder().encode(notice)
            try data.write(to: fileURL(of: id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            noticeLogger.error("An import notice could not be kept: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    func forget(cvWithId id: UUID) {
        remove(fileURL(of: id))
    }

    func keptCVIds() -> [UUID] {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        } catch {
            noticeLogger.error("The kept import notices could not be listed: \(error.localizedDescription, privacy: .private)")
            return []
        }
        // Only the notices: a file another write left behind, or any other file, is not one
        return names.compactMap { name in
            guard name.hasSuffix(Self.fileExtension) else { return nil }
            return UUID(uuidString: String(name.dropLast(Self.fileExtension.count)))
        }
    }

    // MARK: The files

    private static let fileExtension = ".json"

    private func fileURL(of id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString + Self.fileExtension)
    }

    private func remove(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return
        } catch {
            noticeLogger.error("An import notice could not be removed: \(error.localizedDescription, privacy: .private)")
        }
    }
}

/// Keeps the notices in memory, for the previews and the tests.
actor InMemoryEditorNoticeStore: EditorNoticeStore {
    private var notices: [UUID: EditorNotice]

    init(notices: [UUID: EditorNotice] = [:]) {
        self.notices = notices
    }

    func notice(ofCVWithId id: UUID) -> EditorNotice? {
        notices[id]
    }

    func keep(_ notice: EditorNotice, forCVWithId id: UUID) {
        notices[id] = notice
    }

    func forget(cvWithId id: UUID) {
        notices[id] = nil
    }

    func keptCVIds() -> [UUID] {
        Array(notices.keys)
    }
}
