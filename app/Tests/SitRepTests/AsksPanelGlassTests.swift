import AppKit
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// The row's arrow and the asks panel in glass, in the dark appearance over black (DESIGN, "Answering from the panel",
/// "Black and Glass"): the arrow's chevron in the secondary on the row's lift, lit a step stronger with its chevron in
/// the primary, pointing away from the screen's edge, taking the time's place; the asks panel's hairline and its
/// shadows, cast outside it alone, its words in the label colours, its
/// current page dot orange, its rows and keycaps in the glass's tints, lifted under the pointer, the words ask's row
/// outlined; and while an answer is held, its row white with its check in ink, and the countdown run down from what is
/// left. The glass itself is the window server's, which draws nothing offscreen: these read what is drawn over it.
@MainActor
@Suite(.backstop)
struct AsksPanelGlassTests {
    private static func light(_ drawn: Drawn, at point: CGPoint) -> CGFloat {
        drawn.pixel(at: point)?.lightness ?? 0
    }

    private static func brightest(_ drawn: Drawn, in rect: CGRect) throws -> CGFloat {
        try drawn.brightest(in: rect).lightness
    }

    // MARK: The row's arrow

    private static let row = CGSize(width: 344, height: 30)

    /// A Needs you row lifted under the pointer, its arrow unlit or lit, pointing right or left.
    @available(macOS 26, *)
    private static func arrowed(isLit: Bool, pointsLeft: Bool = false) throws -> Drawn {
        let session = Session(
            id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, ask: "k1",
            title: "Thread replies, or keep them flat?", sub: "Northwind", since: 0
        )

        return try Drawn(
            GlassSessionRow(
                session: session, size: row, hovered: true, pressed: false, now: 60_000, wash: 0,
                arrow: SessionRow.Arrow(isLit: isLit, pointsLeft: pointsLeft)
            ),
            size: row
        )
    }

    private static var arrowBox: CGRect { RowArrow.box(in: row) }

    /// Unlit, no fill of its own on the row's lift, its chevron the secondary's, dimmer than the primary's lit.
    @available(macOS 26, *)
    @Test func unlitTheArrowIsASecondaryChevronOnTheRowsLift() throws {
        let unlit = try Self.arrowed(isLit: false), lit = try Self.arrowed(isLit: true), box = Self.arrowBox
        let edge = CGPoint(x: box.minX + 4, y: box.midY), lift = CGPoint(x: box.minX - 3, y: box.midY)

        #expect(abs(Self.light(unlit, at: edge) - Self.light(unlit, at: lift)) < 0.02)
        #expect(try Self.brightest(unlit, in: box) < Self.brightest(lit, in: box) - 0.3)
    }

    /// Lit, its fill a step stronger than the row's lift, its chevron the primary's, near white on the dark.
    @available(macOS 26, *)
    @Test func litTheArrowIsAStepStrongerItsChevronPrimary() throws {
        let drawn = try Self.arrowed(isLit: true), box = Self.arrowBox
        let edge = CGPoint(x: box.minX + 4, y: box.midY), lift = CGPoint(x: box.minX - 3, y: box.midY)

        #expect(Self.light(drawn, at: edge) > Self.light(drawn, at: lift) + 0.1)
        #expect(try Self.brightest(drawn, in: box) > 2.4)
    }

    /// Its time gives way to it: nothing drawn in the time's place round the arrow.
    @available(macOS 26, *)
    @Test func itTakesTheTimesPlace() throws {
        let drawn = try Self.arrowed(isLit: false), box = Self.arrowBox
        let beside = CGRect(x: box.minX, y: box.minY, width: 8, height: box.height)

        #expect(try Self.brightest(drawn, in: beside) < 0.5)
    }

