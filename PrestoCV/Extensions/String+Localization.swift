import Foundation
import SwiftUI

extension String {
    /// Returns the localized version of the string using the String Catalog system
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }
    
    /// Returns a localized string with format arguments
    func localizedWithArgs(_ arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
    
    /// Helper function for SwiftUI LocalizedStringKey usage (for Text views, buttons, etc.)
    /// Only used in specific cases where explicit LocalizedStringKey is needed
    var asLoclizedKey: LocalizedStringKey {
        LocalizedStringKey(self)
    }
}
