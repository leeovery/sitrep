import AppKit
@testable import SitRep
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow on a strip's tab (DESIGN, "Answering from the panel", the strip): a tab whose session has an ask the
/// asks panel answers is wider by the arrow's room, the arrow 40 by 26 at its front end, its right on the left edge and
/// its left on the right, its words and its time laid out in the rest as they would be without it; unlit a soft
/// chevron, lit filled, turned while the asks panel is open beside the tab, hidden while a click presses the tab in.
@MainActor
@Suite(.backstop)
struct StripTabArrowTests {
    private static let size = CGSize(width: 300, height: 52)
    private static let helpDesk = Session(
        id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, ask: "k1",
        title: "Thread replies, or keep them flat?", sub: "Northwind", since: 0
    )
    private static let turn = Session(
        id: "sr-ts0004", project: "Tailspin", kind: .turn, title: "Onboarding flow", sub: "Tailspin", since: 0
    )

    private static var note: StripNote {
        var note = StripNote()

        note.arrows = [helpDesk.id, turn.id]
        return note
    }

    private static func mirror(right: Bool) -> CGAffineTransform {
        right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: Strip.depth, ty: 0) : .identity
    }

    /// A session needing Lee with an ask the asks panel answers takes the arrow; Lee's turn, or a session the board
    /// lists no such ask for, takes none, though it needs Lee.
    @Test func onlyASessionNeedingLeeWithAnAskTheAsksPanelAnswersTakesTheArrow() {
        #expect(Self.note.hasArrow(Self.helpDesk))
        #expect(!Self.note.hasArrow(Self.turn))
        #expect(!StripNote().hasArrow(Self.helpDesk))
    }

    /// Its tab is wider by the arrow's room, the arrow and its inset, and 8 between it and the time on the left edge.
    @Test func itsTabIsWiderByTheArrowsRoom() {
        let with = StripWordsLayer.measure { Self.note }, without = StripWordsLayer.measure { StripNote() }

        #expect(with.row(Self.helpDesk) - without.row(Self.helpDesk) == StripRowLayout.arrowRoom)
        #expect(with.row(Self.turn) == without.row(Self.turn))
        #expect(StripRowLayout.arrowRoom == RowArrow.inset + RowArrow.size.width + 8 - StripRowLayout.pad.right)
    }

    /// The arrow at the tab's front end; the words and the time laid out in the room it leaves, as a tab as wide as
    /// that room would lay them: on the left edge where they would be, on the right edge moved past the arrow.
    @Test(arguments: [false, true])
    func theArrowIsAtTheFrontEndAndTheWordsAndTheTimeKeepTheirLayout(right: Bool) throws {
        let room = StripRowLayout.arrowRoom
        let with = StripRowLayout(Self.helpDesk, note: Self.note, in: Self.size, now: 0, pointsLeft: right)
        let without = StripRowLayout(
            Self.helpDesk, note: StripNote(), in: CGSize(width: Self.size.width - room, height: 52), now: 0
        )
        let arrow = try #require(with.arrow), dx = right ? CGFloat(room) : 0

        #expect(arrow == RowArrow.tabBox(in: Self.size, pointsLeft: right))
        #expect(with.title == without.title.offsetBy(dx: dx, dy: 0) && with.age == without.age.offsetBy(dx: dx, dy: 0))
        if right {
            #expect(with.title.minX - arrow.maxX == 6)
        } else {
            #expect(arrow.minX - with.age.maxX == 8)
        }
    }

    /// Drawn: hidden until it shows; lit, filled #34343B at its place, its chevron white, the time still drawn; hidden
    /// while a click presses the tab in.
    @Test(arguments: [false, true])
    func itDrawsAtItsPlaceLitOrNotAndHidesAsTheTabPressesIn(right: Bool) throws {
        let scene = Self.scene(right: right), words = Self.words(pressed: false)
        let layer = StripWordsLayer(words, in: CGRect(origin: .zero, size: Self.size), scene)
        let box = RowArrow.tabBox(in: Self.size, pointsLeft: right)
        let lit = ArrowButton.Look(isLit: true, pointsLeft: right)
        let fill = CGPoint(x: box.minX + 4, y: box.midY)

        layer.show(words, in: CGRect(origin: .zero, size: Self.size), hover: nil, arrow: nil, now: 0)
        #expect(!Self.isClose(try Drawn(layer.layer).stored(at: fill), 0x34343B))

        layer.show(words, in: CGRect(origin: .zero, size: Self.size), hover: nil, arrow: lit, now: 0)

        let drawn = try Drawn(layer.layer)
        let age = StripRowLayout(Self.helpDesk, note: Self.note, in: Self.size, now: 0, pointsLeft: right).ageBox

        #expect(Self.isClose(drawn.stored(at: fill), 0x34343B))
        #expect(try drawn.brightest(in: box).lightness > 0.9)
        #expect(try drawn.brightest(in: age).lightness > 0.2)

        let pressed = Self.words(pressed: true)

        layer.show(pressed, in: CGRect(origin: .zero, size: Self.size), hover: nil, arrow: lit, now: 0)
        #expect(!Self.isClose(try Drawn(layer.layer).stored(at: fill), 0x34343B))
    }

    /// The scene's arrow on the tab's words: lit as the run says, pointing away from the edge, and turned while the
    /// asks panel is open beside the tab; none on another session's words.
    @Test(arguments: [false, true])
    func theScenesArrowPointsAwayFromTheEdgeAndTurnsWhileTheAsksPanelIsOpen(right: Bool) {
        let layout = AsksLayout(PanelAsk(id: "k1", title: "Ship it?", wants: .yes, answers: ["Ship"], since: 0),
                                measure: .estimated)
        let asks = AsksShown(
            row: Self.helpDesk.markID, session: Self.helpDesk, ask: PanelAsk(
                id: "k1", title: "Ship it?", wants: .yes, answers: ["Ship"], since: 0
            ), page: 0, pages: 1, layout: layout, frame: .zero, sending: nil, hover: nil
        )
        var scene = Self.scene(right: right)

        scene.arrow = (Self.helpDesk.markID, true)
        #expect(scene.arrow(on: Self.words(pressed: false)) == ArrowButton.Look(isLit: true, pointsLeft: right))
        scene.asks = asks
        #expect(scene.arrow(on: Self.words(pressed: false))?.isTurned == true)
        #expect(scene.arrow(on: Self.words(of: Self.turn)) == nil)
    }

    private static func scene(right: Bool) -> StripScene {
        let resting = StripScene.resting()

        return StripScene(
            frame: resting.frame, hoverRow: nil, note: note, now: 0, mirror: mirror(right: right), menu: 37,
            reducesMotion: false
        )
    }

    private static func words(of session: Session = helpDesk, pressed: Bool) -> StripFrame.Words {
        StripFrame.Words(
            id: 1, key: .session(session.markID), content: .row(session), frame: CGRect(origin: .zero, size: size),
            scroll: 0, alpha: 1, dy: 0, isPressed: pressed, pressedRow: nil
        )
    }

    private static func words(of session: Session) -> StripFrame.Words {
        words(of: session, pressed: false)
    }

    /// Whether a stored pixel is this colour, to within 3 levels of 8 bits in each channel.
    private static func isClose(_ colour: NSColor?, _ hex: UInt32) -> Bool {
        guard let colour else {
            return false
        }

        let wanted = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) }
        let got = [colour.redComponent, colour.greenComponent, colour.blueComponent].map { $0 * 255 }

        return zip(got, wanted).allSatisfy { abs($0 - $1) <= 3 }
    }
}
