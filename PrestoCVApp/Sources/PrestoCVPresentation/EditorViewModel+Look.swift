internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

extension EditorViewModel {

    /// Sets the language the document is written in, by its tag; nil leaves it automatic. A tag that names no language
    /// changes nothing. The writer of the open CV stores it, or keeps it for the first write; the text is not written.
    public func setDocumentLanguage(_ tag: String?) async {
        let language = tag.flatMap(DocumentLanguage.init)
        guard tag == nil || language != nil else { return }
        await restyle { writer, content in try await writer.setDocumentLanguage(language, of: content) }
    }

    /// Changes the `parts` of the look to the ones of `shown`. A look whose ids no design may have changes nothing. The
    /// writer of the open CV stores it, or keeps it for the first write; the text is not written.
    public func changeLook(to shown: EditorLook, parts: Set<LookPart>) async {
        guard let change = LookChange(shown: shown, parts: parts) else { return }
        await restyle { writer, content in try await writer.changeLook(change, of: content) }
    }

    /// Runs `change` on the writer of the open CV, after any replacement that runs, and holds the CV it gives back. The CV
    /// passed is the one the form stands on: the writer takes the look and the language it keeps, never this one's.
    private func restyle(_ change: @escaping @MainActor (any CVAutosaveWriting, CV) async throws -> CV) async {
        await replace { [self] in
            guard let writer, let base else { return }
            do {
                restyled = try await change(writer, form.applied(to: base))
                changeFailure = nil
            } catch {
                changeFailed(error)
            }
        }
    }

    /// A change the writer refused shows its failure; one cancelled before it reached the store changed nothing.
    private func changeFailed(_ error: any Error) {
        guard !(error is CancellationError) else { return }
        changeFailure = (error as? EditFailure).map { SaveStatus($0) } ?? .failed
    }
}
