import Foundation
import Testing
@testable import StoreListing

// MARK: - Captions

/// The composer puts the first caption of a locale on the first capture, the second on the second, and so on: a locale with
/// fewer captions than captures would leave the captions over the wrong screens, and one with more would have no capture for
/// them. So a locale needs exactly six captions, and the checker says so.
@Suite("The captions of the store listing")
struct StoreListingCaptionTests {
    private static func captions() throws -> [String] {
        try #require(StoreListingFixture.listing()[StoreListingFixture.locale]?.fields["Screenshot captions"]?.first).components(separatedBy: "\n")
    }

    @Test("The listing has six captions in every locale, and no error")
    func sixCaptionsEverywhere() throws {
        let listing = try StoreListingFixture.listing()

        #expect(StoreListingRules.check(listing, retired: try StoreListingFixture.retired()) == [])
        #expect(listing.locales.count >= 9)
        for locale in listing.locales {
            #expect(locale.fields["Screenshot captions"]?.first?.components(separatedBy: "\n").count == 6, "\(locale.code)")
        }
    }

    @Test("Five captions are refused")
    func fiveAreRefused() throws {
        let errors = try StoreListingFixture.captionErrors(Array(Self.captions().prefix(5)))

        #expect(errors.contains { $0.contains(StoreListingFixture.locale) && $0.contains("exactly 6") }, "\(errors)")
    }

    @Test("Seven captions are refused")
    func sevenAreRefused() throws {
        let errors = try StoreListingFixture.captionErrors(Self.captions() + ["One more. | A seventh caption, with no capture."])

        #expect(errors.contains { $0.contains(StoreListingFixture.locale) && $0.contains("exactly 6") }, "\(errors)")
    }

    @Test("An empty line is refused")
    func emptyLineIsRefused() throws {
        let errors = try StoreListingFixture.captionErrors(Array(Self.captions().prefix(5)) + [""])

        #expect(!errors.isEmpty)
    }

    @Test("Six captions are accepted")
    func sixAreAccepted() throws {
        #expect(try StoreListingFixture.captionErrors(Self.captions()) == [])
    }

    @Test("A caption is a title and a line below it, each within its limit")
    func captionShape() throws {
        var captions = try Self.captions()
        captions[0] = "No separator here"
        captions[1] = String(repeating: "T", count: 31) + " | Line"
        captions[2] = "Title | " + String(repeating: "L", count: 81)

        let errors = try StoreListingFixture.captionErrors(captions)

        #expect(errors.contains { $0.contains("caption 1: write it as 'Title | Line below'") }, "\(errors)")
        #expect(errors.contains { $0.contains("caption 2: title 31 characters (limit 30), line below 4 (limit 80)") }, "\(errors)")
        #expect(errors.contains { $0.contains("caption 3: title 5 characters (limit 30), line below 81 (limit 80)") }, "\(errors)")
    }
}

// MARK: - Limits

@Suite("The limits of the store listing")
struct StoreListingLimitTests {
    private static func errors(editing field: String, to text: String, in code: String = StoreListingFixture.locale) throws -> [String] {
        var listing = try StoreListingFixture.listing()
        var texts = try #require(listing[code])
        texts.fields[field] = [text]
        listing[code] = texts
        return StoreListingRules.check(listing, retired: try StoreListingFixture.retired())
    }

    @Test("A text over its limit is refused, and a text at it is accepted", arguments: [
        ("Name", 30), ("Subtitle", 30), ("Promotional text", 170), ("Description", 4000), ("What's New", 4000),
    ])
    func characterLimits(field: String, limit: Int) throws {
        let at = try Self.errors(editing: field, to: String(repeating: "x", count: limit))
        let over = try Self.errors(editing: field, to: String(repeating: "x", count: limit + 1))

        #expect(!at.contains { $0.contains("\(StoreListingFixture.locale) \(field): ") && $0.contains("characters, limit") }, "\(at)")
        #expect(over.contains("\(StoreListingFixture.locale) \(field): \(limit + 1) characters, limit \(limit)"), "\(over)")
    }

