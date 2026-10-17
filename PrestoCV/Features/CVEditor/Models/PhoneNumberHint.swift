import PrestoCVCore

extension PersonalInfo {
    /// True when the phone field holds text without a single digit, such as "abc", from which no number can be
    /// called. The editor says so beside the field and still lets the CV be saved: how a number is written is up
    /// to the person.
    var phoneLacksDigits: Bool {
        let text = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && !text.contains(where: \.isWholeNumber)
    }
}
