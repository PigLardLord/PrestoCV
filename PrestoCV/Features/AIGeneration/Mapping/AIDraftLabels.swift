import Foundation
import PrestoCVCore

/// The localised words the mapper writes into a CV.
///
/// They are injected, not looked up, so the mapper stays pure: tests pass their own words, and the
/// app builds these from the string catalog in one place.
struct AIDraftLabels {
    /// End of a current job's period in a language a CV is printed in, e.g. "Present" in English
    let present: (DocumentLanguage) -> String
    /// End of a current job's period in the language the app is shown in, for a CV whose language the mapper cannot tell:
    /// such a CV follows the app's language
    let presentInAppLanguage: String
}

extension AIDraftLabels {
    /// The words as the app's string catalog writes them: in each language a CV is printed in, whatever language the app
    /// is shown in, and in the app's own language (#363)
    init(catalog bundle: Bundle) {
        let presentKey = "template.present"
        self.init(
            present: { $0.localizedString(forKey: presentKey, in: bundle) },
            presentInAppLanguage: bundle.localizedString(forKey: presentKey, value: nil, table: nil)
        )
    }
}
