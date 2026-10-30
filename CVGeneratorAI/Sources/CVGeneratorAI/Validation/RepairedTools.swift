import Foundation

// MARK: The tools a request for more tools writes

extension CVDataSanitizer {
    /// The tools a request for more tools wrote (`writeMoreSkills`) that name a tool: a general kind of the work, a kind of tool
    /// with a purpose and its object alone ("sistema di tracciamento dati", "système de suivi des progrès", "máquina de escaneo de
    /// registros"; #354, round 15), or a German word that ends in a kind of tool ("Sicherungssystem"; #354, round 16), goes unless
    /// the description writes it. Only these answers are checked so: the first answers' kinds with a word of their trade stay
    /// ("software di rilievo").
    func repairedTools(_ tools: [String], against description: String) -> [String] {
        let language = language(of: description)
        let text = DescriptionText.normalized(description)
        return tools.filter { tool in
            !(Self.namesAGeneralKind(tool, language: language) || Self.isAKindCompound(tool, language: language))
                || !DescriptionText.spans(of: DescriptionText.normalized(tool), in: text).isEmpty
        }
    }

    /// The language code of `description` ("de"), as the checks read it.
    func language(of description: String) -> String? {
        DescriptionText(description, languageOfText: languageOfText).explainer.language?.rawValue
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

    /// Whether a tool names a kind of tool (`namesAKindOfTool`: "truck loading equipment", "software di controllo") or, in German,
    /// is one word that ends in a kind of tool with a word before it ("Montagesystem", "Messgeräte"): a past title's answer adds a
    /// tool before such a kind (`SectionDraft.mergedTools`; #354, round 15).
    static func endsInAKindOfTool(_ item: String, language: String?) -> Bool {
        namesAKindOfTool(item, language: language) || isAKindCompound(item, language: language)
    }

    /// Whether `item` is, in German, one word that ends in a kind of tool with a word before it ("Montagesystem", "Messgeräte").
    static func isAKindCompound(_ item: String, language: String?) -> Bool {
        let words = item.split { !$0.isLetter && !$0.isNumber }
        guard language == "de", words.count == 1, let word = words.first, word.dropFirst().allSatisfy(\.isLowercase) else { return false }
        let folded = DescriptionText.normalized(String(word))
        return toolKinds.contains { folded.count > $0.count + 2 && folded.hasSuffix($0) }
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
