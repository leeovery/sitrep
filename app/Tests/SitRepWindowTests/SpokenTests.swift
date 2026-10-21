import Foundation
@testable import SitRepCore
@testable import SitRepWindow
import Testing

/// What VoiceOver reads of the window: words for its marks, counts and times, never their symbols.
struct SpokenTests {
    private static func row(_ mark: Mark, isAway: Bool = false, since: Date = minutes(before: 300)) -> Listed.Row {
        Listed.Row(id: "sr-macapp", name: "The Mac app", project: "SitRep", mark: mark, isAway: isAway, since: since)
    }

    @Test(arguments: [
        (Mark.needs, false, "The Mac app, SitRep, needs you, 5 hours"),
        (.working, false, "The Mac app, SitRep, working, 5 hours"),
        (.turn, false, "The Mac app, SitRep, your turn, 5 hours"),
        (.away, true, "The Mac app, SitRep, away, 5 hours"),
        (.needs, true, "The Mac app, SitRep, needs you, away, 5 hours"),
    ])
    func aSidebarRowReadsAsItsSessionItsProjectItsStateAndItsAge(mark: Mark, isAway: Bool, words: String) {
        #expect(Spoken.row(Self.row(mark, isAway: isAway), at: printedAt) == words)
    }

    @Test func aNeedsYouRowReadsAsAProjectsRowDoes() throws {
        let listed = Listed(heard(line(0)))
        let flat = try #require(listed.flat.first { $0.id == "sr-rq7dgr" })

        #expect(Spoken.row(flat, at: printedAt) == "Request ledger, Switchboard, your turn, 12 minutes")
    }

    @Test func theFilterFieldReadsAsWhatItDoes() {
        #expect(Spoken.filter == "Filter sessions")
    }

    @Test func anAgeReadsInWholeMinutesHoursOrDaysAsTheRowShowsIt() {
        #expect(Spoken.age(minutes(before: 0), at: printedAt) == "just now")
        #expect(Spoken.age(minutes(before: 1), at: printedAt) == "1 minute")
        #expect(Spoken.age(minutes(before: 59), at: printedAt) == "59 minutes")
        #expect(Spoken.age(minutes(before: 60), at: printedAt) == "1 hour")
        #expect(Spoken.age(minutes(before: 23 * 60 + 59), at: printedAt) == "23 hours")
        #expect(Spoken.age(minutes(before: 48 * 60), at: printedAt) == "2 days")
    }

    @Test func aProjectHeadingReadsItsNameAndWhatWaitsThere() {
        let waiting = Listed.Project(id: "sitrep", name: "SitRep", waiting: 3, sessions: [])
        let none = Listed.Project(id: "kit", name: "Kit", waiting: 0, sessions: [])

        #expect(Spoken.project(waiting) == "SitRep, 3 waiting")
        #expect(Spoken.project(none) == "Kit, nothing waiting")
        #expect(Spoken.quiet(Listed.Quiet(id: "kit", name: "Kit", sessions: [])) == "Kit, quiet project")
    }

    @Test func aCardIsLabelledByItsAsksTitleAfterItsSessionsNameInAProject() throws {
        let card = try #require(opened().page(at: printedAt).session?.asks.first)

        #expect(Spoken.card(card, session: nil) == card.title)
        #expect(Spoken.card(card, session: "The Mac app") == "The Mac app: \(card.title)")
    }

    @Test func aHeadingReadsItsNameAndTheWordsOnItsRight() {
        #expect(Spoken.heading("Asks", note: "3 waiting") == "Asks, 3 waiting")
        #expect(Spoken.heading("Status", note: nil) == "Status")
    }

    @Test(arguments: [(Mark.needs, "needs you"), (.turn, "your turn"), (.working, "working"), (.away, "away")])
    func aMarkReadsAsWhatItMeans(mark: Mark, words: String) {
        #expect(Spoken.mark(mark) == words)
    }
}
