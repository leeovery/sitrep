import Foundation
@testable import SitRepCore
import SitRepLines
import enum SitRepPanel.BoardSection
@testable import SitRepWindow
import Testing

/// What VoiceOver reads of the window: words for its marks, counts and times, never their symbols.
struct SpokenTests {
    /// A row of Working or Your turn, its one line as given.
    private static func row(_ section: BoardSection, _ mark: Mark, _ line: Listed.Line) -> PlaceList.Row {
        .session(Listed.Row(
            id: "sr-macapp", name: "The Mac app", project: "SitRep", section: section, mark: mark, isAway: false,
            since: minutes(before: 300), lines: [line]
        ))
    }

    private static func said(_ lead: String, code: String? = nil, subject: String? = nil, until: Date? = nil) -> Listed.Line {
        Listed.Line(
            id: "turn:sr-macapp", lead: lead, code: code, subject: subject, until: until, more: nil,
            since: minutes(before: 300)
        )
    }

    /// A line of a session in Needs you, its session a window holds or not.
    private static func asking(_ words: String, isAway: Bool = false, since: Date = minutes(before: 90)) -> PlaceList.Row {
        let line = Listed.Line(id: "ask:sr-1:k1", ask: "k1", lead: words, code: nil, more: nil, since: since)
        let session = Listed.Row(
            id: "sr-1", name: "The bootstrap", project: "Kit", section: .needsYou, mark: .needs, isAway: isAway,
            since: minutes(before: 300), lines: [line]
        )

        return .line(PlaceList.LineRow(session: session, line: line))
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

    /// A line reads its own words, never its session's other lines, then its project and session, and its own age;
    /// away, it says so before its age.
    @Test(arguments: [false, true])
    func aLineReadsItsWordsItsProjectItsSessionAndItsAgeAndAwaySaysSo(isAway: Bool) {
        #expect(
            Spoken.row(Self.asking("Which edge?", isAway: isAway), at: printedAt)
                == (isAway ? "Which edge?, Kit, The bootstrap, away, 1 hour" : "Which edge?, Kit, The bootstrap, 1 hour")
        )
    }

    /// Over the real board: Switchboard's stop reads its own words, not its ask's beside it.
    @Test func aLineOfTheRealBoardReadsItsOwnWordsAlone() throws {
        let list = PlaceList(.needsYou, in: Listed(heard(line(0))))
        let stop = try #require(list.row(needsYouLines[0]))
        let age = Spoken.age(Date(timeIntervalSince1970: 1_792_486_361), at: printedAt)

        #expect(Spoken.row(stop, at: printedAt) == "Allow Bash gh pr create --draft --base main, Switchboard, Dashboard redesign, \(age)")
    }

    /// Every row of a session a window holds offers VoiceOver its button as an action, "Jump to the window", whatever
    /// its place; an away one, none.
    @Test func aRowAWindowHoldsOffersTheJumpAsAnActionAndAnAwayRowNone() {
        let working = Self.row(.working, .working, Self.said("Running", code: "swift test"))
        let turn = Self.row(.yourTurn, .turn, Self.said("Drawing round 3"))

        #expect([working, turn, Self.asking("Which edge?")].map(Spoken.jump) == Array(repeating: "Jump to the window", count: 3))
        #expect(Spoken.jump(Self.asking("Which edge?", isAway: true)) == nil)
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

    /// A place reads its name and its count in words: Needs you its lines waiting, Working and Your turn their
    /// sessions, Parked its items.
    @Test func aPlaceReadsItsNameAndItsCount() {
        #expect(Spoken.place(.needsYou, count: 4) == "Needs you, 4 waiting")
        #expect(Spoken.place(.yourTurn, count: 1) == "Your turn, 1 session")
        #expect(Spoken.place(.working, count: 3) == "Working, 3 sessions")
        #expect(Spoken.place(.parked, count: 12) == "Parked, 12 items")
    }

    /// A project reads as one, what waits on Lee there, and its sessions, but where it is quiet.
    @Test func aProjectsRowReadsWhatItsMarkAndCountSay() throws {
        let places = Places(Listed(heard(line(0))))
        let project = { (key: String) in try #require(places.projects.first { $0.id == key }) }

        #expect(Spoken.project(try project("switchboard")) == "Switchboard, project, needs you, 2 sessions")
        #expect(Spoken.project(try project("goosemates")) == "Goosemates, project, needs you, away, 1 session")
        #expect(Spoken.project(try project("kit")) == "Kit, project")
    }

    /// A fold reads how many, "N earlier" its projects too, and folded says so.
    @Test func aFoldReadsHowManyAndWhetherItIsFolded() throws {
        let snoozed = try #require(PlaceList(.needsYou, in: Listed(heard(.line(Lines.snoozed[0])))).fold)
        let earlier = try #require(PlaceList(.yourTurn, in: Self.earlier, isFoldOpen: true).fold)

        #expect(Spoken.fold(snoozed) == "2 snoozed, folded")
        #expect(Spoken.fold(earlier) == "1 earlier, Switchboard")
    }

    /// The first board, Request ledger's turn past the fold period.
    private static let earlier: Listed = {
        var listed = Listed(heard(line(0)))

        listed.changeRows { $0.isEarlier = $0.section == .yourTurn }
        return listed
    }()

    @Test func aHeadingReadsItsNameAndTheWordsOnItsRight() {
        #expect(Spoken.heading("Asks", note: "3 waiting") == "Asks, 3 waiting")
        #expect(Spoken.heading("Status", note: nil) == "Status")
    }

    @Test(arguments: [
        (Mark.needs, "needs you"), (.awayAsk, "needs you, away"), (.turn, "your turn"), (.working, "working"),
        (.onItsWork, "on its own work"), (.away, "away"), (.snoozed, "snoozed"),
    ])
    func aMarkReadsAsWhatItMeans(mark: Mark, words: String) {
        #expect(Spoken.mark(mark) == words)
    }
}
