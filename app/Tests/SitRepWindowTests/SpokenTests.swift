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

    /// What waits first, how many and each line's words, then its project and session and the oldest's time.
    @Test func aNeedsYouRowReadsItsLinesThenItsProjectAndSession() throws {
        let listed = Listed(heard(line(0)))
        let asking = try #require(listed.needsYou.first { $0.id == "sr-dash02" })
        let age = Spoken.age(asking.since, at: printedAt)

        #expect(
            Spoken.needsYou(asking, at: printedAt)
                == "2 asks, Paste the load test's output for the Usage area, Allow Bash gh pr create --draft --base main, "
                + "Switchboard, Dashboard redesign, \(age)"
        )
    }

    /// One line reads with no count; away, it says so before its time.
    @Test(arguments: [false, true])
    func aNeedsYouRowOfOneLineReadsNoCountAndAwaySaysSo(isAway: Bool) {
        let since = minutes(before: 90)
        let asking = Listed.Row(
            id: "sr-1", name: "The bootstrap", project: "Kit", mark: .needs, isAway: isAway, since: since,
            lines: [Listed.Waiting(id: "ask:sr-1:k1", lead: "Which edge?", code: nil, more: "+2", since: since)]
        )

        #expect(
            Spoken.needsYou(asking, at: printedAt)
                == (isAway ? "Which edge?, Kit, The bootstrap, away, 1 hour" : "Which edge?, Kit, The bootstrap, 1 hour")
        )
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

    @Test func aSidebarHeadingReadsItsNameWhatWaitsThereAndWhetherItIsFolded() {
        let heading = { (fold: Fold, name: String, isFolded: Bool, waiting: Int) in
            Spoken.heading(Sidebar.Heading(fold: fold, name: name, isFolded: isFolded, asking: 1, waiting: waiting))
        }

        #expect(heading(.project("sitrep"), "SitRep", false, 3) == "SitRep, 3 waiting")
        #expect(heading(.project("kit"), "Kit", true, 0) == "Kit, nothing waiting, folded")
        #expect(heading(.quiet, Words.quietProjects, false, 0) == "Quiet projects")
        #expect(heading(.quiet, Words.quietProjects, true, 0) == "Quiet projects, folded")
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

    @Test(arguments: [
        (Mark.needs, "needs you"), (.turn, "your turn"), (.working, "working"), (.onItsWork, "on its own work"),
        (.away, "away"),
    ])
    func aMarkReadsAsWhatItMeans(mark: Mark, words: String) {
        #expect(Spoken.mark(mark) == words)
    }
}
