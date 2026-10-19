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

    @Test func whileItIsOutAChangedRowChangesInPlace() {
        var rows = HeldRows()
        rows.take(Self.by("s1", "s2", "s3"))
        rows.hold(true)
        var answered = Self.by("s1")[0]
        answered.kind = .working
        answered.title = "Drawing the strip in Paper"

        let changed = rows.take(Self.by("s2", "s3") + [answered])

        #expect(changed)
        #expect(rows.shown == [answered] + Self.by("s2", "s3"))
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
