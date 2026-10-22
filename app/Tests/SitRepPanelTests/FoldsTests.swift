import CoreGraphics
import Foundation
@testable import SitRepPanel
import Testing

/// Rows folding in and out as they come and go, as the prototypes' do: only while the panel is out, over 260ms on
/// easeInOut (120 under reduced motion), a new one fading in over 220, one gone folding away where it was.
struct FoldsTests {
    private static func row(_ id: String) -> Item {
        .session(Session(id: id, project: "SitRep", kind: .turn, title: id, sub: "", since: 0))
    }

    private static let a = row("a"), b = row("b"), c = row("c")

    /// Folds holding these, taken while the panel was in.
    private static func folds(_ items: Item...) -> Folds {
        var folds = Folds()
        folds.take(items, at: 0, animating: false, reducesMotion: false)
        return folds
    }

    private static func keys(_ content: Content) -> [String] { content.items.map(\.key) }

    @Test func whileThePanelIsInAChangeShowsAtOnce() {
        var folds = Self.folds(Self.a, Self.b)

        folds.take([Self.a, Self.c], at: 1000, animating: false, reducesMotion: false)
        let content = folds.content(at: 1000)

        #expect(Self.keys(content) == ["a", "c"])
        #expect(content.entries.allSatisfy { $0.height == 59 && $0.alpha == 1 && !$0.isGoing })
        #expect(!folds.isMoving(at: 1000))
    }

    /// Keyed by its session, a row gaining a line while the panel is out neither folds away nor in again: it is the
    /// same row, at once its new height, the line's 22 more.
    @Test func aRowGainingALineIsTheSameRowAtItsNewHeight() {
        var folds = Self.folds(Self.a, Self.b)
        var asked = Self.a.session!

        asked.lines.append(Session.Line(title: "Another ask", since: 60_000))
        folds.take([.session(asked), Self.b], at: 1000, animating: true, reducesMotion: false)

        let content = folds.content(at: 1000)

        #expect(Self.keys(content) == ["a", "b"])
        #expect(content.entries.map(\.height) == [81, 59])
        #expect(content.entries.allSatisfy { $0.alpha == 1 && !$0.isGoing })
        #expect(!folds.isMoving(at: 1000))
    }

    @Test func aNewRowUnfoldsOver260msAndFadesInOver220() {
        var folds = Self.folds(Self.a)

        folds.take([Self.a, Self.b], at: 1000, animating: true, reducesMotion: false)

        let born = folds.content(at: 1000).entries[1]
        #expect(born.height == 0 && born.alpha == 0)
        let half = folds.content(at: 1130).entries[1]
        #expect(abs(half.height - 59 * 0.5) < 1e-9)
        #expect(abs(half.alpha - (1 - pow(1 - 130.0 / 220, 3))) < 1e-9)
        #expect(folds.content(at: 1220).entries[1].alpha == 1)
        #expect(folds.isMoving(at: 1259))
        #expect(folds.content(at: 1260).entries[1].height == 59)
        #expect(!folds.isMoving(at: 1260))
    }

    @Test func aRowGoneFoldsAwayWhereItWasFadingWithItsFold() {
        var folds = Self.folds(Self.a, Self.b, Self.c)

        folds.take([Self.a, Self.c], at: 1000, animating: true, reducesMotion: false)

        let going = folds.content(at: 1130)
        #expect(Self.keys(going) == ["a", "b", "c"])
        #expect(going.entries[1].isGoing)
        #expect(abs(going.entries[1].height - 29.5) < 1e-9)
        #expect(abs(going.entries[1].alpha - 0.5) < 1e-9)
        #expect(Self.keys(folds.content(at: 1260)) == ["a", "c"])
    }

    @Test func aRowGoneStaysUnderTheRowAboveItAsTheRestMove() {
        var folds = Self.folds(Self.a, Self.b, Self.c)

        folds.take([Self.c, Self.a], at: 1000, animating: true, reducesMotion: false)

        #expect(Self.keys(folds.content(at: 1000)) == ["c", "a", "b"])
    }

    @Test func aRowComingBackAsItFoldsAwayUnfoldsFromWhereItGot() {
        var folds = Self.folds(Self.a, Self.b)
        folds.take([Self.a], at: 1000, animating: true, reducesMotion: false)

        folds.take([Self.a, Self.b], at: 1130, animating: true, reducesMotion: false)

        let back = folds.content(at: 1260).entries[1]
        #expect(!back.isGoing)
        #expect(abs(back.height - 59 * 0.75) < 1e-9)
        #expect(back.alpha == 1)
    }

    @Test func theHairlineFoldsInAndOutAsARow() {
        var folds = Self.folds(Self.a)

        folds.take([Self.a, .divider, Self.b], at: 1000, animating: true, reducesMotion: false)

        let content = folds.content(at: 1130)
        #expect(Self.keys(content) == ["a", "divider", "b"])
        #expect(abs(content.entries[1].height - 9 * 0.5) < 1e-9)
    }

    @Test func underReducedMotionAFoldTakes120AndANewRowDoesNotFade() {
        var folds = Self.folds(Self.a)

        folds.take([Self.a, Self.b], at: 1000, animating: true, reducesMotion: true)

        let half = folds.content(at: 1060).entries[1]
        #expect(abs(half.height - 29.5) < 1e-9)
        #expect(half.alpha == 1)
        #expect(!folds.isMoving(at: 1120))
    }

    @Test func aRowFoldingAwayTakesNoClickNorHover() {
        var folds = Self.folds(Self.a, Self.b)
        folds.take([Self.b], at: 1000, animating: true, reducesMotion: false)

        let content = folds.content(at: 1000)

        #expect(!content.entries[0].jumps)
        #expect(content.entries[1].jumps)
        #expect(content.row(at: content.itemFrame(0).origin.applying(.init(translationX: 1, y: 1))) == nil)
    }
}
