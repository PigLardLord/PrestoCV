/// A share sheet that is open, or about to open, on the PDF of the export sheet. From the moment the PDF is handed to it
/// until the share sheet closes (`end()`), the file stays, whatever the export sheet does in the meantime.
@MainActor
final class PDFShare {
    let pdf: ExportedPDF
    private let keeper: ExportFileKeeper
    private var isOpen = true

    init(pdf: ExportedPDF, keeper: ExportFileKeeper) {
        self.pdf = pdf
        self.keeper = keeper
        keeper.shareBegan(on: pdf.url)
    }

    /// The share sheet closed. A share that is dropped without being ended ends with the drop: whoever held it is gone,
    /// and so is the share sheet that read the file. Ending it again changes nothing.
    /// - Returns: The task that removes the file when the export sheet had already let it go, for a caller that wants to
    ///   wait for it
    @discardableResult
    func end() -> Task<Void, Never> {
        guard isOpen else { return Task {} }
        isOpen = false
        return keeper.shareEnded(on: pdf.url)
    }

    isolated deinit {
        end()
    }
}