    /// Its chevron's tip toward the asks panel: right on the left edge, left on the right.
    @available(macOS 26, *)
    @Test func itsChevronPointsAwayFromTheEdge() throws {
        let box = Self.arrowBox, middle = box.midY
        let tipRight = CGPoint(x: box.midX + 1.5, y: middle), tipLeft = CGPoint(x: box.midX - 1.5, y: middle)
        let right = try Self.arrowed(isLit: true), left = try Self.arrowed(isLit: true, pointsLeft: true)

        #expect(Self.light(right, at: tipRight) > Self.light(right, at: tipLeft))
        #expect(Self.light(left, at: tipLeft) > Self.light(left, at: tipRight))
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
    private static let margin = 40.0

    /// The asks panel drawn with room round it, over black or over `ground`, a second after `sending` was held where
    /// one is.
    @available(macOS 26, *)
    private static func drawn(
        _ ask: PanelAsk = choice, pages: Int = 2, sending: Sending? = nil, hover: AsksPart? = nil,
        pointsLeft: Bool = false, over ground: Color = .black
    ) throws -> (Drawn, AsksShown) {
        let layout = AsksLayout(ask, measure: .drawn)
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: helpDesk, ask: ask, page: 0, pages: pages, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: sending, hover: hover
        )
        let size = CGSize(width: layout.size.width + 2 * margin, height: layout.height + 2 * margin)
        let now = 4 * 60_000 + (sending.map { $0.heldAt - 4 * 60_000 + 1000 } ?? 0)
        let panel = GlassAsksPanel(asks: asks, pointsLeft: pointsLeft, now: now)
            .offset(x: margin, y: margin)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(ground)

        return (try Drawn(panel, size: size), asks)
    }

    /// A box of the asks panel's own, in the picture.
    private static func placed(_ box: CGRect) -> CGRect {
        box.offsetBy(dx: margin, dy: margin)
    }

    /// The middle of a box of the asks panel's own, in the picture.
    private static func middle(_ box: CGRect) -> CGPoint {
        CGPoint(x: placed(box).midX, y: placed(box).midY)
    }

    /// The label colours as they draw over black in the dark: the primary near white, the secondary soft, the tertiary
    /// faint.
    private static func isPrimary(_ light: CGFloat) -> Bool { light > 2.3 }
    private static func isSecondary(_ light: CGFloat) -> Bool { (1.2 ... 2.0).contains(light) }
    private static func isTertiary(_ light: CGFloat) -> Bool { (0.4 ... 1.0).contains(light) }

    /// Its hairline, the separator's, round the glass, which draws nothing here.
    @available(macOS 26, *)
    @Test func itHasAHairlineRoundItsGlass() throws {
        let (drawn, asks) = try Self.drawn(), frame = Self.placed(asks.frame)

        #expect(Self.light(drawn, at: CGPoint(x: frame.midX, y: frame.minY + 0.25)) > 0.1)
        #expect(Self.light(drawn, at: CGPoint(x: frame.midX, y: frame.minY + 6)) < 0.02)
    }

    /// A submenu's shadows, 14 off its middle down the screen and 4 toward the list, across the other way on the right
    /// edge, falling outside it alone: the glass shows what is under it untouched. A view's cache casts the long one up
    /// where the screen casts it down, as `render(in:)` does (`Shadows`), so its offset reads here as one side's shadow
    /// far darker than the other's.
    @available(macOS 26, *)
    @Test(arguments: [false, true])
    func itCastsASubmenusShadowsOutsideItAlone(onTheRight: Bool) throws {
        let (drawn, asks) = try Self.drawn(pointsLeft: onTheRight, over: Color(white: 0.5))
        let frame = Self.placed(asks.frame), ground = Self.light(drawn, at: CGPoint(x: 2, y: 2))
        let ends = [frame.minY - 4, frame.maxY + 4].map { Self.light(drawn, at: CGPoint(x: frame.midX, y: $0)) }
        let list = CGPoint(x: onTheRight ? frame.maxX + 2 : frame.minX - 2, y: frame.midY)
        let away = CGPoint(x: onTheRight ? frame.minX - 2 : frame.maxX + 2, y: frame.midY)

        #expect(try #require(ends.min()) < ground - 0.5)
        #expect(try #require(ends.max()) - #require(ends.min()) > 0.3)
        #expect(Self.light(drawn, at: list) < Self.light(drawn, at: away) - 0.1)
        #expect(abs(Self.light(drawn, at: CGPoint(x: frame.midX, y: frame.maxY - 6)) - ground) < 0.03)
    }

