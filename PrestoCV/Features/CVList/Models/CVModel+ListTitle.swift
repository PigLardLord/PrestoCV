import Foundation
import PrestoCVCore

extension CVModel {
    /// What the list calls this CV: its name, or "Untitled CV" while it has none.
    var listTitle: String {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName ? name : "cv.untitled".localized
    }
}
