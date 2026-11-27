import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// The system's picker of files, for one PDF. It hands over the file picked unread, or tells that the system could
    /// not hand one over; Cancel hands over nothing.
    func pdfFileImporter(isPresented: Binding<Bool>, onPick: @escaping (URL) -> Void,
                         onFailure: @escaping () -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { onPick(url) }
            case .failure:
                onFailure()
            }
        }
    }
}
