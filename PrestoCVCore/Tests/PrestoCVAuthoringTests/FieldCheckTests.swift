import Testing
import PrestoCVDomain

/// What the editor says of an e-mail address, a phone number and a web address, with what people write in the six
/// languages of the app and in their regions.
@Suite("Field checks")
struct FieldCheckTests {

    // MARK: - E-mail address

    @Test("An address people write reads as one", arguments: [
        "john.smith@example.com",          // en-US
        "j.smith@example.co.uk",           // en-GB
        "giulia.rossi@esempio.it",         // it-IT
        "anna.müller@beispiel.de",         // de-DE
        "josé.garcía@correo.es",           // es-ES
        "marie-claire.dupont@exemple.fr",  // fr-FR
        "joão.silva@exemplo.com.br",       // pt-BR
        "ana.sousa@exemplo.pt",            // pt-PT
        "lucia+cv@gmail.com",
        " ada@example.com\n",
    ])
    func plausibleEmail(text: String) {
        #expect(FieldCheck.email(text) == .plausible)
    }

    @Test("An address cut short, or with a part missing or doubled, is not one", arguments: [
        "clara.weiss@", "name@", "@beispiel.de", "clara.weiss@beispiel", "clara weiss@beispiel.de", "giulia.rossi@esempio..it",
        "marie.dupont@@exemple.fr", "joão.silva", "josé.garcía@correo.e", "ana.sousa@exemplo.pt.", "john.smith@example.com/cv",
    ])
    func implausibleEmail(text: String) {
        #expect(FieldCheck.email(text) == .implausible)
    }

    // MARK: - Phone number

    @Test("A phone with digits reads as one, however it is written", arguments: [
        "+1 (555) 010-0199",    // en-US
        "+44 20 7946 0958",     // en-GB
        "+39 06 1234 5678",     // it-IT
        "333 123 4567",         // it-IT, mobile
        "+49 (0)30 12345678",   // de-DE
        "+34 912 345 678",      // es-ES
        "06 12 34 56 78",       // fr-FR
        "+55 11 91234-5678",    // pt-BR
        "+351 912 345 678",     // pt-PT
        "tel. 0612 interno 4",
    ])
    func plausiblePhone(text: String) {
        #expect(FieldCheck.phoneNumber(text) == .plausible)
    }

    @Test("A phone without a single digit cannot be called", arguments: [
        "call me", "chiamami", "rufen Sie an", "llámame", "appelez-moi", "me ligue", " - ", "+",
    ])
    func implausiblePhone(text: String) {
        #expect(FieldCheck.phoneNumber(text) == .implausible)
    }

    // MARK: - Web address

    @Test("A web address with its scheme and host reads as one", arguments: [
        "https://www.linkedin.com/in/giulia-rossi", "https://www.xing.com/profile/Anna_Mueller", "http://portfolio.exemple.fr",
        "https://github.com/joaosilva", "HTTPS://ADA.DEV", "https://josegarcia.es/cv?lang=es",
    ])
    func plausibleWebAddress(text: String) {
        #expect(FieldCheck.webAddress(text) == .plausible)
    }

    @Test("A web address without its scheme or host, or with credentials, is doubtful", arguments: [
        "www.linkedin.com/in/giulia-rossi", "linkedin.com/in/anna", "https://", "http://", "ftp://exemplo.pt",
        "https://user:secret@example.com", "https://exa mple.com",
    ])
    func implausibleWebAddress(text: String) {
        #expect(FieldCheck.webAddress(text) == .implausible)
    }

    // MARK: - Nothing written

    @Test("A field with nothing written in it says nothing", arguments: ["", "   ", "\n\t"])
    func empty(text: String) {
        #expect(FieldCheck.email(text) == .empty)
        #expect(FieldCheck.phoneNumber(text) == .empty)
        #expect(FieldCheck.webAddress(text) == .empty)
    }
}