    @Test("A length is counted in Unicode scalars, not in bytes or grapheme clusters")
    func scalarsAreCounted() throws {
        // 30 letters with an accent (one scalar each, two bytes each) fit a name of 30; the same letters decomposed do not.
        let composed = String(repeating: "\u{E9}", count: 30)
        let decomposed = String(repeating: "e\u{301}", count: 30)

        #expect(!(try Self.errors(editing: "Name", to: composed)).contains { $0.contains("Name:") && $0.contains("characters, limit") })
        #expect(try Self.errors(editing: "Name", to: decomposed).contains("\(StoreListingFixture.locale) Name: not in NFC"))
    }

    @Test("The keywords are counted in UTF-8 bytes")
    func keywordBytes() throws {
        let tooLong = (0..<26).map { "k\u{E9}\($0 % 10)x" }.joined(separator: ",")   // 26 words of 5 bytes and 25 commas
        let bytes = tooLong.utf8.count

        let errors = try Self.errors(editing: "Keywords", to: tooLong)

        #expect(bytes > 100)
        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: \(bytes) bytes, limit 100"), "\(errors)")
    }

    @Test("A keyword needs more than two characters and no space around it")
    func keywordShape() throws {
        let errors = try Self.errors(editing: "Keywords", to: "ab, padded,fine")

        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: 'ab' needs more than two characters and no surrounding space"), "\(errors)")
        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: ' padded' needs more than two characters and no surrounding space"), "\(errors)")
    }

    @Test("A keyword may not repeat a word of the name or the subtitle, nor be listed twice")
    func keywordRepeats() throws {
        var listing = try StoreListingFixture.listing()
        var texts = try #require(listing[StoreListingFixture.locale])
        texts.fields["Name"] = ["Resume Maker"]
        texts.fields["Subtitle"] = ["Quick forms"]
        texts.fields["Keywords"] = ["maker,forms,Currículum,curriculum"]
        listing[StoreListingFixture.locale] = texts

        let errors = StoreListingRules.check(listing, retired: try StoreListingFixture.retired())

        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: 'maker' repeats a word of the name or the subtitle"), "\(errors)")
        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: 'forms' repeats a word of the name or the subtitle"), "\(errors)")
        #expect(errors.contains("\(StoreListingFixture.locale) Keywords: a keyword is listed twice"), "\(errors)")
    }

    @Test("A price is refused in the name, the subtitle, the keywords and the captions, in any language", arguments: [
        ("Name", "Gratis CV"), ("Subtitle", "Kostenlos starten"), ("Keywords", "precio,cv-maker"), ("Name", "CV for $5"),
    ])
    func prices(field: String, text: String) throws {
        let errors = try Self.errors(editing: field, to: text)

        #expect(errors.contains("\(StoreListingFixture.locale) \(field): names a price (guideline 2.3.7)"), "\(errors)")
    }

    @Test("A field with no text, or with two, is refused")
    func fieldNeedsExactlyOneText() throws {
        var listing = try StoreListingFixture.listing()
        var texts = try #require(listing[StoreListingFixture.locale])
        texts.fields["Subtitle"] = nil
        texts.fields["Name"] = ["One", "Two"]
        listing[StoreListingFixture.locale] = texts

        let errors = StoreListingRules.check(listing, retired: try StoreListingFixture.retired())

        #expect(errors.contains("\(StoreListingFixture.locale): needs exactly one text under '### Subtitle'"), "\(errors)")
        #expect(errors.contains("\(StoreListingFixture.locale): needs exactly one text under '### Name'"), "\(errors)")
    }

