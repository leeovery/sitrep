@testable import SitRepPanel
import Testing

/// Core orders the rows; the panel decides only when a new order shows: at once while it is in, and once it is in
/// again after it was out.
struct HeldRowsTests {
    private static let sessions = Item.prototype.compactMap(\.session)

    private static func ids(_ rows: HeldRows) -> [String] { rows.shown.map(\.id) }

    private static func by(_ ids: String...) -> [Session] {
        ids.map { id in sessions.first { $0.id == id }! }
    }

    /// Needs you together over the hairline: the hairline right under the last of them.
    private static func needsYouIsTogether(_ rows: HeldRows) -> Bool {
        Item.list(rows.shown).firstIndex(of: .divider) == rows.shown.count(where: \.needsLee)
    }

    /// Held while the panel is out, then this board taken.
    private static func held(_ shown: [Session], taking board: [Session]) -> HeldRows {
        var rows = HeldRows()
        rows.take(shown)
        rows.hold(true)
        rows.take(board)
        return rows
    }

    private static func away(_ session: Session, _ isAway: Bool = true) -> Session {
        var session = session
        session.away = isAway
        return session
    }

    private static func answered(_ session: Session) -> Session {
        var session = session
        session.kind = .turn
        session.title = "Your turn"
        return session
    }

