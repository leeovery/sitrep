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

    @Test func whileItIsOutARowGoneLeaves() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)

        rows.take(Self.by("s3", "s1"))

        #expect(Self.ids(rows) == ["s1", "s3"])
    }

    @Test func whileItIsOutANewRowComesInUnderTheRowCoreHasAboveIt() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)

        rows.take(Self.by("s3", "s1", "s7", "s4", "s2"))

        #expect(Self.ids(rows) == ["s1", "s7", "s4", "s2", "s3"])
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