    @Test("The notes for App Review are required and limited to 4000 characters")
    func notes() throws {
        var listing = try StoreListingFixture.listing()
        let retired = try StoreListingFixture.retired()
        listing.notes = String(repeating: "n", count: 4001)
        #expect(StoreListingRules.check(listing, retired: retired).contains("Notes for App Review: 4001 characters, limit 4000"))
        listing.notes = nil
        #expect(StoreListingRules.check(listing, retired: retired).contains("no text under '## Notes for App Review'"))
    }

    @Test("The parser reads a locale by the code at the end of its heading, and the first block of each field")
    func parsing() {
        let lines = ["# Title", "## Notes for App Review", "```text", "notes", "line", "```", "## German, de-DE", "### Name", "```text",
                     "Name de", "```", "### Description", "```text", "a", "", "b", "```", "## Other section", "### Name", "```text", "x", "```"]

        let listing = StoreListingRules.parse(lines)

        #expect(listing.notes == "notes\nline")
        #expect(listing.locales.map(\.code) == ["de-DE"])
        #expect(listing["de-DE"]?.fields == ["Name": ["Name de"], "Description": ["a\n\nb"]])
    }
}

// MARK: - Counts table

@Suite("The counts table of the store listing")
struct StoreListingCountsTests {
    @Test("The table in the document is the one the texts give")
    func tableIsCurrent() throws {
        let lines = try Repository.text(StoreListingFixture.document).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex(of: StoreListingRules.countsStart))
        let end = try #require(lines.firstIndex(of: StoreListingRules.countsEnd))

        let table = StoreListingRules.countsTable(try StoreListingFixture.listing())

        #expect(Array(lines[(start + 1)..<end]) == table, "the counts table is stale: run `swift run --package-path Tools/SourceChecks store-listing-counts --write`")
    }

    @Test("A row gives, for each locale, the counts of its texts, and the notes close the table")
    func rows() throws {
        let texts = ["Name": ["Ünï"], "Subtitle": ["Sub"], "Keywords": ["ké,wor"], "Promotional text": ["Promo"], "Description": ["Desc"],
                     "Screenshot captions": ["Title | Line below\nA | B"], "What's New": ["New"]]
        let listing = Listing(locales: [LocaleTexts(code: "xx", fields: texts)], notes: "Notes")

        let table = StoreListingRules.countsTable(listing)

        try #require(table.count == 5, "\(table)")
        #expect(table[0].hasPrefix("| Locale | Name (30) | Subtitle (30) | Keywords (100 bytes)"))
        #expect(table[1] == "|---|---|---|---|---|---|---|---|")
        #expect(table[2] == "| xx | 3 | 3 | 7 | 5 | 4 | 5 / 10 (2 captions) | 3 |")
        #expect(table[3] == "")
        #expect(table[4] == "Notes for App Review: 5 characters (4000).")
    }

    @Test("Replacing the table keeps the lines around it, and a document without the markers gives nothing")
    func replacing() {
        let lines = ["before", StoreListingRules.countsStart, "old", "rows", StoreListingRules.countsEnd, "after"]

        #expect(StoreListingRules.replacingCounts(in: lines, with: ["new"]) == ["before", StoreListingRules.countsStart, "new", StoreListingRules.countsEnd, "after"])
        #expect(StoreListingRules.replacingCounts(in: ["before", "after"], with: ["new"]) == nil)
    }
}

// MARK: - Retired words

private let aiClaims = [
    "en-US": "Draft it with AI on your iPhone.",
    "de-DE": "Mit KI entwerfen, direkt auf dem iPhone.",
    "it": "Scrivilo con l'IA sul tuo iPhone.",
    "es-ES": "Redáctalo con IA en tu iPhone.",
    "fr-FR": "Rédigez avec l'IA sur votre iPhone.",
    "pt-PT": "Escreva com IA no seu iPhone.",
]

/// The retired words (store-listing-retired-words.json) are the claims check: a text of the 1.1 listing must not name a feature
/// the app lacks, in the language of its locale.
@Suite("The retired words of the store listing")
struct StoreListingRetiredWordsTests {
    @Test("The listing names no retired feature")
    func listingIsClean() throws {
        #expect(StoreListingRules.check(try StoreListingFixture.listing(), retired: try StoreListingFixture.retired()) == [])
    }

