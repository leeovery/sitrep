import AppKit
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel in black, as Paper's boards E2, F and A2 draw them: the arrow soft on the row's
/// lift, lit #34343B with its chevron white, pointing away from the screen's edge; the asks panel's black, its
/// hairline and its shadow, its page dots, its title and age, its answers' rows and keycaps, the outlined row of a
/// words ask, its foot's Open in Claude; and while an answer is held, its row white, the countdown's arc half run out
/// a second in, and Undo.
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

    private static func isClose(_ colour: NSColor, _ hex: UInt32, _ within: CGFloat = 3) -> Bool {
        let wanted = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) }
        let got = [colour.redComponent, colour.greenComponent, colour.blueComponent].map { $0 * 255 }

        return zip(got, wanted).allSatisfy { abs($0 - $1) <= within }
    }

    // MARK: The row's arrow

    private static let row = CGSize(width: 344, height: 30)

    /// A Needs you row lifted under the pointer, its arrow unlit or lit, pointing right or left.
    private static func arrowed(isLit: Bool, pointsLeft: Bool = false) throws -> Drawn {
        let session = Session(
            id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, ask: "k1",
            title: "Thread replies, or keep them flat?", sub: "Northwind", since: 0
        )
        let row = SessionRow(session, size: Self.row)

        row.isHighlighted = true
        row.arrow = SessionRow.Arrow(isLit: isLit, pointsLeft: pointsLeft)
        return try Drawn(row.layer)
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

    // MARK: The asks panel

    private static let helpDesk = Session(
        id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, title: "", sub: "Northwind",
        since: 0
    )
    private static let choice = PanelAsk(
        id: "k1", title: "Thread replies, or keep them flat?", answers: ["Threaded", "Flat"], recommended: "Threaded",
        since: 0
    )
    private static let words = PanelAsk(id: "k1", title: "Say what an empty rota should read", since: 0)
    /// Where the asks panel stands in the picture, with room round it for its shadow.
    private static let margin = 40.0

    /// The asks panel drawn over grey, so its shadow shows, a second after `sending` was held where one is.
    private static func drawn(
        _ ask: PanelAsk = choice, page: Int = 0, pages: Int = 2, sending: Sending? = nil, hover: AsksPart? = nil
    ) throws -> (Drawn, AsksShown) {
        let layout = AsksLayout(ask, measure: AsksMeasure.drawn)
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

    /// Each answer's row filled and bordered, its keycap's grey round its number, its label white, Claude's pick's
    /// "recommended" faint at its end.
    @Test func itsAnswersAreNumberedRowsTheRecommendedOneSaysSo() throws {
        let (drawn, asks) = try Self.drawn()
        let first = Self.placed(asks.layout.answers[0]), second = Self.placed(asks.layout.answers[1])
        let keycap = AsksLayout.keycap.offsetBy(dx: second.minX, dy: second.minY)

        #expect(Self.shows(0x1C1C1F, at: CGPoint(x: second.maxX - 20, y: second.midY), in: drawn))
        #expect(Self.shows(0x34343A, at: CGPoint(x: second.midX, y: second.minY + 0.25), in: drawn))
        #expect(Self.shows(0x2C2C31, at: CGPoint(x: keycap.minX + 3, y: keycap.midY), in: drawn))
        let label = CGRect(x: second.minX + 40, y: second.minY, width: 40, height: 38)
        let recommended = CGRect(x: first.maxX - 70, y: first.minY + 8, width: 60, height: 22)

        #expect(Self.brightest(Self.white, in: label, of: drawn))
        #expect(Self.brightest(Self.faint, in: recommended, of: drawn))
    }

    @Test func anAnswersRowLiftsUnderThePointer() throws {
        let (drawn, asks) = try Self.drawn(hover: .answer(1)), second = Self.placed(asks.layout.answers[1])

        #expect(Self.shows(0x26262A, at: CGPoint(x: second.maxX - 20, y: second.midY), in: drawn))
    }

    @Test func aWordsAskHasOneOutlinedRowAndNoOpenInClaude() throws {
        let (drawn, asks) = try Self.drawn(Self.words, pages: 1), row = Self.placed(asks.layout.answers[0])

        #expect(asks.layout.open == nil)
        #expect(Self.shows(0x000000, at: CGPoint(x: row.maxX - 20, y: row.midY), in: drawn))
        #expect(Self.shows(0x2C2C31, at: CGPoint(x: row.midX, y: row.minY + 0.25), in: drawn))
    }

    @Test func openInClaudeIsAnOutlinedPill() throws {
        let (drawn, asks) = try Self.drawn(), open = Self.placed(try #require(asks.layout.open))

        #expect(Self.shows(0x2C2C31, at: CGPoint(x: open.midX, y: open.minY + 0.25), in: drawn))
        #expect(Self.brightest(Self.white, in: open.insetBy(dx: 10, dy: 4), of: drawn))
    }

    // MARK: Sending

    /// "Sending Threaded", a second into its two: its row white, its keycap a check in ink, the arc run halfway
    /// round, from 12 o'clock to 6 down the right, the track bare on the left.
    @Test func aHeldAnswersRowIsWhiteAndItsCountdownHalfRunOutASecondIn() throws {
        let held = Sending(row: 0, words: "Threaded", heldAt: 4 * 60_000, goesAt: 4 * 60_000 + 2000)
        let (drawn, asks) = try Self.drawn(sending: held)
        let row = Self.placed(asks.layout.answers[0]), ring = Self.placed(asks.layout.countdown)
        let check = AsksLayout.keycap.offsetBy(dx: row.minX, dy: row.minY), undo = Self.placed(asks.layout.undo)
        let right = CGRect(x: ring.midX + 3.5, y: ring.midY - 1, width: 2.5, height: 2)
        let left = CGRect(x: ring.midX - 6, y: ring.midY - 1, width: 2.5, height: 2)

        #expect(Self.shows(Self.white, at: CGPoint(x: row.minX + 36, y: row.minY + 4), in: drawn))
        #expect(try #require(drawn.pixels(in: check).min { $0.lightness < $1.lightness }).lightness < 0.5)
        #expect(Self.brightest(Self.white, in: Self.placed(asks.layout.sending), of: drawn))
        #expect(Self.brightest(Self.soft, in: right, of: drawn))
        #expect(Self.brightest(0x2C2C31, in: left, of: drawn))
        #expect(Self.shows(0x2C2C31, at: CGPoint(x: undo.midX, y: undo.minY + 0.25), in: drawn))
    }
}
