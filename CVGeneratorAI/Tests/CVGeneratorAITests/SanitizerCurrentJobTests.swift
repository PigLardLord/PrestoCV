import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may say about a job being current: only if the sentence that names the employer or title
/// says it goes on now, and says nothing that ends it or hedges it.
@Suite("Sanitizer: a job is current only if the description says so")
struct SanitizerCurrentJobTests {
    private let sanitizer = CVDataSanitizer()

    private func isCurrent(_ description: String, employer: String = "Trattoria Da Mario", title: String? = nil, startDate: String? = nil) throws -> Bool {
        let job = Experience(title: title ?? "", company: employer, startDate: startDate, current: true)
        return try sanitizer.sanitize(CVData(experience: [job]), against: description).experience.first?.current == true
    }

    @Test("A job the description says goes on now stays current",
          arguments: [
            "I work at Trattoria Da Mario now.",
            "Currently I work at Trattoria Da Mario.",
            "Today I cook at Trattoria Da Mario.",
            "I still work at Trattoria Da Mario.",
            "Since 2019 I have cooked at Trattoria Da Mario.",
            "Attualmente lavoro alla Trattoria Da Mario.",
            "Dal 2019 lavoro alla Trattoria Da Mario.",
            "Lavoro ad oggi alla Trattoria Da Mario.",
            "Derzeit arbeite ich in der Trattoria Da Mario.",
            "Seit 2019 arbeite ich in der Trattoria Da Mario.",
            "Actualmente trabajo en la Trattoria Da Mario.",
            "Desde 2019 trabajo en la Trattoria Da Mario.",
            "Actuellement, je travaille à la Trattoria Da Mario.",
            "Depuis 2019, je travaille à la Trattoria Da Mario.",
            "Atualmente trabalho na Trattoria Da Mario.",
            "Desde 2019 trabalho na Trattoria Da Mario.",
          ])
    func currentWhenStated(description: String) throws {
        #expect(try isCurrent(description))
    }

    @Test("A job is not current when the description only says it happened",
          arguments: [
            "I worked at Trattoria Da Mario.",
            "I worked at Trattoria Da Mario in 2018.",
            "I worked at Trattoria Da Mario from 2012 to 2016.",
            "Since 2012 I worked at Trattoria Da Mario until 2016.",
            "Since 2012 I worked at Trattoria Da Mario, and I left in 2016.",
            "Formerly I cooked at Trattoria Da Mario.",
            "I no longer work at Trattoria Da Mario.",
            "I don't work at Trattoria Da Mario now.",
            "Prima lavoravo alla Trattoria Da Mario, oggi no.",
            "Dal 2012 al 2016 ho lavorato alla Trattoria Da Mario.",
            "Von 2012 bis heute habe ich nicht bei der Trattoria Da Mario gearbeitet.",
          ])
    func notCurrentWhenOnlyPast(description: String) throws {
        #expect(try !isCurrent(description))
    }

    /// A description about two jobs: the person's current state of each, as the sanitizer reads it.
    private func currents(_ description: String, _ jobs: [(title: String?, employer: String)]) throws -> [Bool] {
        let experiences = jobs.map { Experience(title: $0.title ?? "", company: $0.employer, current: true) }
        let result = try sanitizer.sanitize(CVData(experience: experiences), against: description).experience
        return jobs.map { job in result.first { $0.company == job.employer }?.current ?? false }
    }

    @Test("A job that ended does not become current because a later job in the same sentence is",
          arguments: [
            "I worked at Acme from 2012 to 2016, and now cook at Beta.",
            "I worked at Acme from 2012 to 2016, now I cook at Beta.",
            "I worked at Acme from 2012 to 2016; currently I cook at Beta.",
            "I worked at Acme in 2012 and now cook at Beta.",
            "Ho lavorato da Acme dal 2012 al 2016 e oggi cucino da Beta.",
            "Ich habe von 2012 bis 2016 bei Acme gearbeitet und koche jetzt bei Beta.",
          ])
    func endedJobBesideCurrentJob(description: String) throws {
        let result = try currents(description, [(title: nil, employer: "Acme"), (title: nil, employer: "Beta")])

        #expect(result[0] == false, "Acme ended: \(description)")
        #expect(result[1] == true, "Beta goes on: \(description)")
    }

    @Test("A job that ended does not become current through a title it shares with the current job")
    func endedJobSharingATitle() throws {
        let description = "I worked as a cook at Acme from 2012 to 2016. I am a cook at Beta now."

        let result = try currents(description, [(title: "cook", employer: "Acme"), (title: "cook", employer: "Beta")])

        #expect(result == [false, true])
    }

    @Test("The same two jobs in separate sentences, in either order, give the same answer")
    func endedAndCurrentInSeparateSentences() throws {
        #expect(try currents("I worked at Acme from 2012 to 2016. Now I cook at Beta.", [(nil, "Acme"), (nil, "Beta")]) == [false, true])
        #expect(try currents("Now I cook at Beta. I worked at Acme from 2012 to 2016.", [(nil, "Acme"), (nil, "Beta")]) == [false, true])
        #expect(try currents("I cook at Beta now, and I worked at Acme in 2012.", [(nil, "Acme"), (nil, "Beta")]) == [false, true])
    }