    @Test("Every entry has a reason and a language, and every pending locale is a locale of the listing")
    func entriesAreWellFormed() throws {
        let retired = try StoreListingFixture.retired()
        let languages: Set<String> = ["*", "en", "de", "it", "es", "fr", "pt"]
        let fields = Set(StoreListingRules.fields)

        #expect(!retired.entries.isEmpty)
        for entry in retired.entries {
            let pattern = entry.regex.pattern
            #expect(!entry.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(pattern)")
            #expect(Set(entry.languages).isSubset(of: languages), "\(pattern)")
            #expect(Set(entry.allowedIn).isSubset(of: fields), "\(pattern)")
            #expect(Set(entry.onlyIn ?? StoreListingRules.fields).isSubset(of: fields), "\(pattern)")
        }
        let known = Set(try StoreListingFixture.listing().locales.map(\.code)).union(["notes"])
        #expect(Set(retired.pendingLocales).isSubset(of: known), "\(retired.pendingLocales)")
    }

    @Test("The AI draft is refused in every language", arguments: aiClaims.sorted { $0.key < $1.key })
    func aiDraftIsRefused(locale: String, claim: String) throws {
        #expect(!(try StoreListingFixture.retiredErrors(locale, "Description", claim)).isEmpty, "\(claim)")
    }

    @Test("The other retired features are refused", arguments: [
        "Apple Intelligence writes it", "an on-device model", "Import from LinkedIn", "Scan your CV", "Also on the Mac", "also for macOS",
    ])
    func otherFeaturesAreRefused(claim: String) throws {
        #expect(!(try StoreListingFixture.retiredErrors("en-US", "Description", claim)).isEmpty, "\(claim)")
    }

    @Test("The usual variants are refused", arguments: [
        ("en-US", "ai-powered CVs"), ("en-US", "Written by A.I."), ("en-US", "Drafted for you"), ("en-US", "Keep drafting"),
        ("en-US", "Apple-Intelligence"), ("en-US", "an on device model"), ("en-US", "Import from Linked-In"), ("en-US", "On all your Macs"),
        ("de-DE", "Mit K.I."), ("de-DE", "ki-gestützt"), ("de-DE", "Drei Entwürfe"), ("de-DE", "Das On-Device-Modell schreibt"),
        ("it", "Una Bozza pronta"), ("it", "Con l'I.A."), ("it", "Con la ia generativa"),
        ("es-ES", "Con I.A."), ("es-ES", "Borrador listo"), ("fr-FR", "Brouillon prêt"),
        ("pt-PT", "Com IA"), ("pt-PT", "Rascunho pronto"),
    ])
    func variantsAreRefused(locale: String, text: String) throws {
        #expect(!(try StoreListingFixture.retiredErrors(locale, "Description", text)).isEmpty, "\(text)")
    }

    @Test("In Portuguese, the word is refused in the keywords too")
    func portugueseKeyword() throws {
        #expect(!(try StoreListingFixture.retiredErrors("pt-PT", "Keywords", "ia")).isEmpty)
    }

    @Test("A scan is refused in its forms", arguments: [
        ("en-US", "Scan your CV"), ("en-US", "a scanned page"), ("en-US", "scanning made easy"), ("de-DE", "eingescannt"),
        ("de-DE", "Sie können Ihren Lebenslauf einscannen"), ("de-DE", "um ihn einzuscannen"), ("de-DE", "abscannen"),
        ("de-DE", "der Dokumentenscanner"), ("de-DE", "ein Dokumentenscan"), ("de-DE", "Scan-Funktion"),
        ("it", "scansiona il CV"), ("es-ES", "escanea tu CV"), ("fr-FR", "numérisez le CV"),
    ])
    func scanIsRefused(locale: String, text: String) throws {
        #expect(!(try StoreListingFixture.retiredErrors(locale, "Description", text)).isEmpty, "\(text)")
    }

