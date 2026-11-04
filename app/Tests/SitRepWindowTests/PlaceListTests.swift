import Foundation
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// A place's list, the middle column: Needs you a row per line, Working and Your turn a row per session, each with
/// its fold; filtered, its position, and ↑/↓ through it.
struct PlaceListTests {
    /// SitRep's three asks (k2, k3, k1, oldest first), Switchboard's ask and stop, Goosemates' away ask; Request ledger
    /// on Lee's turn.
    private static let listed = Listed(heard(line(0)))
    private static let needsYou = PlaceList(.needsYou, in: listed)

    private static let k2 = ListPick.line("ask:sr-macapp:k2")
    private static let k3 = ListPick.line("ask:sr-macapp:k3")
    private static let k1 = ListPick.line("ask:sr-macapp:k1")
    private static let dash = ListPick.line("ask:sr-dash02:k1")
    private static let stop = ListPick.line("stop:sr-dash02:w2:1792486361000")
    private static let goose = ListPick.line("ask:sr-gs7kq2:k1")

    // MARK: Needs you

    /// SitRep's oldest two, then Switchboard's ask, older than SitRep's third, then the stop; Goosemates' ask, the
    /// oldest of all, last, as no window holds its session.
    @Test func needsYouIsARowPerLineOldestFirstLiveBeforeAway() {
        #expect(Self.needsYou.picks == [Self.k2, Self.k3, Self.dash, Self.k1, Self.stop, Self.goose])
        #expect(Self.needsYou.rows.map(\.session) == [
            "sr-macapp", "sr-macapp", "sr-dash02", "sr-macapp", "sr-dash02", "sr-gs7kq2",
        ])
    }

    @Test func aLineRowCarriesItsSessionsNamesAndMarkAndItsOwnWords() throws {
        let goose = try #require(Self.needsYou.row(Self.goose)?.line)
        let stop = try #require(Self.needsYou.row(Self.stop)?.line)

        #expect(goose.session.name == "Settle the older open questions")
        #expect(goose.session.project == "Goosemates")
        #expect(goose.session.mark == .awayAsk)
        #expect(goose.session.isAway)
        #expect(stop.line.words == "Allow Bash gh pr create --draft --base main")
        #expect(stop.session.mark == .needs)
    }

    /// Harness's k3 waits; k1 and k2 are asleep, k1 waking first: "2 snoozed" at the foot, folded until it opens.
    @Test func needsYouEndsInNSnoozedWhichOpensInPlace() throws {
        let listed = Listed(heard(.line(Lines.snoozed[0])))
        let folded = PlaceList(.needsYou, in: listed)
        let open = PlaceList(.needsYou, in: listed, isFoldOpen: true)
        let fold = try #require(folded.fold)
        let z1 = ListPick.snoozed("ask:sr-4g01a7:k1"), z2 = ListPick.snoozed("ask:sr-4g01a7:k2")

        #expect(fold.kind == .snoozed)
        #expect(fold.title == "2 snoozed")
        #expect(folded.items.map(\.id) == [.pick(.line("ask:sr-4g01a7:k3")), .fold(.snoozed)])
        #expect(folded.picks == [.line("ask:sr-4g01a7:k3")])
        #expect(open.picks == [.line("ask:sr-4g01a7:k3"), z1, z2])
        #expect(open.items.map(\.id) == [.pick(.line("ask:sr-4g01a7:k3")), .fold(.snoozed), .pick(z1), .pick(z2)])
        #expect(open.row(z1)?.session == "sr-4g01a7")
    }

    /// Across sessions, the asleep soonest to wake come first, then the oldest of those waking together.
    @Test func snoozedRowsAreTheSoonestToWakeFirstThenTheOldest() {
        var one = Built(id: "s1", project: "northwind")
        var two = Built(id: "s2", project: "contoso")

        one.snoozed = [(age: 30, wakesIn: 60), (age: 40, wakesIn: 10)]
        two.snoozed = [(age: 50, wakesIn: 60), (age: 20, wakesIn: 30)]

        let fold = PlaceList(.needsYou, in: Built.listed([one, two]), isFoldOpen: true).fold

        #expect(fold?.rows.map(\.pick) == [
            .snoozed(one.asleep(1)), .snoozed(two.asleep(1)), .snoozed(two.asleep(0)), .snoozed(one.asleep(0)),
        ])
        #expect(fold?.rows.map { $0.line?.session.mark } == [.snoozed, .snoozed, .snoozed, .snoozed])
    }

    @Test func withNothingAsleepNeedsYouHasNoFold() {
        #expect(Self.needsYou.fold == nil)
        #expect(Self.needsYou.items.count == 6)
    }

    // MARK: Working and Your turn

    @Test func workingAndYourTurnAreARowPerSessionInCoresOrder() {
        let listed = Listed(heard(.line(Lines.bySession[0])))

        #expect(PlaceList(.working, in: listed).picks == [.session("sr-macapp"), .session("sr-k7bt2s")])
        #expect(PlaceList(.yourTurn, in: listed).picks == [.session("sr-v3t7a0")])
        #expect(PlaceList(.working, in: listed).fold == nil)
    }

    /// Your turn's rows past the fold period sit under "N earlier" at its foot, shown only while it is open.
    @Test func yourTurnsEarlierRowsFoldUnderNEarlier() throws {
        let turns = (1 ... 3).map { Built(id: "t\($0)", project: "northwind", state: .yourTurn, turn: Double(60 * $0)) }
        let all: [ListPick] = [.session("t1"), .session("t2"), .session("t3")]
        var listed = Built.listed(turns)

        listed.changeRows { $0.isEarlier = $0.since < minutes(before: 90) }

        let folded = PlaceList(.yourTurn, in: listed)
        let fold = try #require(folded.fold)

        #expect(folded.rows.map(\.pick) == [.session("t1")])
        #expect(fold.kind == .earlier)
        #expect(fold.title == "2 earlier")
        #expect(fold.earlier == Earlier(projects: ["Northwind", "Northwind"], isOpen: false))
        #expect(folded.picks == [.session("t1")])
        #expect(PlaceList(.yourTurn, in: listed, isFoldOpen: true).picks == all)
    }

    /// Parked's list comes with the parked items on `watch`'s line: for now it lists nothing.
    @Test func parkedListsNothingYet() {
        #expect(PlaceList(.parked, in: Self.listed).isEmpty)
    }

    // MARK: The filter

    /// A line stays while every word appears in its session's name, its project's or its own words: only SitRep's
    /// line and Switchboard's that speak of the load test, not their sessions' other lines.
    @Test func theFilterKeepsALineByItsOwnWordsAndItsSessionsNames() {
        let filtered = { (text: String) in PlaceList(.needsYou, in: Self.listed, filter: Filter(text)).picks }

        #expect(filtered("load TEST") == [Self.k3, Self.dash])
        #expect(filtered("switchboard") == [Self.dash, Self.stop])
        #expect(filtered("mac app") == [Self.k2, Self.k3, Self.k1])
        #expect(filtered("gh pr") == [Self.stop])
        #expect(filtered("nowhere").isEmpty)
    }

    @Test func theFilterKeepsASessionsRowByTodaysRule() {
        let filtered = { (text: String) in PlaceList(.yourTurn, in: Self.listed, filter: Filter(text)) }

        #expect(filtered("ledger schema").picks == [.session("sr-rq7dgr")])
        #expect(filtered("goosemates").isEmpty)
    }

    /// While the filter holds text the fold shows open, with only what matches; with nothing matching, it goes.
    @Test func theFilterOpensTheFoldOnItsMatchesOnly() throws {
        let listed = Listed(heard(.line(Lines.snoozed[0])))
        let stage = PlaceList(.needsYou, in: listed, filter: Filter("stage 2"))
        let fold = try #require(stage.fold)

        #expect(stage.rows.isEmpty)
        #expect(fold.isOpen)
        #expect(fold.title == "1 snoozed")
        #expect(stage.picks == [.snoozed("ask:sr-4g01a7:k2")])
        #expect(PlaceList(.needsYou, in: listed, filter: Filter("stage 3")).fold == nil)
    }

    // MARK: Position

    @Test func aPicksPositionCountsTheRowsShown() {
        #expect(Self.needsYou.position(of: Self.k2)?.text == "1 / 6")
        #expect(Self.needsYou.position(of: Self.goose)?.text == "6 / 6")
        #expect(Self.needsYou.position(of: .line("ask:sr-gone:k1")) == nil)
        #expect(Self.needsYou.position(of: nil) == nil)
    }

    /// An open fold's rows are shown, so counted; a closed one's are not.
    @Test func anOpenFoldsRowsCountInThePosition() {
        let listed = Listed(heard(.line(Lines.snoozed[0])))
        let open = PlaceList(.needsYou, in: listed, isFoldOpen: true)

        #expect(PlaceList(.needsYou, in: listed).position(of: .line("ask:sr-4g01a7:k3"))?.text == "1 / 1")
        #expect(open.position(of: .snoozed("ask:sr-4g01a7:k2"))?.text == "3 / 3")
    }

    // MARK: ↑ and ↓

    private static func step(_ list: PlaceList, from pick: ListPick?, down: Bool) -> ListPick? {
        list.step(from: ListSpot(pick, in: list), down: down)
    }

    @Test func anArrowGoesToTheRowAfterOrBeforeThePick() {
        #expect(Self.step(Self.needsYou, from: Self.dash, down: true) == Self.k1)
        #expect(Self.step(Self.needsYou, from: Self.dash, down: false) == Self.k3)
    }

    /// Up is dimmed on the first row, and down on the last.
    @Test func noRowLiesBeyondTheEnds() {
        #expect(Self.step(Self.needsYou, from: Self.k2, down: false) == nil)
        #expect(Self.step(Self.needsYou, from: Self.goose, down: true) == nil)
    }

    @Test func withNothingPickedDownGoesToTheFirstRowAndUpNowhere() {
        #expect(Self.step(Self.needsYou, from: nil, down: true) == Self.k2)
        #expect(Self.step(Self.needsYou, from: nil, down: false) == nil)
        #expect(Self.step(PlaceList(.working, in: Self.listed), from: nil, down: true) == nil)
    }

    /// A closed fold is no row: down from the last line goes nowhere; open, down goes into its rows.
    @Test func anArrowPassesOverAClosedFoldAndIntoAnOpenOnesRows() {
        let listed = Listed(heard(.line(Lines.snoozed[0])))
        let k3 = ListPick.line("ask:sr-4g01a7:k3")
        let open = PlaceList(.needsYou, in: listed, isFoldOpen: true)

        #expect(Self.step(PlaceList(.needsYou, in: listed), from: k3, down: true) == nil)
        #expect(Self.step(open, from: k3, down: true) == .snoozed("ask:sr-4g01a7:k1"))
    }

    /// Northwind's two lines, 30 and 20 minutes old, and Contoso's, 25: Contoso's is picked, then answered.
    private static let northwind = Built(id: "s1", project: "northwind", waiting: [30, 20])
    private static let contoso = Built(id: "s2", project: "contoso", waiting: [25])

    private static func needsYou(_ sessions: Built...) -> PlaceList {
        PlaceList(.needsYou, in: Built.listed(sessions))
    }

    private static func answered(_ session: Built) -> Built {
        var answered = session

        answered.waiting = []
        answered.state = .yourTurn
        return answered
    }

    /// Section 2's rule: the picked ask answered, nothing is picked, and ↓ goes to the row after it, ↑ to the one
    /// before.
    @Test func aPickThatLeftTheListStandsWhereItWas() {
        let before = Self.needsYou(Self.northwind, Self.contoso)
        let picked = ListPick.line(Self.contoso.line(0))
        let spot = ListSpot(picked, in: before)
        let after = Self.needsYou(Self.northwind, Self.answered(Self.contoso))

        #expect(before.picks == [.line(Self.northwind.line(0)), picked, .line(Self.northwind.line(1))])
        #expect(after.position(of: picked) == nil)
        #expect(after.row(picked) == nil)
        #expect(after.step(from: spot, down: true) == .line(Self.northwind.line(1)))
        #expect(after.step(from: spot, down: false) == .line(Self.northwind.line(0)))
    }

    /// Taking each list as it shows keeps the spot up to date: a line come in just above the pick since it was made
    /// is what ↑ goes to once the pick leaves.
    @Test func aSpotTakesEachListAsItShows() {
        let fabrikam = Built(id: "s3", project: "fabrikam", waiting: [27])
        let picked = ListPick.line(Self.contoso.line(0))
        var spot = ListSpot(picked, in: Self.needsYou(Self.northwind, Self.contoso))

        spot.take(Self.needsYou(Self.northwind, Self.contoso, fabrikam))

        let after = Self.needsYou(Self.northwind, Self.answered(Self.contoso), fabrikam)

        #expect(after.picks == [.line(Self.northwind.line(0)), .line(fabrikam.line(0)), .line(Self.northwind.line(1))])
        #expect(after.step(from: spot, down: false) == .line(fabrikam.line(0)))
        #expect(after.step(from: spot, down: true) == .line(Self.northwind.line(1)))
    }

    /// With every row above it gone, it stands at the top: ↓ to the first row, ↑ nowhere.
    @Test func aPickWhoseRowsAboveAllLeftStandsAtTheTop() {
        let spot = ListSpot(.line(Self.northwind.line(1)), in: Self.needsYou(Self.northwind, Self.contoso))
        let answered = [Self.answered(Self.northwind), Self.answered(Self.contoso)]
        let fabrikam = Built(id: "s4", project: "fabrikam", waiting: [5])
        let empty = PlaceList(.needsYou, in: Built.listed(answered))
        let later = PlaceList(.needsYou, in: Built.listed(answered + [fabrikam]))

        #expect(empty.step(from: spot, down: true) == nil)
        #expect(later.step(from: spot, down: true) == .line(fabrikam.line(0)))
        #expect(later.step(from: spot, down: false) == nil)
    }

    /// A snoozed row picked, then its fold closed: the fold holds it, and it stands after the last line.
    @Test func aPickAFoldClosedOverStandsAboveTheFold() {
        let listed = Listed(heard(.line(Lines.snoozed[0])))
        let z2 = ListPick.snoozed("ask:sr-4g01a7:k2")
        let spot = ListSpot(z2, in: PlaceList(.needsYou, in: listed, isFoldOpen: true))
        let closed = PlaceList(.needsYou, in: listed)

        #expect(closed.folds(z2))
        #expect(!closed.folds(.line("ask:sr-4g01a7:k3")))
        #expect(closed.step(from: spot, down: false) == .line("ask:sr-4g01a7:k3"))
        #expect(closed.step(from: spot, down: true) == nil)
    }

    // MARK: Lee's board

    /// 13 lines of 7 live sessions, oldest first, then the 2 away asks, oldest first; ↓ from nothing walks every row
    /// once, to the last.
    @Test func aBoardTheSizeOfLeesListsAndStepsEveryLine() throws {
        let list = PlaceList(.needsYou, in: Built.listed(Built.leesSize))
        let ages = list.rows.compactMap(\.line).map { ($0.session.isAway, $0.line.since) }
        var walked: [ListPick] = []
        var spot = ListSpot(in: list)

        while let next = list.step(from: spot, down: true) {
            walked.append(next)
            spot = ListSpot(next, in: list)
        }

        #expect(list.rows.count == 15)
        #expect(ages.map(\.0) == Array(repeating: false, count: 13) + [true, true])
        #expect(ages.prefix(13).map(\.1) == ages.prefix(13).map(\.1).sorted())
        #expect(ages.suffix(2).map(\.1) == ages.suffix(2).map(\.1).sorted())
        #expect(walked == list.picks)
        #expect(list.position(of: walked.last)?.text == "15 / 15")
        #expect(PlaceList(.working, in: Built.listed(Built.leesSize)).rows.count == 6)
        #expect(PlaceList(.yourTurn, in: Built.listed(Built.leesSize)).rows.count == 6)
    }
}

extension PlaceList.Row {
    /// The line it is, where it is one.
    var line: PlaceList.LineRow? {
        if case let .line(line) = self {
            return line
        }
        return nil
    }
}
