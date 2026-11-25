import AppKit
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel in black, as Paper's boards E2, F, H3 and A2 draw them: the arrow soft on the
/// row's lift, lit #34343B with its chevron white, pointing away from the screen's edge, turned back while its asks
/// panel is open, turning in 0.2 seconds or at once under Reduce motion; the asks panel's black, its hairline and its
/// shadow, its page dots, its title and age, its answers' rows, their words alone, Claude's pick in lilac with its tag
/// after its words, each lighter under the pointer, a words ask with none, its foot's Open in Claude for every ask and
/// Snooze ▾ only while Snooze offers a time; and while an answer is held, its row white with its check at its end, the
/// countdown's arc half run out a second in, and Undo.
@MainActor
@Suite(.backstop)
struct AsksPanelDrawnTests {
    private static let soft: UInt32 = 0x98989F, white: UInt32 = 0xF5F5F7, faint: UInt32 = 0x5C5C63

    /// Whether the pixel under a point, as stored, is this colour, to within 3 levels of 8 bits in each channel.
    private static func shows(_ hex: UInt32, at point: CGPoint, in drawn: Drawn) -> Bool {
        drawn.stored(at: point).map { isClose($0, hex) } ?? false
    }

    /// Whether the brightest pixel in `rect`, as stored, is this colour: words' and strokes' full colour.
    private static func brightest(_ hex: UInt32, in rect: CGRect, of drawn: Drawn, within: CGFloat = 3) -> Bool {
        let step = 1 / drawn.scale
        let points = stride(from: rect.minY, to: rect.maxY, by: step).flatMap { y in
            stride(from: rect.minX, to: rect.maxX, by: step).map { CGPoint(x: $0, y: y) }
        }

        return points.compactMap(drawn.stored).max { $0.lightness < $1.lightness }.map { isClose($0, hex, within) }
            ?? false
    }

    /// A colour at an alpha out of 255 laid over an opaque one, as Core Animation lays a fill over what is under it.
    private static func over(_ hex: UInt32, _ alpha: UInt32, on base: UInt32) -> UInt32 {
        let a = Double(alpha) / 255

        return [16, 8, 0].reduce(0) { blended, shift in
            let top = Double(hex >> shift & 0xFF), under = Double(base >> shift & 0xFF)

            return blended | UInt32((a * top + (1 - a) * under).rounded()) << shift
        }
    }

