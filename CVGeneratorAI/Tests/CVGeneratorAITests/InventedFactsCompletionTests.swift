import Testing
import Foundation
import CVGeneratorAI

// A year that a school's sentence says only as the year the studies were completed is never the start of the studies
// (ADR 0023, "A completion year is never a start date"). The counter must catch it without the production rules: a start
// date equal to such a year is invented, and one whose year the sentence gives as a start stays a quote.

@Suite("Invented facts: a completion year is not a start date")
struct InventedFactsCompletionTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let label: String
        let description: String
        let start: String
        var end: String?
        let kind: InventedFacts.Class

        var testDescription: String { label }
    }

    static let all: [Case] = [
        Case(label: "en: finished in the year, no end date", description: "I studied at Gamma University and finished in 2013.", start: "2013", kind: .invented),
        Case(label: "en: graduated in the year, both dates hold it", description: "I studied at Gamma University and graduated in 2013.", start: "2013", end: "2013", kind: .invented),
        Case(label: "it: laureato nel, no end date", description: "Mi sono laureato alla Gamma University nel 2013.", start: "2013", kind: .invented),
        Case(label: "it: diplomata nel, both dates hold it", description: "Mi sono diplomata alla Gamma University nel 2013.", start: "2013", end: "2013", kind: .invented),
        Case(label: "de: abgeschlossen, no end date", description: "Ich habe das Studium an der Gamma University 2013 abgeschlossen.", start: "2013", kind: .invented),
        Case(label: "es: terminé en, both dates hold it", description: "Terminé mis estudios en la Gamma University en 2013.", start: "2013", end: "2013", kind: .invented),
        Case(label: "fr: diplômé de, no end date", description: "Diplômé de la Gamma University en 2013.", start: "2013", kind: .invented),
        Case(label: "pt: formei-me em, both dates hold it", description: "Formei-me na Gamma University em 2013.", start: "2013", end: "2013", kind: .invented),
        Case(label: "en: the start year is stated, so the start stays a quote", description: "I studied at Gamma University from 2009 and graduated in 2013.", start: "2009", end: "2013", kind: .quote),
        Case(label: "it: the start year is stated, so the start stays a quote", description: "Ho studiato alla Gamma University dal 2009 e mi sono laureato nel 2013.", start: "2009", end: "2013", kind: .quote),
        Case(label: "de: the start year is stated, so the start stays a quote", description: "Ich studierte an der Gamma University seit 2009 und schloss 2013 ab.", start: "2009", end: "2013", kind: .quote),
        Case(label: "en: a year the sentence gives as a start, with the completion word, stays a quote", description: "I started at Gamma University in 2013 and graduated later.", start: "2013", kind: .quote),
        Case(label: "en: a completion word that names the degree, after a start verb, is for review", description: "I started my graduate studies at Gamma University in 2013.", start: "2013", kind: .review),
        Case(label: "it: a completion word that names the degree, after a start verb, is for review", description: "Ho iniziato la laurea alla Gamma University nel 2013.", start: "2013", kind: .review),
        Case(label: "en: a from before the year of graduate studies is for review", description: "I did graduate studies at Gamma University from 2013.", start: "2013", kind: .review),
        Case(label: "en: an undated start and a graduation in one sentence is for review", description: "I started studying at Gamma University long ago and graduated in 2013.", start: "2013", kind: .review),
        Case(label: "it: an undated start and a graduation in one sentence is for review", description: "Ho iniziato a studiare alla Gamma University tempo fa e mi sono laureato nel 2013.", start: "2013", kind: .review),
        Case(label: "fr: an undated start and a completion in one sentence is for review", description: "J'ai commencé mes études à Gamma University il y a longtemps et fini en 2013.", start: "2013", kind: .review),
        Case(label: "en: an ongoing completing after a start verb is for review", description: "I started completing my degree at Gamma University in 2013.", start: "2013", kind: .review),
        Case(label: "fr: a start verb before the noun diplôme is for review", description: "J'ai commencé mon diplôme à Gamma University en 2013.", start: "2013", kind: .review),
        Case(label: "fr: a start verb before the participle diplômé is for review", description: "J'ai commencé à Gamma University et je suis diplômé en 2013.", start: "2013", kind: .review),
        Case(label: "en: no word of a start or a completion is for review", description: "I studied at Gamma University in 2013.", start: "2013", kind: .review),
        Case(label: "it: no word of a start or a completion is for review", description: "Ho studiato alla Gamma University nel 2013.", start: "2013", kind: .review),
        Case(label: "de: no word of a start or a completion is for review", description: "Ich habe an der Gamma University 2013 studiert.", start: "2013", kind: .review),
        Case(label: "es: a start and a completion word together is for review", description: "Empecé mis estudios en la Gamma University y terminé en 2013.", start: "2013", kind: .review),
        Case(label: "pt: a start and a completion word together is for review", description: "Comecei na Gamma University e formei-me em 2013.", start: "2013", kind: .review),
        Case(label: "de: a start and a completion word together is for review", description: "Ich begann an der Gamma University und schloss 2013 ab.", start: "2013", kind: .review),
        Case(label: "en: a start in one mention and a completion in another is for review", description: "I started at Gamma University in 2013. I graduated from Gamma University in 2013.", start: "2013", kind: .review),
        Case(label: "en: a start in one mention and nothing in another is for review", description: "I started at Gamma University in 2013. I liked Gamma University in 2013.", start: "2013", kind: .review),
    ]

    @Test("The start of a school is a quote only when its sentence gives the year as a start", arguments: all)
    func startDate(_ item: Case) {
        let cv = CVData(education: [Education(institution: "Gamma University", startDate: item.start, endDate: item.end)])

        let report = InventedFacts.count(cv, description: item.description)

        let finding = report.finding(at: "education[0].startDate")
        #expect(finding?.kind == item.kind, "\(item): \(report.findings)")
        if item.kind == .review {
            #expect(finding?.reason.contains("start or the completion") == true, "\(item): \(finding?.reason ?? "no finding")")
        }
        if item.kind == .invented {
            #expect(finding?.reason.contains("completion") == true, "\(item): \(finding?.reason ?? "no finding")")
        }
    }
}
