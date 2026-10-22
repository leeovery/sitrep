import Foundation
@testable import SitRepCore
import enum SitRepPanel.BoardSection
import struct SitRepPanel.Earlier
@testable import SitRepWindow
import Testing

/// What VoiceOver reads of the window: words for its marks, counts and times, never their symbols.
struct SpokenTests {
    /// A row of Working or Your turn, its one line as given.
    private static func row(_ section: BoardSection, _ mark: Mark, _ line: Listed.Line) -> Listed.Row {
        Listed.Row(
            id: "sr-macapp", name: "The Mac app", project: "SitRep", section: section, mark: mark, isAway: false,
            since: minutes(before: 300), lines: [line]
        )
    }

    private static func said(_ lead: String, code: String? = nil, subject: String? = nil, until: Date? = nil) -> Listed.Line {
        Listed.Line(
            id: "turn:sr-macapp", lead: lead, code: code, subject: subject, until: until, more: nil,
            since: minutes(before: 300)
        )
    }

    @Test(arguments: [
        (BoardSection.working, Mark.working, said("Running", code: "swift test"),
         "Running swift test, SitRep, The Mac app, working, 5 hours"),
        (.working, .onItsWork, said("Waiting on", subject: "3 agents"),
         "Waiting on 3 agents, SitRep, The Mac app, on its own work, 5 hours"),
        (.working, .onItsWork, said("Wakes", until: minutes(before: -12)),
         "Wakes in 12m, SitRep, The Mac app, on its own work, 5 hours"),
        (.yourTurn, .turn, said("Drawing round 3"), "Drawing round 3, SitRep, The Mac app, your turn, 5 hours"),
    ])
    func aWorkingOrYourTurnRowReadsItsWordsItsProjectItsSessionItsStateAndItsAge(
        section: BoardSection, mark: Mark, line: Listed.Line, words: String
    ) {
        #expect(Spoken.row(Self.row(section, mark, line), at: printedAt) == words)
    }

    /// Every row a window holds offers VoiceOver its button as an action, "Jump to the window", whatever its section;
    /// an away row, none.
    @Test func aRowAWindowHoldsOffersTheJumpAsAnActionAndAnAwayRowNone() {
        let working = Self.row(.working, .working, Self.said("Running", code: "swift test"))
        let turn = Self.row(.yourTurn, .turn, Self.said("Drawing round 3"))
        let needs = Listed.Row(
            id: "sr-dash02", name: "Dashboard redesign", project: "Switchboard", section: .needsYou, mark: .needs,
            isAway: false, since: minutes(before: 300), lines: [Self.said("Paste the load test's output")]
        )
        let away = Listed.Row(
            id: "sr-gs7kq2", name: "Onboarding", project: "Goosemates", section: .needsYou, mark: .needs,
            isAway: true, since: minutes(before: 300), lines: [Self.said("Keep the invite flow?")]
        )

        #expect([working, turn, needs].map(Spoken.jump) == ["Jump to the window", "Jump to the window", "Jump to the window"])
        #expect(Spoken.jump(away) == nil)
    }

    @Test func aNeedsYouRowReadsAsNeedsYouSaysIt() throws {
        let asking = try #require(Listed(heard(line(0))).needsYou.first)

        #expect(Spoken.row(asking, at: printedAt) == Spoken.needsYou(asking, at: printedAt))
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
            id: "sr-1", name: "The bootstrap", project: "Kit", section: .needsYou, mark: .needs, isAway: isAway,
            since: since, lines: [Listed.Line(id: "ask:sr-1:k1", lead: "Which edge?", code: nil, more: "+2", since: since)]
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

    @Test func aSidebarHeadingReadsItsNameItsCountAndWhetherItIsFolded() {
        let heading = { (fold: Fold, count: Int, isFolded: Bool) in
            Spoken.heading(Sidebar.Heading(fold: fold, count: count, isFolded: isFolded))
        }

        #expect(heading(.section(.needsYou), 4, false) == "Needs you, 4 waiting")
        #expect(heading(.section(.working), 1, true) == "Working, 1 session, folded")
        #expect(heading(.section(.yourTurn), 3, false) == "Your turn, 3 sessions")
        #expect(heading(.projects, 6, true) == "Projects, 6 projects, folded")
    }

    @Test func nEarlierReadsHowManyAndTheirProjectsAndWhetherItIsFolded() {
        #expect(Spoken.earlier(Earlier(projects: ["Kit", "Fumi", "Kit"], isOpen: false)) == "3 earlier, Kit, Fumi, folded")
        #expect(Spoken.earlier(Earlier(projects: ["Kit"], isOpen: true)) == "1 earlier, Kit")
    }

    @Test func aProjectsRowReadsAsAProject() {
        #expect(Spoken.project(Listed.Project(id: "kit", name: "Kit")) == "Kit, project")
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
