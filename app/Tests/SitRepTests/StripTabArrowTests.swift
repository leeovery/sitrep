import AppKit
@testable import SitRep
import SitRepCore
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

        #expect(abs(with.row(Self.helpDesk) - without.row(Self.helpDesk) - StripRowLayout.arrowRoom) < 1e-9)
        #expect(with.row(Self.turn) == without.row(Self.turn))
        #expect(StripRowLayout.arrowRoom == RowArrow.fromFront + RowArrow.size.width + 8 - StripRowLayout.pad.right)
        #expect(StripRowLayout.arrowRoom == 51)
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

    /// Once shown, it stays with its words as they fade out of a tab drawing back or gliding on, where the scene gives
    /// them no arrow any more: it never pops off ahead of them.
    @Test(arguments: [false, true])
    func onceShownItFadesWithItsWords(right: Bool) throws {
        let words = Self.words(pressed: false), frame = CGRect(origin: .zero, size: Self.size)
        let layer = StripWordsLayer(words, in: frame, Self.scene(right: right))
        let box = RowArrow.tabBox(in: Self.size, pointsLeft: right), fill = CGPoint(x: box.minX + 4, y: box.midY)

        layer.show(words, in: frame, hover: nil, arrow: ArrowButton.Look(isLit: true, pointsLeft: right), now: 0)
        layer.show(words, in: frame, hover: nil, arrow: nil, now: 0)
        #expect(Self.isClose(try Drawn(layer.layer).stored(at: fill), 0x34343B))
        layer.show(Self.words(pressed: false, alpha: 0.5), in: frame, hover: nil, arrow: nil, now: 0)
        #expect(layer.layer.opacity == 0.5)
    }

    /// Its words are laid out again as their own session's arrow comes or goes, though nothing else they say changes;
    /// another session's arrow leaves them as they are.
    @Test func itsWordsAreLaidOutAgainAsTheirSessionsArrowComesOrGoes() {
        let layer = StripWordsLayer(Self.words(pressed: false), in: CGRect(origin: .zero, size: Self.size), Self.scene())
        var other = Self.note, none = Self.note

        other.arrows.remove(Self.turn.id)
        none.arrows.remove(Self.helpDesk.id)
        #expect(layer.says(Self.scene(note: other)))
        #expect(!layer.says(Self.scene(note: none)))
    }

    /// A run over the board with the drawing's measure: the tab of a session asking is wider by the arrow's room, and
    /// gives it back once the board leaves its ask out though its row stays, or its last ask's answer goes.
    @Test(arguments: [false, true])
    func theTabIsWiderByTheArrowsRoomUntilItsArrowGoes(byAnswer: Bool) throws {
        let setting = StripRun.Setting(stage: StripStage(width: 1512, height: 982, menu: 37), reducesMotion: false)
        let run = StripRun(at: 1000, in: setting, EdgeSettings(), measure: StripWordsLayer.measure)
        let board = NotchAsksWindowTests.board(named: "Help desk redesign, round two")
        var time = 1000.0
        let frames = { (ms: Double) in
            let end = time + ms

            while time < end {
                let mark = CGPoint(x: 18, y: run.strip.yOf(.session("sr-nw0001")))

                time += 1000.0 / 60
                run.step(StripRun.Moment(time: time, pointer: mark, setting: setting))
            }
        }

        run.show(board, StripRun.Moment(time: time, pointer: nil, setting: setting))
        frames(3000)

        let wide = try #require(run.frame.tabs.first { $0.isLive }).box.width

        #expect(run.arrow(in: setting) != nil)
        if byAnswer {
            let threaded = Answering(.words("Threaded"), to: "k1", of: "sr-nw0001", wanting: .choice)

            run.heard(.went(threaded), StripRun.Moment(time: time, pointer: nil, setting: setting))
        } else {
            run.show(PanelBoard(rows: board.sessions), StripRun.Moment(time: time, pointer: nil, setting: setting))
        }
        frames(3000)

        let narrow = try #require(run.frame.tabs.first { $0.isLive }).box.width

        #expect(run.arrow(in: setting) == nil)
        #expect(narrow > StripTuning.tabMin && wide < StripTuning.tabMax)
        #expect(Double(wide - narrow) == StripRowLayout.arrowRoom)
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

    private static func scene(right: Bool = false, note: StripNote = note) -> StripScene {
        let resting = StripScene.resting()

        return StripScene(
            frame: resting.frame, hoverRow: nil, note: note, now: 0, mirror: mirror(right: right), menu: 37,
            reducesMotion: false
        )
    }

    private static func words(of session: Session = helpDesk, pressed: Bool, alpha: Double = 1) -> StripFrame.Words {
        StripFrame.Words(
            id: 1, key: .session(session.markID), content: .row(session), frame: CGRect(origin: .zero, size: size),
            scroll: 0, alpha: alpha, dy: 0, isPressed: pressed, pressedRow: nil
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
