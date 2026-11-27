import Foundation
import PrestoCVWorkflowPorts

/// The end of the port's receive of a file handed on to another part of the screen. The part that handed it lets its
/// own hold go only after it, so that the file is always held while it changes hands: the adapter removes a copy with
/// its last hold (`ImportFileReading`).
public struct FileReceipt: Sendable {
    fileprivate let receiving: Task<ReceivedFile, Never>

    /// Ends once the port received the file.
    func received() async {
        _ = await receiving.value
    }
}

/// A file a part of the screen holds through the port: its URL at once, the port's received file once the receive ended.
struct FileHold: Sendable {
    let url: URL
    let receipt: FileReceipt
}

/// Calls the file port of one part of the screen off the main actor (R19), one call after the other in the order the
/// part asked for them. A release so never comes before a receive asked earlier, and a file let go and taken again is
/// never removed in between. Each call runs in a task of its own that nothing cancels, so each received file is released
/// exactly once, also when the part that held it is gone.
@MainActor
final class FileHolder {
    private let files: any ImportFileReading
    /// The last call asked: the next one starts once it ended.
    private var last: Task<Void, Never>?

    init(files: any ImportFileReading) {
        self.files = files
    }

    /// Receives the file at `url`, after the calls asked before.
    func hold(_ url: URL) -> FileHold {
        let previous = last, files = files
        let receiving = Task {
            await previous?.value
            return await files.receive(url)
        }
        last = Task { _ = await receiving.value }
        return FileHold(url: url, receipt: FileReceipt(receiving: receiving))
    }

    /// Releases `hold`, after the calls asked before, and, for a file handed on, once `successor` received it there.
    func letGo(_ hold: FileHold, after successor: FileReceipt? = nil) {
        let previous = last, files = files
        last = Task {
            await previous?.value
            await successor?.received()
            await files.release(hold.receipt.receiving.value)
        }
    }

    /// The bytes of the PDF of `hold`, once it was received. A cancelled task stays cancelled (`readPDF(of:)`).
    func read(_ hold: FileHold) async throws -> Data {
        try await files.readPDF(of: hold.receipt.receiving.value)
    }

    /// Ends once every call asked so far ended.
    func settled() async {
        await last?.value
    }
}
