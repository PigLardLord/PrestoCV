import Foundation
import PrestoCVWorkflowPorts

/// One share of the sheet's PDF: the file written for it, from the moment it is written until the system's share sheet
/// is done with it. The platform's share sheet reads `url` and calls `end` when it closes. The file is removed then, or
/// when the share goes, whichever comes first; it outlives a refresh and the end of the export sheet, so that a share
/// sheet still open keeps reading it.
@MainActor
public final class PDFShare: Identifiable {
    /// The export that made the PDF.
    let export: ExportID
    /// The file the share sheet reads.
    public let url: URL
    /// The name of the file, as the share sheet shows it.
    public let fileName: String
    private let file: SharedFile
    private let files: any ExportFileSharing
    /// The sheet the share was opened from; it is told how the share ended while it is there.
    private weak var sheet: ExportSheetViewModel?
    private var ended = false

    init(file: SharedFile, fileName: String, export: ExportID, files: any ExportFileSharing,
         sheet: ExportSheetViewModel) {
        self.export = export
        self.url = file.url
        self.fileName = fileName
        self.file = file
        self.files = files
        self.sheet = sheet
    }

    /// The share sheet closed: the file goes, and the sheet confirms a share that went through. Only the first call
    /// counts.
    public func end(_ result: ShareResult) {
        guard !ended else { return }
        ended = true
        files.remove(file)
        sheet?.shareEnded(self, with: result)
    }

    /// A share that goes without an end, as when its share sheet was never shown, still removes its file.
    isolated deinit {
        guard !ended else { return }
        files.remove(file)
    }
}
