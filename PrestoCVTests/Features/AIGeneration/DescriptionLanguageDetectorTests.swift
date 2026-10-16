import Testing
@testable import PrestoCV

@Suite("DescriptionLanguageDetector Tests")
struct DescriptionLanguageDetectorTests {

    @Test("Each supported language is recognised from a description", arguments: [
        ("en", "I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I have taught at the Don Milani school, where I trained 3 new teachers. Before that, from 2012 to 2016, I worked as an assistant in a nursery. I studied Education Sciences at the University of Bologna and graduated in 2012. I speak Italian (native) and English (B2). In my free time I like chess and hiking."),
        ("it", "Sono Maria Rossi, insegnante di scuola primaria a Bologna. Dal 2016 insegno alla scuola Don Milani, dove ho formato 3 nuovi insegnanti. Prima, dal 2012 al 2016, ho lavorato come assistente in un asilo nido. Ho studiato Scienze della Formazione all'Università di Bologna e mi sono laureata nel 2012. Parlo italiano (madrelingua) e inglese (B2). Nel tempo libero mi piacciono gli scacchi e le escursioni."),
        ("de", "Ich bin Maria Rossi, Grundschullehrerin aus Bologna. Seit 2016 unterrichte ich an der Schule Don Milani, wo ich 3 neue Lehrkräfte eingearbeitet habe. Davor habe ich von 2012 bis 2016 als Betreuerin in einer Kinderkrippe gearbeitet. Ich habe Erziehungswissenschaften an der Universität Bologna studiert und 2012 meinen Abschluss gemacht. Ich spreche Italienisch (Muttersprache) und Englisch (B2). In meiner Freizeit mag ich Schach und Wandern."),
        ("es", "Soy Maria Rossi, maestra de primaria en Bolonia. Desde 2016 enseño en la escuela Don Milani, donde formé a 3 nuevos maestros. Antes, de 2012 a 2016, trabajé como auxiliar en una guardería. Estudié Ciencias de la Educación en la Universidad de Bolonia y me gradué en 2012. Hablo italiano (nativo) e inglés (B2). En mi tiempo libre me gustan el ajedrez y el senderismo."),
        ("fr", "Je suis Maria Rossi, institutrice dans une école primaire de Bologne. Depuis 2016, j'enseigne à l'école Don Milani, où j'ai formé 3 nouveaux enseignants. Avant, de 2012 à 2016, j'ai travaillé comme assistante dans une crèche. J'ai étudié les sciences de l'éducation à l'université de Bologne et j'ai obtenu mon diplôme en 2012. Je parle italien (langue maternelle) et anglais (B2). Pendant mon temps libre, j'aime les échecs et la randonnée."),
        ("pt", "Sou Maria Rossi, professora do ensino fundamental em Bolonha. Desde 2016 leciono na escola Don Milani, onde formei 3 novos professores. Antes, de 2012 a 2016, trabalhei como auxiliar em uma creche. Estudei Ciências da Educação na Universidade de Bolonha e me formei em 2012. Falo italiano (nativo) e inglês (B2). No meu tempo livre, gosto de xadrez e de caminhadas."),
    ])
    func recognisesTheSupportedLanguages(tag: String, text: String) {
        #expect(DescriptionLanguageDetector.languageTag(of: text) == tag)
    }

    @Test("Another language is reported as it is, for the mapper to ignore")
    func recognisesAnUnsupportedLanguage() {
        let text = "私は東京で十年間、看護師として病院で働いてきました。大学で看護学を学び、二〇一二年に卒業しました。"

        #expect(DescriptionLanguageDetector.languageTag(of: text) == "ja")
    }

    @Test("Text with no words gives no language", arguments: ["", "   ", "12345 67890"])
    func noWordsNoLanguage(text: String) {
        #expect(DescriptionLanguageDetector.languageTag(of: text) == nil)
    }
}
