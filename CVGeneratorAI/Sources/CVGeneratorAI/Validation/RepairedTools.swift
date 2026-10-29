import Foundation

// MARK: The tools a request for more tools writes

extension CVDataSanitizer {
    /// The tools a request for more tools wrote (`writeMoreSkills`) that name a tool: a general kind of the work, a kind of tool
    /// with a purpose and its object alone ("sistema di tracciamento dati", "système de suivi des progrès", "máquina de escaneo de
    /// registros"; #354, round 15), goes unless the description writes it. Only these answers are checked so: the first answers'
    /// kinds with a word of their trade stay ("software di rilievo").
    func repairedTools(_ tools: [String], against description: String) -> [String] {
        let language = DescriptionText(description, languageOfText: languageOfText).explainer.language?.rawValue
        let text = DescriptionText.normalized(description)
        return tools.filter { tool in
            !Self.namesAGeneralKind(tool, language: language)
                || !DescriptionText.spans(of: DescriptionText.normalized(tool), in: text).isEmpty
        }
    }

    /// Whether `item` is a general kind of the work: its head noun (the last word in English and German, the first in the other
    /// languages) is a kind of tool or of store (`toolKinds`, `storeKinds`), and its other words, past the link words, are a
    /// purpose (`purposeWords`) and its generic objects or modifiers (`purposeObjects`) only. A name, an acronym or a number names
    /// a tool ("Sistema di Interscambio"), and so does a word of a trade ("logiciel de gestion de classe", "software di contabilità").
    static func namesAGeneralKind(_ item: String, language: String?) -> Bool {
        let words = item.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let named = words.enumerated().contains { index, word in
            word.count > 1 && word == word.uppercased() && word.contains(where: \.isLetter)
                || word.dropFirst().contains(where: \.isUppercase)
                || index > 0 && word.first?.isUppercase == true && language != "de"
                || word.contains(where: \.isNumber)
        }
        let content = words.map { DescriptionText.normalized($0) }.filter { !skillLinkWords.contains($0) }
        guard !named, content.count > 1,
              let head = ["en", "de"].contains(language ?? "") ? content.last : content.first,
              toolKinds.contains(head) || storeKinds.contains(head) else { return false }
        let others = ["en", "de"].contains(language ?? "") ? content.dropLast() : content.dropFirst()
        return others.contains(where: purposeWords.contains)
            && others.allSatisfy { purposeWords.contains($0) || purposeObjects.contains($0) }
    }

    /// The nouns of a store or a device of no trade, without accents.
    private static let storeKinds: Set<String> = [
        "archivio", "archive", "archives", "archivo", "archivos", "arquivo", "arquivos", "archiv", "dispositivo", "dispositivi",
        "dispositivos", "dispositif", "dispositifs", "device", "devices",
    ]

    /// The purposes of a general kind, without accents: to manage, to track, to scan, to archive.
    private static let purposeWords: Set<String> = [
        "gestion", "gestione", "gestao", "management", "verwaltung", "suivi", "tracking", "tracciamento", "seguimiento",
        "rastreamento", "escaneo", "scansione", "scanning", "numerisation", "digitalizacion", "digitalizacao", "archiviazione",
        "archivage", "archiving",
    ]

    /// The objects and modifiers of a purpose that name no trade, without accents.
    private static let purposeObjects: Set<String> = [
        "documents", "document", "documenti", "documento", "documentos", "data", "dati", "datos", "donnees", "dados", "daten",
        "progress", "progres", "progressi", "progreso", "progresso", "records", "record", "registro", "registros", "registri",
        "registres",
        "files", "file", "archivos", "fichiers", "informazioni", "information", "informacion", "informacoes", "informations",
        "digitale", "digital", "numerique", "elettronico", "elettronica", "electronic", "electronico", "electronique",
        "automatico", "automated", "automatique", "online",
    ]
}