    @Test("The Mac is refused in any case", arguments: [
        ("en-US", "Also available for macos."), ("en-US", "Also available for MAC."), ("en-US", "Works on your iMac"),
        ("en-US", "on a MacBook Pro"), ("en-US", "for iMacs"), ("de-DE", "Auch für den MAC"), ("fr-FR", "aussi sur MACOS"),
        ("es-ES", "también en imac"), ("it", "anche su Mac"), ("pt-BR", "também no macbook air"),
    ])
    func macIsRefused(locale: String, text: String) throws {
        #expect(!(try StoreListingFixture.retiredErrors(locale, "Description", text)).isEmpty, "\(text)")
    }

    @Test("Words that only look like a retired one pass")
    func lookAlikesPass() throws {
        #expect(try StoreListingFixture.retiredErrors("en-US", "Description", "Scandinavian roles, all linked in one place.") == [])
        #expect(try StoreListingFixture.retiredErrors("en-US", "Description", "Tuscany and the Tuscans.") == [])
        #expect(try StoreListingFixture.retiredErrors("pt-PT", "Description", "Eu ia ao trabalho.") == [])
        #expect(try StoreListingFixture.retiredErrors("it", "Description", "Ai colleghi piace.") == [])
    }

    @Test("A caption and the keywords are checked too")
    func captionsAndKeywordsAreChecked() throws {
        #expect(!(try StoreListingFixture.retiredErrors("de-DE", "Screenshot captions", "Apple Intelligence | Ein Entwurf")).isEmpty)
        #expect(!(try StoreListingFixture.retiredErrors("en-US", "Keywords", "linkedin")).isEmpty)
    }

    @Test("What's New may say the AI draft is gone, and may name nothing else retired")
    func whatsNewIsExempt() throws {
        #expect(try StoreListingFixture.retiredErrors("en-US", "What's New", "The AI draft of version 1.0 is gone.") == [])
        #expect(!(try StoreListingFixture.retiredErrors("en-US", "What's New", "Now with Apple Intelligence.")).isEmpty)
    }

    @Test("The notes for App Review are checked in English")
    func notesAreChecked() throws {
        var listing = try StoreListingFixture.listing()
        listing.notes = (listing.notes ?? "") + "\nTap Draft My CV with AI."

        let errors = StoreListingRules.checkRetired(listing, retired: try StoreListingFixture.retired())

        #expect(errors.contains { $0.hasPrefix("notes ") }, "\(errors)")
    }

    @Test("Ordinary words are not retired", arguments: ["en-US", "de-DE", "it"])
    func ordinaryWordsPass(locale: String) throws {
        let text = "Mach dein CV in Italia: mail, main, machine, scale, Macedonia, bozzetto, Entwicklung, Mackintosh, machen, a macro and a tablet."

        #expect(try StoreListingFixture.retiredErrors(locale, "Description", text) == [])
    }
}

// MARK: - Pending locales

@Suite("The pending locales of the store listing")
struct StoreListingPendingLocalesTests {
    private static func listing(_ description: String) -> Listing {
        Listing(locales: [LocaleTexts(code: "en-US", fields: ["Description": [description]])], notes: "Plain notes.")
    }

    @Test("A pending locale that passes must leave the baseline")
    func passingPendingLocaleIsRefused() throws {
        var retired = try StoreListingFixture.retired()
        retired.pendingLocales = ["en-US"]

        let errors = StoreListingRules.checkRetired(Self.listing("A plain CV maker."), retired: retired)

        #expect(errors.contains { $0.contains("remove it from pendingLocales") && $0.contains("en-US") }, "\(errors)")
    }

    @Test("A pending locale that fails is not reported")
    func failingPendingLocaleIsNotReported() throws {
        var retired = try StoreListingFixture.retired()
        retired.pendingLocales = ["en-US"]

        #expect(StoreListingRules.checkRetired(Self.listing("Draft it with AI."), retired: retired) == [])
    }