    /// Its top line: the session's name in the primary, its project in the tertiary, its current page dot orange and
    /// the other in the glass's tint.
    @available(macOS 26, *)
    @Test func itsTopLineNamesTheSessionAndItsDotsTheCurrentAskOrange() throws {
        let (drawn, asks) = try Self.drawn(), top = AsksPanelParts.top(asks)
        let current = try #require(top.dots.first { $0.isCurrent }), other = try #require(top.dots.first { !$0.isCurrent })
        let orange = try #require(drawn.pixel(at: Self.middle(current.box)))
        let grey = try #require(drawn.pixel(at: Self.middle(other.box)))

        #expect(Self.isPrimary(try Self.brightest(drawn, in: Self.placed(top.name))))
        #expect(Self.isTertiary(try Self.brightest(drawn, in: Self.placed(top.project))))
        #expect(orange.redComponent > 0.75 && orange.blueComponent < 0.35)
        #expect(abs(grey.redComponent - grey.blueComponent) < 0.03 && (0.3 ... 1).contains(grey.lightness))
    }

    @available(macOS 26, *)
    @Test func oneAskHasNoDots() throws {
        let (drawn, asks) = try Self.drawn(pages: 1), top = Self.placed(asks.layout.top)

        #expect(Self.light(drawn, at: CGPoint(x: top.maxX - 2.5, y: top.midY)) < 0.02)
    }

    @available(macOS 26, *)
    @Test func itsTitleIsPrimaryAndItsAgeTertiary() throws {
        let (drawn, asks) = try Self.drawn()

        #expect(Self.isPrimary(try Self.brightest(drawn, in: Self.placed(asks.layout.title))))
        #expect(Self.isTertiary(try Self.brightest(drawn, in: Self.placed(asks.layout.age))))
    }

    /// Each answer's row filled in the glass's tint and bordered a step over it, its keycap a step over the row; over
    /// them its label in the primary, its number in the secondary, and Claude's pick's "recommended" in the tertiary,
    /// each dimmer than the last.
    @available(macOS 26, *)
    @Test func itsAnswersAreNumberedRowsTheRecommendedOneSaysSo() throws {
        let (drawn, asks) = try Self.drawn()
        let first = Self.placed(asks.layout.answers[0]), second = Self.placed(asks.layout.answers[1])
        let keycap = AsksLayout.keycap.offsetBy(dx: second.minX, dy: second.minY)
        let fill = Self.light(drawn, at: CGPoint(x: second.maxX - 20, y: second.midY))
        let border = Self.light(drawn, at: CGPoint(x: second.midX, y: second.minY + 0.25))
        let cap = Self.light(drawn, at: CGPoint(x: keycap.minX + 3, y: keycap.midY))
        let label = CGRect(x: second.minX + 40, y: second.minY, width: 40, height: 38)
        let recommended = CGRect(x: first.maxX - 70, y: first.minY + 8, width: 60, height: 22)

        #expect(fill > 0.15)
        #expect(border > fill + 0.1)
        #expect(cap > fill + 0.1)
        let words = try Self.brightest(drawn, in: label), note = try Self.brightest(drawn, in: recommended)
        let number = try Self.brightest(drawn, in: keycap.insetBy(dx: 4, dy: 4))

        #expect(Self.isPrimary(words))
        #expect(number < words - 0.3 && note < number - 0.3 && note > fill + 0.3)
    }

