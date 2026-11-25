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
/// the primary, pointing away from the screen's edge, turned back while its asks panel is open, taking the time's
/// place; the asks panel's hairline and its shadows, cast outside it alone, its words in the label colours, its
/// current page dot orange, its rows their words alone in the glass's tints, Claude's pick in lilac, darker in the
/// light, each lifted under the pointer, a words ask with none; Snooze ▾ only while Snooze offers a time; and while an
/// answer is held, its row white with its check in ink at its end, and the countdown run down from what is left. The
/// glass itself is the window server's, which draws nothing offscreen: these read what is drawn over it.
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

    /// A Needs you row lifted under the pointer, its arrow unlit or lit, pointing right or left, turned or not.
    @available(macOS 26, *)
    private static func arrowed(isLit: Bool, pointsLeft: Bool = false, isTurned: Bool = false) throws -> Drawn {
        let session = Session(
            id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, ask: "k1",
            title: "Thread replies, or keep them flat?", sub: "Northwind", since: 0
        )

        return try Drawn(
            GlassSessionRow(
                session: session, size: row, hovered: true, pressed: false, now: 60_000, wash: 0,
                arrow: SessionRow.Arrow(isLit: isLit, pointsLeft: pointsLeft, isTurned: isTurned, turnsAtOnce: true)
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

    /// Turned, while its asks panel is open, it points back the other way, on either edge.
    @available(macOS 26, *)
    @Test func turnedItsChevronPointsBack() throws {
        let box = Self.arrowBox, middle = box.midY
        let tipRight = CGPoint(x: box.midX + 1.5, y: middle), tipLeft = CGPoint(x: box.midX - 1.5, y: middle)
        let right = try Self.arrowed(isLit: true, isTurned: true)
        let left = try Self.arrowed(isLit: true, pointsLeft: true, isTurned: true)

        #expect(Self.light(right, at: tipLeft) > Self.light(right, at: tipRight))
        #expect(Self.light(left, at: tipRight) > Self.light(left, at: tipLeft))
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
    private static let margin = 40.0

    /// The asks panel drawn with room round it, in the dark unless told, over black or over `ground`, `heldFor` ms
    /// after `sending` was held where one is.
    @available(macOS 26, *)
    private static func drawn(
        _ ask: PanelAsk = choice, pages: Int = 2, sending: Sending? = nil, heldFor: Double = 1000,
        hover: AsksPart? = nil, pointsLeft: Bool = false, over ground: Color = .black, scheme: ColorScheme = .dark,
        offersSnooze: Bool = true
    ) throws -> (Drawn, AsksShown) {
        let layout = AsksLayout(ask, measure: .drawn, offersSnooze: offersSnooze)
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: helpDesk, ask: ask, page: 0, pages: pages, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: sending, hover: hover
        )
        let size = CGSize(width: layout.size.width + 2 * margin, height: layout.height + 2 * margin)
        let now = sending.map { $0.heldAt + heldFor } ?? 4 * 60_000
        let panel = GlassAsksPanel(asks: asks, pointsLeft: pointsLeft, asked: ask.askedText(at: now), now: now)
            .offset(x: margin, y: margin)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(ground)

        return (try Drawn(panel, size: size, scheme: scheme), asks)
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
        let current = try #require(top.dots.first { $0.isCurrent })
        let other = try #require(top.dots.first { !$0.isCurrent })
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

    /// The tag's box on Claude's pick's row, after "Threaded" on its one line.
    private static func tagBox(_ row: CGRect) -> CGRect {
        let words = TextLine.width(AsksPanelParts.answerText("Threaded", colour: EdgeStyle.ink))

        return CGRect(x: row.minX + 12 + words + 4, y: row.minY + 8, width: 100, height: 22)
    }

    /// Whether a colour leans lilac: blue over red over green, as #B1B9F9 and #7178C7 do, never a grey.
    private static func isLilac(_ colour: NSColor) -> Bool {
        colour.blueComponent > colour.redComponent + 0.04 && colour.blueComponent > colour.greenComponent + 0.04
    }

    /// Each answer's row its words alone in the primary, from 12 in, no number before them: Claude's pick filled and
    /// bordered in lilac, its tag after its words in lilac; any other filled in the glass's grey tint, bordered a step
    /// over it.
    @available(macOS 26, *)
    @Test func itsAnswersAreTheirWordsAloneThePickInLilac() throws {
        let (drawn, asks) = try Self.drawn()
        let first = Self.placed(asks.layout.answers[0]), second = Self.placed(asks.layout.answers[1])
        let pick = try #require(drawn.pixel(at: CGPoint(x: first.maxX - 20, y: first.midY)))
        let pickBorder = try #require(drawn.pixel(at: CGPoint(x: first.midX, y: first.minY + 0.25)))
        let other = try #require(drawn.pixel(at: CGPoint(x: second.maxX - 20, y: second.midY)))
        let fill = Self.light(drawn, at: CGPoint(x: second.maxX - 20, y: second.midY))
        let border = Self.light(drawn, at: CGPoint(x: second.midX, y: second.minY + 0.25))
        let tag = try drawn.brightest(in: Self.tagBox(first))

        #expect(Self.isLilac(pick) && Self.isLilac(pickBorder) && pickBorder.lightness > pick.lightness + 0.1)
        #expect(Self.isLilac(tag) && tag.lightness > 1.5)
        #expect(!Self.isLilac(other) && fill > 0.15 && border > fill + 0.1)
        #expect(Self.isPrimary(try Self.brightest(drawn, in: CGRect(x: second.minX + 12, y: second.minY, width: 12, height: 38))))
        #expect(abs(Self.light(drawn, at: CGPoint(x: second.minX + 8, y: second.midY)) - fill) < 0.02)
    }

    /// In the light, Claude's pick and its tag are the board pane's darker lilac, #7178C7: its tag darker than the
    /// dark's #9AA2EE, and still lilac.
    @available(macOS 26, *)
    @Test func inTheLightThePickIsADarkerLilac() throws {
        let (light, asks) = try Self.drawn(over: .white, scheme: .light), (dark, _) = try Self.drawn()
        let first = Self.placed(asks.layout.answers[0])
        let lightTag = try #require(light.pixels(in: Self.tagBox(first)).min { $0.lightness < $1.lightness })
        let darkTag = try dark.brightest(in: Self.tagBox(first))
        let border = try #require(light.pixel(at: CGPoint(x: first.midX, y: first.minY + 0.25)))

        #expect(Self.isLilac(lightTag) && lightTag.lightness < darkTag.lightness - 0.3)
        #expect(Self.isLilac(border))
    }

    /// Under the pointer each row is a step stronger, Claude's pick still lilac.
    @available(macOS 26, *)
    @Test(arguments: [0, 1])
    func anAnswersRowLiftsUnderThePointer(row: Int) throws {
        let (resting, asks) = try Self.drawn(), (lifted, _) = try Self.drawn(hover: .answer(row))
        let box = Self.placed(asks.layout.answers[row]), point = CGPoint(x: box.maxX - 20, y: box.midY)

        #expect(Self.light(lifted, at: point) > Self.light(resting, at: point) + 0.08)
        #expect(try Self.isLilac(#require(lifted.pixel(at: point))) == (row == 0))
    }

    /// Lee switched every Snooze time off: nothing drawn where Snooze ▾ stood.
    @available(macOS 26, *)
    @Test func withNoSnoozeTimeOfferedItsFootHasNoSnooze() throws {
        let (offered, asks) = try Self.drawn(), (none, _) = try Self.drawn(offersSnooze: false)
        let snooze = Self.placed(try #require(asks.layout.snooze))

        #expect(Self.isSecondary(try Self.brightest(offered, in: snooze)))
        #expect(try Self.brightest(none, in: snooze) < 0.02)
    }

    /// A words ask draws no row between its age and its foot, whose Open in Claude it has.
    @available(macOS 26, *)
    @Test func aWordsAskHasNoRowsAndItsFootsOpenInClaude() throws {
        let (drawn, asks) = try Self.drawn(Self.words, pages: 1), layout = asks.layout
        let gap = layout.foot.minY - layout.age.maxY
        let between = Self.placed(CGRect(x: layout.foot.minX, y: layout.age.maxY + 2, width: layout.foot.width, height: gap - 4))
        let open = Self.placed(layout.open)

        #expect(try Self.brightest(drawn, in: between) < 0.02)
        #expect(Self.light(drawn, at: CGPoint(x: open.midX, y: open.minY + 0.25)) > 0.2)
    }

    @available(macOS 26, *)
    @Test func openInClaudeIsAnOutlinedPill() throws {
        let (drawn, asks) = try Self.drawn(), open = Self.placed(asks.layout.open)

        #expect(Self.light(drawn, at: CGPoint(x: open.midX, y: open.minY + 0.25)) > 0.2)
        #expect(Self.light(drawn, at: CGPoint(x: open.minX + 6, y: open.midY)) < 0.02)
        #expect(Self.isPrimary(try Self.brightest(drawn, in: open.insetBy(dx: 10, dy: 4))))
    }

    // MARK: Sending

    private static let held = Sending(row: 0, words: "Threaded", heldAt: 4 * 60_000, goesAt: 4 * 60_000 + 2000)

    /// "Sending Threaded" in the dark: its row white, a check in ink at its trailing end, the words in the primary,
    /// and Undo outlined.
    @available(macOS 26, *)
    @Test func aHeldAnswersRowIsWhiteWithInkInTheDark() throws {
        let (drawn, asks) = try Self.drawn(sending: Self.held)
        let row = Self.placed(asks.layout.answers[0]), undo = Self.placed(asks.layout.undo)
        let check = AsksLayout.check(in: row.size).offsetBy(dx: row.minX, dy: row.minY)

        #expect(try #require(drawn.pixel(at: CGPoint(x: row.minX + 36, y: row.minY + 4))).isWhite)
        #expect(try #require(drawn.pixels(in: check).min { $0.lightness < $1.lightness }).lightness < 0.5)
        #expect(Self.isPrimary(try Self.brightest(drawn, in: Self.placed(asks.layout.sending))))
        #expect(Self.light(drawn, at: CGPoint(x: undo.midX, y: undo.minY + 0.25)) > 0.2)
    }

    /// In the light, over a white desk, the held row is the primary made opaque, near black, and its check, words and
    /// "Recommended" are light on it, the tag at half.
    @available(macOS 26, *)
    @Test func aHeldAnswersRowIsNearBlackWithLightWordsInTheLight() throws {
        let (drawn, asks) = try Self.drawn(sending: Self.held, over: .white, scheme: .light)
        let row = Self.placed(asks.layout.answers[0])
        let check = AsksLayout.check(in: row.size).offsetBy(dx: row.minX, dy: row.minY)
        let label = CGRect(x: row.minX + 12, y: row.minY + 8, width: 40, height: 22)
        let note = Self.tagBox(row)

        #expect(Self.light(drawn, at: CGPoint(x: row.minX + 36, y: row.minY + 4)) < 0.3)
        #expect(try Self.brightest(drawn, in: check) > 2.4)
        #expect(try Self.brightest(drawn, in: label) > 2.4)
        #expect((1.0 ... 2.2).contains(try Self.brightest(drawn, in: note)))
    }

    /// Half a second into its two, the arc runs from 12 o'clock clockwise round to 9, three quarters of the ring: lit
    /// down the right and across the bottom, the track bare between 9 and 12. An arc from any other start fails.
    @available(macOS 26, *)
    @Test func theCountdownIsThreeQuartersLeftHalfASecondIn() throws {
        let (drawn, asks) = try Self.drawn(sending: Self.held, heldFor: 500), ring = Self.placed(asks.layout.countdown)
        let at = { (x: Double, y: Double) in CGRect(x: ring.midX + x - 1, y: ring.midY + y - 1, width: 2, height: 2) }

        #expect(Self.isSecondary(try Self.brightest(drawn, in: at(3.4, -3.4))))
        #expect(Self.isSecondary(try Self.brightest(drawn, in: at(3.4, 3.4))))
        #expect(Self.isSecondary(try Self.brightest(drawn, in: at(-3.4, 3.4))))
        #expect(try Self.brightest(drawn, in: at(-3.4, -3.4)) < 0.6)
    }

    /// It is drawn again for what it shows, and how long ago its ask is worded, never for the clock alone: the
    /// countdown runs on its own.
    @available(macOS 26, *)
    @Test func itIsDrawnAgainOnlyAsWhatItShowsChanges() throws {
        let layout = AsksLayout(Self.choice, measure: .drawn)
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: Self.helpDesk, ask: Self.choice, page: 0, pages: 2, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: nil, hover: nil
        )
        let panel = { (asks: AsksShown, asked: String, now: Double) in
            GlassAsksPanel(asks: asks, pointsLeft: false, asked: asked, now: now)
        }
        let lifted = AsksShown(
            row: asks.row, session: asks.session, ask: asks.ask, page: 0, pages: 2, layout: layout, frame: asks.frame,
            sending: nil, hover: .answer(0)
        )

        #expect(panel(asks, "Asked 4m ago", 0) == panel(asks, "Asked 4m ago", 16))
        #expect(panel(asks, "Asked 4m ago", 0) != panel(asks, "Asked 5m ago", 0))
        #expect(panel(asks, "Asked 4m ago", 0) != panel(lifted, "Asked 4m ago", 0))
    }

    /// A name's box, and an answer's lines', a point wider than Core Text sets the words, so SwiftUI never cuts them a
    /// hair early; the project still 8 after the name as set, so the black draws as it did.
    @Test func wordsSetWholeHaveAPointToSpare() throws {
        let layout = AsksLayout(Self.choice, measure: .drawn)
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: Self.helpDesk, ask: Self.choice, page: 0, pages: 1, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: nil, hover: nil
        )
        let name = TextLine.width(TextLine.text(Self.helpDesk.name, EdgeStyle.asksName, EdgeStyle.ink))
        let top = AsksPanelParts.top(asks)
        let line = try #require(AsksPanelParts.answerLines(0, of: asks).first).box

        #expect(top.name.width == name + 1 && top.project.minX == top.name.minX + name + 8)
        #expect(line.minX == 12 && line.width == AsksLayout.answerWidth + 1)
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
