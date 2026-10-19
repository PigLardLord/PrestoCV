/// What the editor says beside a field of the person's details: how its text reads, whether the field must be filled
/// in, and the line under it.
struct FieldStatus: Equatable {
    /// How the text reads against the rule of the field
    enum Validity: Equatable {
        /// There is nothing to say: the field is empty, or its rule does not judge it
        case none
        case valid
        /// The text cannot be what the field asks for, and the line under the field says so
        case invalid
        /// The text is unusual, and it is kept as it is
        case warning
    }

    /// The line under the field
    enum Note: Equatable {
        /// The field must be filled in
        case required
        /// The e-mail address is not one
        case invalidEmail
        /// How to write a phone number
        case phoneHelp
        /// The phone number has no digit to call
        case phoneWithoutDigits
        /// How to write a web address
        case webAddressHelp
    }

    let validity: Validity
    let isRequired: Bool
    let note: Note
}
