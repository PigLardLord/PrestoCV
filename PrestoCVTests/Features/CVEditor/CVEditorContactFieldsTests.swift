import Testing
@testable import PrestoCV
@testable import PrestoCVCore

/// What the editor says beside the e-mail address, the phone number and the portfolio of the person.
@MainActor
@Suite("CVEditorViewModel Tests - the e-mail, phone and web address fields")
struct CVEditorContactFieldsTests {

    private func editor(_ personalInfo: PersonalInfo) -> CVEditorViewModel {
        CVEditorViewModel(cvId: nil, initialCV: CVModel(personalInfo: personalInfo), cvManagementUseCase: MockCVManagementUseCase())
    }

    /// An editor whose contact fields the person has just left
    private func left(_ personalInfo: PersonalInfo) -> CVEditorViewModel {
        let viewModel = editor(personalInfo)
        [ContactField.email, .phone, .portfolio].forEach(viewModel.fieldWasLeft)
        return viewModel
    }

    // MARK: - E-mail address

    @Test("The name is the required field: a PDF is made only with it")
    func nameIsRequired() {
        #expect(editor(PersonalInfo()).nameStatus == FieldStatus(validity: .none, isRequired: true, note: .required))
    }

    @Test("The e-mail field is optional, and valid once it holds an address", arguments: [
        ("", FieldStatus.Validity.none),
        ("ada@example.com", .valid),
    ])
    func emailIsOptional(email: String, validity: FieldStatus.Validity) {
        #expect(left(PersonalInfo(email: email)).emailStatus == FieldStatus(validity: validity, isRequired: false, note: nil))
    }

    @Test("An address that is not one is marked invalid, and the line under it says so", arguments: ["ada.example.com", "clara.weiss@", "name@"])
    func invalidEmailIsMarked(email: String) {
        #expect(left(PersonalInfo(email: email)).emailStatus == FieldStatus(validity: .invalid, isRequired: false, note: .invalidEmail))
    }

    @Test("A field is checked when the person leaves it, not at every key")
    func fieldIsCheckedWhenLeft() {
        let viewModel = editor(PersonalInfo())

        viewModel.cv.personalInfo.email = "clara.weiss@"
        #expect(viewModel.emailStatus.validity == .none, "Still typing: nothing is said yet")

        viewModel.fieldWasLeft(.email)
        #expect(viewModel.emailStatus.validity == .invalid)

        viewModel.cv.personalInfo.email = "clara.weiss@beispiel.de"
        #expect(viewModel.emailStatus.validity == .invalid, "Typing again changes nothing until the field is left")

        viewModel.fieldWasLeft(.email)
        #expect(viewModel.emailStatus.validity == .valid)
    }

    @Test("Leaving one field checks that field only")
    func leavingChecksOneField() {
        let viewModel = editor(PersonalInfo(email: "ada", phone: "call me", portfolio: "ada.dev"))

        viewModel.fieldWasLeft(.phone)

        #expect(viewModel.phoneStatus.validity == .warning)
        #expect(viewModel.emailStatus.validity == .none)
        #expect(viewModel.portfolioStatus.validity == .none)
    }

    // MARK: - Phone number

    @Test("A phone with digits, or none, gets the help of the field", arguments: ["", "+39 06 1234567"])
    func phoneGetsItsHelp(phone: String) {
        #expect(left(PersonalInfo(phone: phone)).phoneStatus == FieldStatus(validity: .none, isRequired: false, note: .phoneHelp))
    }

    @Test("A phone without a digit gets a warning, which does not stop the save")
    func phoneWithoutDigitsWarns() async {
        let viewModel = left(PersonalInfo(name: "Ada Lovelace", phone: "call me"))

        #expect(viewModel.phoneStatus == FieldStatus(validity: .warning, isRequired: false, note: .phoneWithoutDigits))
        #expect(await viewModel.saveCV())
    }

    // MARK: - Web address

    @Test("The portfolio is valid with http or https and a host, doubtful without, and unmarked when empty", arguments: [
        ("", FieldStatus.Validity.none),
        ("https://ada.dev", .valid),
        ("ada.dev", .warning),
        ("https://", .warning),
    ])
    func portfolioIsChecked(portfolio: String, validity: FieldStatus.Validity) {
        #expect(left(PersonalInfo(portfolio: portfolio)).portfolioStatus == FieldStatus(validity: validity, isRequired: false, note: .webAddressHelp))
    }

    // MARK: - What the field shows

    @Test("An invalid field shows its line as an error, any other as help, in the language of the app")
    func fieldShowsItsLine() {
        let invalid = FieldStatus(validity: .invalid, isRequired: true, note: .invalidEmail).fieldState
        let required = FieldStatus(validity: .valid, isRequired: true, note: .required).fieldState
        let noDigits = FieldStatus(validity: .warning, isRequired: false, note: .phoneWithoutDigits).fieldState

        #expect(invalid == FieldState(validation: .invalid, isRequired: true, errorMessage: "field.email.error_invalid".localized))
        #expect(required == FieldState(validation: .valid, isRequired: true, helpText: "field.help.required".localized))
        #expect(noDigits == FieldState(validation: .warning, isRequired: false, helpText: "field.phone.no_digits".localized))
    }

    @Test("Every line under a field has a text in the catalog", arguments: [
        FieldStatus.Note.required, .invalidEmail, .phoneHelp, .phoneWithoutDigits, .webAddressHelp,
    ])
    func everyLineIsTranslated(note: FieldStatus.Note) {
        let state = FieldStatus(validity: .none, isRequired: false, note: note).fieldState

        let text = state.helpText ?? ""
        #expect(!text.isEmpty)
        #expect(!text.hasPrefix("field."), "The key \(text) is shown instead of its text")
    }
}