    @Test("A present word that follows the clause of the employer does not reach back to it")
    func presentWordInAnotherClause() throws {
        #expect(try currents("I worked at Acme and still do.", [(nil, "Acme")]) == [false])
        #expect(try currents("I worked at Acme, and now I paint.", [(nil, "Acme")]) == [false])
    }

    @Test("A statement about something else never lends its \"now\" to a job in the same sentence",
          arguments: [
            "I paint now, I worked at Acme in 2012.",
            "I paint now; I worked at Acme in 2012.",
            "I currently paint, I worked at Acme in 2012.",
            "Currently in Rome, I worked at Acme in 2012.",
            "Since 2019 I paint, Acme was my job in 2012.",
            "Since lunch, I cooked at Acme in 2012.",
            "Dipingo oggi, ho lavorato da Acme nel 2012.",
            "Ich male jetzt, ich habe 2012 bei Acme gearbeitet.",
            "Pinto ahora, trabajé en Acme en 2012.",
            "Je peins maintenant, j'ai travaillé chez Acme en 2012.",
            "Pinto agora, trabalhei na Acme em 2012.",
          ])
    func independentStatementLendsNothing(description: String) throws {
        #expect(try currents(description, [(nil, "Acme")]) == [false], "\(description)")
    }

    @Test("A time on its own at the start of the sentence still belongs to the clause after it",
          arguments: [
            "Currently, I work at Acme.",
            "Since 2019, I work at Acme.",
            "Today, I work at Acme.",
            "Attualmente, lavoro da Acme.",
            "Ad oggi, lavoro da Acme.",
            "Dal 2019, lavoro da Acme.",
            "Derzeit, arbeite ich bei Acme.",
            "Seit 2019, arbeite ich bei Acme.",
            "Actualmente, trabajo en Acme.",
            "Desde 2019, trabajo en Acme.",
            "Actuellement, je travaille chez Acme.",
            "Depuis 2019, je travaille chez Acme.",
            "Atualmente, trabalho na Acme.",
            "Desde 2019, trabalho na Acme.",
          ])
    func leadInStillTransfers(description: String) throws {
        #expect(try currents(description, [(nil, "Acme")]) == [true], "\(description)")
    }

    @Test("A lead-in before the comma belongs to the clause of the employer")
    func leadInBelongsToTheNextClause() throws {
        #expect(try currents("Currently, I work at Acme, where I cook.", [(nil, "Acme")]) == [true])
        #expect(try currents("Since 2019, I work at Acme.", [(nil, "Acme")]) == [true])
        #expect(try currents("Depuis 2019, je travaille chez Acme.", [(nil, "Acme")]) == [true])
    }

    @Test("\"Since\" needs exactly one year in the sentence, and two years in the clause deny a present word")
    func yearsDecide() throws {
        #expect(try currents("Since I was young I cook at Acme.", [(nil, "Acme")]) == [false], "No year at all")
        #expect(try currents("Since 2012 I cook at Acme.", [(nil, "Acme")]) == [true], "One year")
        #expect(try currents("Since 2012 I cook at Acme, as I did in 2016.", [(nil, "Acme")]) == [false], "Two years in the sentence")
        #expect(try currents("I cook at Acme now from 2012 to 2016.", [(nil, "Acme")]) == [false], "A present word and two years in one clause")
    }

    @Test("A job stays current when its own clause says so, whatever the other clauses say")
    func ownClauseDecides() throws {
        #expect(try currents("I cook at Beta now, but I left Acme in 2016.", [(nil, "Acme"), (nil, "Beta")]) == [false, true])
    }

    @Test("A present word in another sentence does not make the job current")
    func presentWordElsewhere() throws {
        #expect(try !isCurrent("I worked at Trattoria Da Mario in 2018. Now I also paint."))
    }

    @Test("A job the description never names is dropped, so nothing about it is current")
    func unnamedJob() throws {
        let job = Experience(title: "cook", company: "Trattoria Da Mario", current: true)

        #expect(try sanitizer.sanitize(CVData(experience: [job]), against: "I'm a nurse now.").experience.isEmpty)
    }

    @Test("The title can carry the statement when the employer is not in the description")
    func titleCarriesTheStatement() throws {
        #expect(try isCurrent("I'm a nurse now since 2019.", employer: "Ospedale Nowhere", title: "nurse", startDate: "2019"))
        #expect(try isCurrent("I'm a nurse now since 2019.", employer: "", title: "nurse", startDate: "2019"))
        #expect(try !isCurrent("I was a nurse in 2018.", employer: "Ospedale Nowhere", title: "nurse", startDate: "2018"))
    }

    @Test("A job that was not claimed to be current stays not current")
    func notClaimedStaysNotCurrent() throws {
        let job = Experience(title: "nurse", startDate: "2019", current: false)

        let result = try sanitizer.sanitize(CVData(experience: [job]), against: "I'm a nurse now since 2019.").experience

        #expect(result.first?.current == false)
    }
}