    private static func isClose(_ colour: NSColor, _ hex: UInt32, _ within: CGFloat = 3) -> Bool {
        let wanted = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) }
        let got = [colour.redComponent, colour.greenComponent, colour.blueComponent].map { $0 * 255 }

        return zip(got, wanted).allSatisfy { abs($0 - $1) <= within }
    }

    // MARK: The row's arrow

    private static let row = CGSize(width: 344, height: 30)

    /// A Needs you row lifted under the pointer, its arrow unlit or lit, pointing right or left, turned or not.
    private static func arrowed(isLit: Bool, pointsLeft: Bool = false, isTurned: Bool = false) throws -> Drawn {
        let row = arrowRow()

        row.isHighlighted = true
        row.arrow = SessionRow.Arrow(isLit: isLit, pointsLeft: pointsLeft, isTurned: isTurned)
        return try Drawn(row.layer)
    }

    private static func arrowRow() -> SessionRow {
        let session = Session(
            id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, ask: "k1",
            title: "Thread replies, or keep them flat?", sub: "Northwind", since: 0
        )

        return SessionRow(session, size: Self.row)
    }

    private static var arrowBox: CGRect { RowArrow.box(in: row) }

    @Test func unlitTheArrowIsASoftChevronOnTheRowsLift() throws {
        let drawn = try Self.arrowed(isLit: false), box = Self.arrowBox

        #expect(Self.brightest(Self.soft, in: box, of: drawn))
        #expect(Self.shows(0x141416, at: CGPoint(x: box.minX + 4, y: box.midY), in: drawn))
    }

    @Test func litTheArrowIsFilledItsChevronWhite() throws {
        let drawn = try Self.arrowed(isLit: true), box = Self.arrowBox

        #expect(Self.brightest(Self.white, in: box, of: drawn))
        #expect(Self.shows(0x34343B, at: CGPoint(x: box.minX + 4, y: box.midY), in: drawn))
    }

    /// Its chevron's tip toward the asks panel: right on the left edge, left on the right.
    @Test func itsChevronPointsAwayFromTheEdge() throws {
        let box = Self.arrowBox, middle = box.midY
        let tipRight = CGPoint(x: box.midX + 1.5, y: middle), tipLeft = CGPoint(x: box.midX - 1.5, y: middle)
        let right = try Self.arrowed(isLit: true), left = try Self.arrowed(isLit: true, pointsLeft: true)
        let light = { (drawn: Drawn, point: CGPoint) in drawn.pixel(at: point)?.lightness ?? 0 }

        #expect(light(right, tipRight) > light(right, tipLeft))
        #expect(light(left, tipLeft) > light(left, tipRight))
    }

    /// Turned, while its asks panel is open, it points back the other way, on either edge.
    @Test func turnedItsChevronPointsBack() throws {
        let box = Self.arrowBox, middle = box.midY
        let tipRight = CGPoint(x: box.midX + 1.5, y: middle), tipLeft = CGPoint(x: box.midX - 1.5, y: middle)
        let right = try Self.arrowed(isLit: true, isTurned: true)
        let left = try Self.arrowed(isLit: true, pointsLeft: true, isTurned: true)
        let light = { (drawn: Drawn, point: CGPoint) in drawn.pixel(at: point)?.lightness ?? 0 }

        #expect(light(right, tipLeft) > light(right, tipRight))
        #expect(light(left, tipRight) > light(left, tipLeft))
    }

    /// The chevron's turns, as the render server runs them: half a turn in 0.2 seconds as its asks panel opens, and
    /// back as it closes, from where it showed; none under Reduce motion, nor as the arrow first shows turned.
    @Test func itTurnsInAFifthOfASecondOrAtOnceUnderReduceMotion() throws {
        let row = Self.arrowRow(), lit = SessionRow.Arrow(isLit: true, pointsLeft: false)
        let turning = { (row: SessionRow) in
            row.arrowLayer?.chevron.animation(forKey: SessionRow.turnKey) as? CABasicAnimation
        }

        row.arrow = SessionRow.Arrow(isLit: true, pointsLeft: false, isTurned: true)
        #expect(turning(row) == nil)
        row.arrow = lit
        let back = try #require(turning(row))

        #expect(back.keyPath == "transform.rotation.z" && back.duration == 0.2)
        #expect(back.fromValue as? Double == .pi && back.toValue as? Double == 0)

        let opening = Self.arrowRow()

        opening.arrow = lit
        opening.arrow = SessionRow.Arrow(isLit: true, pointsLeft: false, isTurned: true)
        #expect(turning(opening)?.fromValue as? Double == 0 && turning(opening)?.toValue as? Double == .pi)

        let still = Self.arrowRow()

        still.arrow = lit
        still.arrow = SessionRow.Arrow(isLit: true, pointsLeft: false, isTurned: true, turnsAtOnce: true)
        #expect(turning(still) == nil)
        #expect(still.arrowLayer?.chevron.value(forKeyPath: SessionRow.turnKey) as? Double == .pi)
    }

    // MARK: The asks panel

    private static let helpDesk = Session(
        id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, title: "", sub: "Northwind",
        since: 0
    )
    private static let choice = PanelAsk(
        id: "k1", title: "Thread replies, or keep them flat?", wants: .choice, answers: ["Threaded", "Flat"],
        recommended: "Threaded",
        since: 0
    )
    private static let words = PanelAsk(id: "k1", title: "Say what an empty rota should read", wants: .words, since: 0)
    /// Claude's pick, long enough to wrap to a second line, its tag after its words there.
    private static let longPick = PanelAsk(
        id: "k1", title: "Thread replies, or keep them flat?", wants: .choice,
        answers: ["Thread replies under the message they answer, folded after three", "Flat"],
        recommended: "Thread replies under the message they answer, folded after three", since: 0
    )
    /// Claude's pick's lilac, #B1B9F9: its row's fill at 20% and border at 36% over the black, and lifted 28% and 50%.
    private static let lilac: UInt32 = 0xB1B9F9, tag: UInt32 = 0x9AA2EE
    /// Where the asks panel stands in the picture, with room round it for its shadow.
    private static let margin = 40.0

    /// The asks panel drawn over grey, so its shadow shows, a second after `sending` was held where one is.
    private static func drawn(
        _ ask: PanelAsk = choice, page: Int = 0, pages: Int = 2, sending: Sending? = nil, hover: AsksPart? = nil,
        offersSnooze: Bool = true
    ) throws -> (Drawn, AsksShown) {
        let layout = AsksLayout(ask, measure: AsksMeasure.drawn, offersSnooze: offersSnooze)
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: helpDesk, ask: ask, page: page, pages: pages, layout: layout,
            frame: CGRect(origin: CGPoint(x: margin, y: margin), size: layout.size), sending: sending, hover: hover
        )
        let panel = AsksPanelLayer(), picture = CALayer()

        picture.frame = CGRect(x: 0, y: 0, width: layout.size.width + 2 * margin, height: layout.height + 2 * margin)
        panel.show(asks, mirror: .identity, now: 4 * 60_000 + (sending.map { $0.heldAt - 4 * 60_000 + 1000 } ?? 0))
        picture.addSublayer(panel.layer)
        return (try Drawn(picture, over: CGColor(srgbRed: 0.38, green: 0.38, blue: 0.38, alpha: 1)), asks)
    }

    /// A box of the asks panel's own, in the picture.
    private static func placed(_ box: CGRect) -> CGRect {
        box.offsetBy(dx: margin, dy: margin)
    }

    /// The black, and its hairline, white at 15% over it.
    @Test func itIsThePanelsBlackWithAHairline() throws {
        let (drawn, asks) = try Self.drawn(), frame = asks.frame

        #expect(Self.shows(0x000000, at: CGPoint(x: frame.midX, y: frame.minY + 6), in: drawn))
        #expect(Self.shows(0x262626, at: CGPoint(x: frame.midX, y: frame.minY + 0.25), in: drawn))
    }

    /// A submenu's two shadows: 14 down blurred 36 at 65%, and 4 toward the list blurred 12 at 50%, across the other
    /// way on the right edge. Read off its layers, as `render(in:)` casts a shadow up where the screen casts it down.
    @Test(arguments: [false, true])
    func itCastsASubmenusShadowsTheSideOneTowardTheList(onTheRight: Bool) throws {
        let layout = AsksLayout(Self.choice, measure: AsksMeasure.drawn), panel = AsksPanelLayer()
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: Self.helpDesk, ask: Self.choice, page: 0, pages: 2, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: nil, hover: nil
        )
        let mirror = onTheRight ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity

        panel.show(asks, mirror: mirror, now: 0)

        let shadows = try #require(panel.layer.sublayers).prefix(2)

        let toward = CGSize(width: onTheRight ? 4 : -4, height: 0)

        #expect(shadows.map(\.shadowOffset) == [CGSize(width: 0, height: 14), toward])
        #expect(shadows.map(\.shadowRadius) == [18, 6])
        #expect(shadows.map(\.shadowOpacity) == [Float(0xA6) / 255, Float(0x80) / 255])
    }

    @Test func itsTopLineNamesTheSessionAndItsDotsTheCurrentAskOrange() throws {
        let (drawn, asks) = try Self.drawn(page: 0, pages: 2), top = Self.placed(asks.layout.top)
        let current = CGPoint(x: top.maxX - 5 - 4 - 7, y: top.midY), other = CGPoint(x: top.maxX - 2.5, y: top.midY)

        let name = CGRect(x: top.minX, y: top.minY, width: 60, height: top.height)

        #expect(Self.brightest(Self.white, in: name, of: drawn))
        #expect(Self.shows(0xE9643D, at: current, in: drawn))
        #expect(Self.shows(0x3A3A40, at: other, in: drawn))
    }

    @Test func oneAskHasNoDots() throws {
        let (drawn, asks) = try Self.drawn(pages: 1), top = Self.placed(asks.layout.top)

        #expect(Self.shows(0x000000, at: CGPoint(x: top.maxX - 2.5, y: top.midY), in: drawn))
    }

    @Test func itsTitleIsWhiteAndItsAgeFaint() throws {
        let (drawn, asks) = try Self.drawn()

        #expect(Self.brightest(Self.white, in: Self.placed(asks.layout.title), of: drawn))
        #expect(Self.brightest(Self.faint, in: Self.placed(asks.layout.age), of: drawn))
    }

    /// Each answer's row its words alone, white from 12 in, no number before them: Claude's pick filled #B1B9F9 at 20%
    /// and bordered at 36%, "  ·  Recommended" after its words in #9AA2EE; any other filled #1C1C1F, bordered #34343A.
    @Test func itsAnswersAreTheirWordsAloneThePickInLilacItsTagAfterThem() throws {
        let (drawn, asks) = try Self.drawn()
        let first = Self.placed(asks.layout.answers[0]), second = Self.placed(asks.layout.answers[1])
        let words = TextLine.width(AsksPanelParts.answerText("Threaded", colour: EdgeStyle.ink))
        let tag = CGRect(x: first.minX + 12 + words + 4, y: first.minY + 8, width: 100, height: 22)

        #expect(Self.shows(Self.over(Self.lilac, 0x33, on: 0), at: CGPoint(x: first.maxX - 20, y: first.midY), in: drawn))
        #expect(Self.shows(
            Self.over(Self.lilac, 0x5C, on: Self.over(Self.lilac, 0x33, on: 0)),
            at: CGPoint(x: first.midX, y: first.minY + 0.25), in: drawn
        ))
        #expect(Self.brightest(Self.tag, in: tag, of: drawn))
        #expect(Self.shows(0x1C1C1F, at: CGPoint(x: second.maxX - 20, y: second.midY), in: drawn))
        #expect(Self.shows(0x34343A, at: CGPoint(x: second.midX, y: second.minY + 0.25), in: drawn))
        #expect(Self.brightest(Self.white, in: CGRect(x: second.minX + 12, y: second.minY, width: 12, height: 38), of: drawn))
        #expect(Self.shows(0x1C1C1F, at: CGPoint(x: second.minX + 8, y: second.midY), in: drawn))
    }

    /// Under the pointer, Claude's pick brightens to 28% filled and 50% bordered; any other lightens to #26262A,
    /// bordered #46464D.
    @Test(arguments: [0, 1])
    func anAnswersRowLiftsUnderThePointer(row: Int) throws {
        let (drawn, asks) = try Self.drawn(hover: .answer(row)), box = Self.placed(asks.layout.answers[row])
        let fill = row == 0 ? Self.over(Self.lilac, 0x47, on: 0) : 0x26262A
        let border = row == 0 ? Self.over(Self.lilac, 0x80, on: fill) : 0x46464D

        #expect(Self.shows(fill, at: CGPoint(x: box.maxX - 20, y: box.midY), in: drawn))
        #expect(Self.shows(border, at: CGPoint(x: box.midX, y: box.minY + 0.25), in: drawn))
    }

    /// An answer past one line wraps to a second, its row grown to 54 round its two lines, both white, Claude's pick's
    /// tag after its words on the second.
    @Test func aLongAnswerWrapsToTwoLinesItsTagAfterItsWords() throws {
        let (drawn, asks) = try Self.drawn(Self.longPick), row = Self.placed(asks.layout.answers[0])
        let lines = AsksLayout.answerBoxes(in: row.size, lines: 2).map { $0.offsetBy(dx: row.minX, dy: row.minY) }
        let shown = AsksPanelParts.answerLines(0, of: asks).map(\.line)

        #expect(asks.layout.answerLines[0] == 2 && row.height == 54)
        #expect(shown.map(\.tag) == [nil, AsksPanelParts.pickTag])
        #expect(Self.brightest(Self.white, in: CGRect(x: lines[0].minX, y: lines[0].minY, width: 40, height: 18), of: drawn))
        #expect(Self.brightest(Self.white, in: CGRect(x: lines[1].minX, y: lines[1].minY, width: 40, height: 18), of: drawn))
        #expect(Self.brightest(Self.tag, in: CGRect(x: row.maxX - 140, y: lines[1].minY, width: 128, height: 18), of: drawn))
    }

    /// Lee switched every Snooze time off: the foot shows Ignore and Open in Claude, nothing between them.
    @Test func withNoSnoozeTimeOfferedItsFootHasNoSnooze() throws {
        let (offered, asks) = try Self.drawn(), (none, _) = try Self.drawn(offersSnooze: false)
        let snooze = Self.placed(try #require(asks.layout.snooze))

        #expect(Self.brightest(Self.soft, in: snooze, of: offered))
        #expect(try #require(none.pixels(in: snooze).max { $0.lightness < $1.lightness }).lightness < 0.01)
    }

    /// A words ask draws no row between its age and its foot: only the black, and its foot's Open in Claude.
    @Test func aWordsAskHasNoRowsAndItsFootsOpenInClaude() throws {
        let (drawn, asks) = try Self.drawn(Self.words, pages: 1), layout = asks.layout
        let gap = layout.foot.minY - layout.age.maxY
        let between = Self.placed(CGRect(x: layout.foot.minX, y: layout.age.maxY + 2, width: layout.foot.width, height: gap - 4))
        let open = Self.placed(layout.open)

        #expect(try #require(drawn.pixels(in: between).max { $0.lightness < $1.lightness }).lightness < 0.01)
        #expect(Self.shows(0x2C2C31, at: CGPoint(x: open.midX, y: open.minY + 0.25), in: drawn))
        #expect(Self.brightest(Self.white, in: open.insetBy(dx: 10, dy: 4), of: drawn))
    }

    @Test func openInClaudeIsAnOutlinedPill() throws {
        let (drawn, asks) = try Self.drawn(), open = Self.placed(asks.layout.open)

        #expect(Self.shows(0x2C2C31, at: CGPoint(x: open.midX, y: open.minY + 0.25), in: drawn))
        #expect(Self.brightest(Self.white, in: open.insetBy(dx: 10, dy: 4), of: drawn))
    }

    // MARK: Sending

    /// "Sending Threaded", a second into its two: its row white, its words and its check at its trailing end in ink,
    /// the arc run halfway round, from 12 o'clock to 6 down the right, the track bare on the left.
    @Test func aHeldAnswersRowIsWhiteAndItsCountdownHalfRunOutASecondIn() throws {
        let held = Sending(row: 0, words: "Threaded", heldAt: 4 * 60_000, goesAt: 4 * 60_000 + 2000)
        let (drawn, asks) = try Self.drawn(sending: held)
        let row = Self.placed(asks.layout.answers[0]), ring = Self.placed(asks.layout.countdown)
        let check = AsksLayout.check(in: row.size).offsetBy(dx: row.minX, dy: row.minY)
        let undo = Self.placed(asks.layout.undo)
        let right = CGRect(x: ring.midX + 3.5, y: ring.midY - 1, width: 2.5, height: 2)
        let left = CGRect(x: ring.midX - 6, y: ring.midY - 1, width: 2.5, height: 2)

        #expect(Self.shows(Self.white, at: CGPoint(x: row.minX + 36, y: row.minY + 4), in: drawn))
        #expect(Self.shows(Self.white, at: CGPoint(x: check.minX - 4, y: check.midY), in: drawn))
        #expect(try #require(drawn.pixels(in: check).min { $0.lightness < $1.lightness }).lightness < 0.5)
        #expect(Self.brightest(Self.white, in: Self.placed(asks.layout.sending), of: drawn))
        #expect(Self.brightest(Self.soft, in: right, of: drawn))
        #expect(Self.brightest(0x2C2C31, in: left, of: drawn))
        #expect(Self.shows(0x2C2C31, at: CGPoint(x: undo.midX, y: undo.minY + 0.25), in: drawn))
    }

    /// It shows, moves and closes at once, as a submenu does: nothing it changes asks for an animation, which Core
    /// Animation does only outside a transaction that turns them off.
    @Test func itShowsAndClosesAtOnce() {
        let layout = AsksLayout(Self.choice, measure: AsksMeasure.drawn), panel = AsksPanelLayer()
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: Self.helpDesk, ask: Self.choice, page: 0, pages: 2, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: nil, hover: nil
        )
        let asked = ActionsAsked()

        panel.layer.delegate = asked
        panel.show(asks, mirror: .identity, now: 0)
        panel.show(nil, mirror: .identity, now: 0)

        #expect(panel.layer.isHidden)
        #expect(asked.keys.isEmpty)
    }
}

/// The changes a layer asked its delegate for an animation for, by their keys.
private final class ActionsAsked: NSObject, CALayerDelegate {
    private(set) var keys: [String] = []

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        keys.append(event)
        return nil
    }
}