    @Test func whileThePanelIsInTheRowsShowInCoresOrderAtOnce() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))

        let changed = rows.take(Self.by("s3", "s1", "s2"))

        #expect(changed)
        #expect(Self.ids(rows) == ["s3", "s1", "s2"])
    }

    @Test func theSameBoardAgainChangesNothing() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2"))

        let changed = rows.take(Self.by("s1", "s2"))

        #expect(!changed)
    }

    @Test func whileItIsOutARowCoreMovesKeepsItsPlace() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)

        let changed = rows.take(Self.by("s3", "s1", "s2"))

        #expect(!changed)
        #expect(Self.ids(rows) == ["s1", "s2", "s3"])
    }

    /// Your turn to working is a change within a section: in place.
    @Test func whileItIsOutAChangedRowChangesInPlace() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3", "s4"))
        rows.hold(true)
        var prompted = Self.by("s3")[0]
        prompted.kind = .working
        prompted.title = "Drawing the strip in Paper"

        let changed = rows.take(Self.by("s1", "s2", "s4") + [prompted])

        #expect(changed)
        #expect(rows.shown == Self.by("s1", "s2") + [prompted] + Self.by("s4"))
    }

    /// A place is held within its section: a row coming to need Lee, from your turn or from working, leaves its place
    /// for one in needs you, under the needs you core has above it, so needs you stays together over the hairline.
    @Test(arguments: ["s3", "s4"])
    func whileItIsOutARowComingToNeedLeeTakesItsPlaceInNeedsYou(id: String) {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3", "s4", "s5"))
        rows.hold(true)
        var asking = Self.by(id)[0]
        asking.kind = .needs
        asking.title = "Approve the plan"
        let rest = Self.by("s3", "s4", "s5").filter { $0.id != id }

        rows.take(Self.by("s1") + [asking] + Self.by("s2") + rest)

        #expect(Self.ids(rows) == ["s1", id, "s2"] + rest.map(\.id))
        #expect(Item.list(rows.shown).firstIndex(of: .divider) == 3)
    }

    /// A needs you whose asks are answered leaves its place there, the first or one between, for its place among the
    /// rest, under the row core has above it: needs you stays together over the hairline.
    @Test(arguments: ["s1", "s2"])
    func whileItIsOutANeedsYouAnsweredLeavesNeedsYouTogether(id: String) {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s7", "s3", "s4"))
        rows.hold(true)
        var answered = Self.by(id)[0]
        answered.kind = .turn
        answered.title = "Your turn"
        let needs = Self.by("s1", "s2", "s7").filter { $0.id != id }

        rows.take(needs + Self.by("s4") + [answered] + Self.by("s3"))

        #expect(Self.ids(rows) == needs.map(\.id) + ["s3", "s4", id])
        #expect(Item.list(rows.shown).firstIndex(of: .divider) == 2)
    }

    /// A row is its session: one gaining a line, as a second ask comes, is the same row, changed in its place.
    @Test func whileItIsOutARowGainingALineKeepsItsPlace() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)
        var asked = Self.by("s2")[0]
        asked.lines.insert(Session.Line(title: "An older ask", since: asked.since - 60_000), at: 0)

        let changed = rows.take([asked] + Self.by("s1", "s3"))

        #expect(changed)
        #expect(Self.ids(rows) == ["s1", "s2", "s3"])
        #expect(rows.shown[1].lines.count == 2)
    }

    /// Each section is held on its own: s1 going away, which core sorts last in needs you, keeps its place there, and a
    /// your turn new to the board comes in at the top of the rest, where core has nothing above it, never under s1.
    @Test func whileItIsOutANewRowAmongTheRestComesInThereThoughNeedsYouMoved() {
        let s1 = Self.away(Self.by("s1")[0])

        let rows = Self.held(Self.by("s1", "s2", "s3"), taking: Self.by("s2") + [s1] + Self.by("s6", "s3"))

        #expect(Self.ids(rows) == ["s1", "s2", "s6", "s3"])
        #expect(Self.needsYouIsTogether(rows))
    }

    /// Core orders needs you anew, s7 first, as s1 is answered: needs you keeps its held order, and s1 comes in among
    /// the rest under s4, the row core has above it there.
    @Test func whileItIsOutAnAnsweredRowComesInAmongTheRestThoughNeedsYouMoved() {
        let s1 = Self.answered(Self.by("s1")[0])

        let rows = Self.held(Self.by("s1", "s2", "s7", "s3", "s4"), taking: Self.by("s7", "s2", "s4") + [s1] + Self.by("s3"))

        #expect(Self.ids(rows) == ["s2", "s7", "s3", "s4", "s1"])
        #expect(Self.needsYouIsTogether(rows))
    }

    /// A session new to the board that core puts first among the rest comes in at their top, though core's needs you
    /// above it is in another order than the one held.
    @Test func whileItIsOutANewRowCorePutsFirstAmongTheRestComesInAtTheirTop() {
        let rows = Self.held(Self.by("s1", "s2", "s3"), taking: Self.by("s2", "s1", "s6", "s3"))

        #expect(Self.ids(rows) == ["s1", "s2", "s6", "s3"])
        #expect(Self.needsYouIsTogether(rows))
    }

    /// s7's window comes back, which core sorts first in needs you, while s2 is answered and comes first among the
    /// rest: needs you keeps its held order, and s2 comes in at the top of the rest.
    @Test func whileItIsOutAnAwayRowReturningAsAnotherCrossesKeepsNeedsYouTogether() {
        let s7 = Self.away(Self.by("s7")[0], false), s2 = Self.answered(Self.by("s2")[0])

        let rows = Self.held(Self.by("s1", "s2", "s7", "s3"), taking: [s7] + Self.by("s1") + [s2] + Self.by("s3"))

        #expect(Self.ids(rows) == ["s1", "s7", "s2", "s3"])
        #expect(Self.needsYouIsTogether(rows))
    }

    @Test func whileItIsOutARowGoneLeaves() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)

        rows.take(Self.by("s3", "s1"))

        #expect(Self.ids(rows) == ["s1", "s3"])
    }

    /// Within its section: s7 under s1 in needs you, s4 under s3 among the rest.
    @Test func whileItIsOutANewRowComesInUnderTheRowCoreHasAboveIt() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)

        rows.take(Self.by("s1", "s7", "s2", "s3", "s4"))

        #expect(Self.ids(rows) == ["s1", "s7", "s2", "s3", "s4"])
    }

    @Test func whileItIsOutANewRowCoreHasFirstComesInFirst() {
        var rows = HeldRows()
        rows.take(Self.by("s2", "s3"))
        rows.hold(true)

        rows.take(Self.by("s1", "s3", "s2"))

        #expect(Self.ids(rows) == ["s1", "s2", "s3"])
    }

    @Test func asItGoesInTheRowsTakeCoresOrder() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)
        rows.take(Self.by("s3", "s1", "s2"))

        let changed = rows.hold(false)

        #expect(changed)
        #expect(Self.ids(rows) == ["s3", "s1", "s2"])
    }

    @Test func goingInWithNothingChangedChangesNothing() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2"))
        rows.hold(true)

        let changed = rows.hold(false)

        #expect(!changed)
    }
}