    @available(macOS 26, *)
    @Test func anAnswersRowLiftsUnderThePointer() throws {
        let (resting, asks) = try Self.drawn(), (lifted, _) = try Self.drawn(hover: .answer(1))
        let row = Self.placed(asks.layout.answers[1]), point = CGPoint(x: row.maxX - 20, y: row.midY)

        #expect(Self.light(lifted, at: point) > Self.light(resting, at: point) + 0.08)
    }

    @available(macOS 26, *)
    @Test func aWordsAskHasOneOutlinedRowAndNoOpenInClaude() throws {
        let (drawn, asks) = try Self.drawn(Self.words, pages: 1), row = Self.placed(asks.layout.answers[0])

        #expect(asks.layout.open == nil)
        #expect(Self.light(drawn, at: CGPoint(x: row.maxX - 20, y: row.midY)) < 0.02)
        #expect(Self.light(drawn, at: CGPoint(x: row.midX, y: row.minY + 0.25)) > 0.2)
    }

    @available(macOS 26, *)
    @Test func openInClaudeIsAnOutlinedPill() throws {
        let (drawn, asks) = try Self.drawn(), open = Self.placed(try #require(asks.layout.open))

        #expect(Self.light(drawn, at: CGPoint(x: open.midX, y: open.minY + 0.25)) > 0.2)
        #expect(Self.light(drawn, at: CGPoint(x: open.minX + 6, y: open.midY)) < 0.02)
        #expect(Self.isPrimary(try Self.brightest(drawn, in: open.insetBy(dx: 10, dy: 4))))
    }

    // MARK: Sending

    /// "Sending Threaded", a second into its two: its row white, a check in ink in its keycap's place, the words in
    /// the primary, the arc run halfway round, from 12 o'clock to 6 down the right, the track bare on the left, and
    /// Undo outlined.
    @available(macOS 26, *)
    @Test func aHeldAnswersRowIsWhiteAndItsCountdownHalfRunOutASecondIn() throws {
        let held = Sending(row: 0, words: "Threaded", heldAt: 4 * 60_000, goesAt: 4 * 60_000 + 2000)
        let (drawn, asks) = try Self.drawn(sending: held)
        let row = Self.placed(asks.layout.answers[0]), ring = Self.placed(asks.layout.countdown)
        let check = AsksLayout.keycap.offsetBy(dx: row.minX, dy: row.minY), undo = Self.placed(asks.layout.undo)
        let right = CGRect(x: ring.midX + 3.5, y: ring.midY - 1, width: 2.5, height: 2)
        let left = CGRect(x: ring.midX - 6, y: ring.midY - 1, width: 2.5, height: 2)

        #expect(try #require(drawn.pixel(at: CGPoint(x: row.minX + 36, y: row.minY + 4))).isWhite)
        #expect(try #require(drawn.pixels(in: check).min { $0.lightness < $1.lightness }).lightness < 0.5)
        #expect(Self.isPrimary(try Self.brightest(drawn, in: Self.placed(asks.layout.sending))))
        #expect(Self.isSecondary(try Self.brightest(drawn, in: right)))
        #expect(try Self.brightest(drawn, in: left) < 0.6)
        #expect(Self.light(drawn, at: CGPoint(x: undo.midX, y: undo.minY + 0.25)) > 0.2)
    }

    /// The countdown runs down in the render server from what is left when it is first shown, over what is left of
    /// the two seconds; shown again for the same answer, as each frame shows it, it runs on untouched.
    @Test func theCountdownRunsDownOnceOverWhatIsLeft() throws {
        let held = Sending(row: 0, words: "Threaded", heldAt: 0, goesAt: 2000), view = CountdownView()

        view.show(held, at: 500)

        let run = try #require(view.arc.animation(forKey: "countdown") as? CABasicAnimation)

        #expect(view.arc.strokeEnd == 0.75)
        #expect(run.fromValue as? Double == 0.75 && run.toValue as? Double == 0 && run.duration == 1.5)

        view.show(held, at: 1500)

        #expect(view.arc.strokeEnd == 0.75)
        #expect(view.arc.animation(forKey: "countdown") as? CABasicAnimation === run)
    }

}
