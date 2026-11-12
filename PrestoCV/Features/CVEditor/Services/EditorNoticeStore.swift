import Foundation
import os

private let noticeLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "editor")

/// Where the notice of an imported CV is kept once the CV is stored, until the person dismisses it (ADR 0027). It lists the
/// values to check and the person's own text that fits no field, which nothing else keeps, so the person can come back to
/// it after leaving the editor.
protocol EditorNoticeStore: Sendable {
    /// The notice kept for the CV, or nil when none is kept.
    func notice(ofCVWithId id: UUID) async -> EditorNotice?
    /// Keeps `notice` for the CV, in place of the one kept before.
    func keep(_ notice: EditorNotice, forCVWithId id: UUID) async
    /// Forgets the notice of the CV, if one is kept.
    func forget(cvWithId id: UUID) async
}

/// Keeps the notices in one small JSON file in Application Support, protected as the CVs are. A missing file holds no
/// notice; a file that cannot be read or written is logged, and the notices it held are lost, never the CVs.
actor FileEditorNoticeStore: EditorNoticeStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func notice(ofCVWithId id: UUID) -> EditorNotice? {
        notices()[id.uuidString]
    }

    func keep(_ notice: EditorNotice, forCVWithId id: UUID) {
        var notices = notices()
        notices[id.uuidString] = notice
        write(notices)
    }

    func forget(cvWithId id: UUID) {
        var notices = notices()
        guard notices.removeValue(forKey: id.uuidString) != nil else { return }
        write(notices)
    }

    // MARK: The file

    private func notices() -> [String: EditorNotice] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return [:]
        } catch {
            noticeLogger.error("The kept import notices could not be read: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: EditorNotice].self, from: data)
        } catch {
            noticeLogger.error("The kept import notices are damaged: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    private func write(_ notices: [String: EditorNotice]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            let data = try JSONEncoder().encode(notices)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            noticeLogger.error("The import notices could not be kept: \(error.localizedDescription, privacy: .private)")
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
}