    @Test("A pending name that is no locale is refused")
    func unknownPendingNameIsRefused() throws {
        var retired = try StoreListingFixture.retired()
        retired.pendingLocales = ["xx"]

        let errors = StoreListingRules.checkRetired(Self.listing("Plain."), retired: retired)

        #expect(errors.contains { $0.contains("'xx' is not a locale") }, "\(errors)")
    }

    @Test("A grown list is refused, and the locales that grew are named")
    func grownListIsRefused() {
        let errors = StoreListingRules.pendingGrowth(pending: ["es-ES", "fr-FR"], base: ["es-ES"])

        #expect(errors.contains { $0.contains("grew") && $0.contains("fr-FR") && !$0.contains("es-ES") }, "\(errors)")
    }

    @Test("An equal or shorter list passes")
    func equalOrShorterPasses() {
        #expect(StoreListingRules.pendingGrowth(pending: ["es-ES"], base: ["es-ES"]) == [])
        #expect(StoreListingRules.pendingGrowth(pending: [], base: ["es-ES", "fr-FR"]) == [])
    }

    @Test("A list that holds a locale cannot grow from an empty one")
    func emptyBaselineRefusesAnyLocale() {
        #expect(StoreListingRules.pendingGrowth(pending: ["es-ES"], base: []) == ["retired words: pendingLocales grew compared with the target branch: es-ES"])
    }

    @Test("The pending locales of this branch have not grown compared with the target branch's")
    func thisBranchHasNotGrown() throws {
        guard let ref = ProcessInfo.processInfo.environment[TargetBranch.variable], !ref.isEmpty else { return }   // no pull request: nothing to compare
        let pending = try StoreListingFixture.retired().pendingLocales

        guard case .list(let base) = try TargetBranch.pendingLocales(ref: ref, file: StoreListingFixture.retiredWords) else { return }

        #expect(StoreListingRules.pendingGrowth(pending: pending, base: base) == [])
    }
}

// MARK: - The target branch

@Suite("The target branch's list of pending locales")
struct TargetBranchTests {
    private static let file = "Tools/Release/store-listing-retired-words.json"

    /// A repository of one commit on `main`, holding `contents` at the path of the retired-words file when it is not nil.
    private static func repository(holding contents: String?) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("target-branch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = contents == nil ? "other.txt" : file
        let url = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (contents ?? "x").write(to: url, atomically: true, encoding: .utf8)
        for arguments in [["init", "-q", "-b", "main"], ["add", "."],
                          ["-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-q", "-m", "one"]] {
            #expect(TargetBranch.git(arguments, in: folder) != nil, "git \(arguments) failed")
        }
        return folder
    }

    @Test("The list of the ref is read from the file the ref holds")
    func readsTheList() throws {
        let folder = try Self.repository(holding: #"{"pendingLocales": ["es-ES", "fr-FR"], "entries": []}"#)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(try TargetBranch.pendingLocales(ref: "main", file: Self.file, in: folder) == .list(["es-ES", "fr-FR"]))
    }

    @Test("A ref the checkout lacks is compared as an empty list")
    func missingRefIsEmpty() throws {
        let folder = try Self.repository(holding: #"{"pendingLocales": ["es-ES"]}"#)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(try TargetBranch.pendingLocales(ref: "origin/main", file: Self.file, in: folder) == .list([]))
    }

    @Test("A target branch with no such file is not compared")
    func missingFileIsNotCompared() throws {
        let folder = try Self.repository(holding: nil)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(try TargetBranch.pendingLocales(ref: "main", file: Self.file, in: folder) == .notCompared)
    }

    @Test("A file with no list is an empty list")
    func fileWithoutListIsEmpty() throws {
        let folder = try Self.repository(holding: #"{"entries": []}"#)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(try TargetBranch.pendingLocales(ref: "main", file: Self.file, in: folder) == .list([]))
    }
}
