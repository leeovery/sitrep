import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// A row on the black card, on one line as Paper's board J draws it, taken relative to the built row: a Needs you row
/// is its session, one row of standard height whatever its count, its name and a quiet "3" 6 after it for its three
/// lines waiting, its project at the right, its time at the right under the pointer as off it (its right-click menu
/// is `RowMenuTests`'). Read from its pixels at 2×.
@MainActor
struct CardSessionRowTests {
    private static let width = 344.0
    /// Without a descender, so its drawn box ends on its baseline, as the count's does.
    private static let name = "Finish the rollout"
    private static let titles = [
        "Approve the first fix batch", "Choose how the release notes are grouped", "Paste the failing output",
    ]

    private static func tailspin(_ count: Int, name: String = name, away: Bool = false) -> Session {
        Session(
            id: "sr-4t2kq8", project: "Tailspin", name: name, kind: .needs, away: away,
            lines: titles.prefix(count).enumerated().map { Session.Line(title: $1, since: Double($0) * 3_600_000) },
            sub: away ? "No window holds it. Carry it on in Claude." : "Tailspin"
        )
    }

    /// The row as the card lays it out, on one line.
    private static func card(_ session: Session) -> SessionRow {
        let row = SessionRow(session, size: CGSize(width: width, height: Item.lineHeight))

        row.showAge(at: 5 * 3_600_000)
        return row
    }

    private static let ground = CGPoint(x: 2, y: 2)

    private static func nameWidth(_ name: String = name) -> CGFloat {
        TextLine.width(TextLine.text(name, EdgeStyle.lineMedium, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.lineMedium)))
    }

    private static let projectWidth = TextLine.width(TextLine.text("Tailspin", EdgeStyle.sub, EdgeStyle.ink3))

    /// 30, however many lines wait.
    @Test(arguments: [1, 2, 3])
    func aRowIsOneRowOfStandardHeight(count: Int) {
        #expect(Item.line(Self.tailspin(count)).height == 30)
    }

    /// Its dot at 16 by 15; its session's name from 32, 13 medium, none of its asks' words; its project at the right,
    /// ending 10 before the time's lane; its time in the lane ending at 334; its lift's corners 10.
    @Test func aRowNeedingLeeIsItsNameAndItsProject() throws {
        let drawn = try Drawn(Self.card(Self.tailspin(1)).layer)
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 4, width: 22, height: 22), ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 200, height: 22), ground: Self.ground))
        let project = try #require(drawn.drawnBox(
            in: CGRect(x: 288 - Self.projectWidth - 1, y: 4, width: Self.projectWidth + 2, height: 22), ground: Self.ground
        ))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 4, width: 54, height: 22), ground: Self.ground))

        #expect(abs(dot.midX - 16) <= 0.5 && abs(dot.midY - 15) <= 0.5)
        #expect((32 ... 33.5).contains(words.minX))
        #expect(abs(words.width - Self.nameWidth()) <= 1.5)
        // drawn inside its set width by its letters' side bearings
        #expect(abs(project.maxX - 288) <= 1 && project.width <= Self.projectWidth + 0.5 && project.width >= Self.projectWidth - 3)
        #expect((332.5 ... 334.5).contains(age.maxX))
        #expect(Self.card(Self.tailspin(1)).layer.cornerRadius == 10)
    }

    /// "3" for three lines waiting: 13 medium in tabular figures, 6 after the name, on its baseline.
    @Test func severalLinesShowACount6AfterTheNameOnItsBaseline() throws {
        let drawn = try Drawn(Self.card(Self.tailspin(3)).layer)
        let after = 32 + Self.nameWidth()
        let name = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: after - 26, height: 22), ground: Self.ground))
        let count = try #require(drawn.drawnBox(in: CGRect(x: after + 2, y: 4, width: 40, height: 22), ground: Self.ground))
        let set = TextLine.width(TextLine.text("3", EdgeStyle.count, EdgeStyle.ink2))

        #expect(abs(count.minX - (after + 6)) <= 1.5)
        #expect(abs(count.width - set) <= 1.5)
        #expect(abs(count.maxY - name.maxY) <= 0.5)
    }

    /// A name too long for the line is cut short before its count, which shows whole, 6 after it, 12 before its
    /// project.
    @Test func aLongNameIsCutShortBeforeItsCount() throws {
        let long = String(repeating: "Finish the Tailspin migration ", count: 3)
        let drawn = try Drawn(Self.card(Self.tailspin(2, name: long)).layer)
        let words = 256 - Self.projectWidth - SessionRowLayout.projectGap
        let set = TextLine.width(TextLine.text("2", EdgeStyle.count, EdgeStyle.ink2))
        let room = words - set - 6
        let cut = TextLine(
            TextLine.text(long, EdgeStyle.lineMedium, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.lineMedium)),
            in: CGRect(x: 0, y: 0, width: room, height: 18)
        ).width
        let name = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + cut, height: 22), ground: Self.ground))
        let count = try #require(drawn.drawnBox(
            in: CGRect(x: 32 + cut + 2, y: 4, width: words - cut, height: 22), ground: Self.ground
        ))

        #expect(cut <= room && cut > room - 20)
        #expect(name.maxX <= 32 + cut + 0.5)
        #expect(abs(count.minX - (32 + cut + 6)) <= 1.5)
        // drawn inside its set width by the figures' side bearings
        #expect(count.width <= set + 0.5 && count.width >= set - 3)
        #expect(count.maxX <= 32 + words + 0.5)
    }

    /// Every row lifts under the pointer, an away one too, as its click carries its session on (stage 8).
    @Test(arguments: [false, true])
    func underThePointerEveryRowLifts(away: Bool) {
        let row = Self.card(Self.tailspin(1, away: away))

        row.isHighlighted = true
        #expect(row.layer.backgroundColor == EdgeStyle.hover)

        row.isHighlighted = false
        #expect(row.layer.backgroundColor == nil)
    }

    /// Tailspin's two asks asleep, the sooner waking a day after the time the rows are drawn at; away, or a window
    /// holding it.
    private static func asleep(away: Bool = false) -> Session {
        Session(
            id: "sr-4t2kq8", project: "Tailspin", name: name, kind: .snoozed, away: away,
            lines: titles.prefix(2).enumerated().map { Session.Line(ask: "k\($0)", title: $1, since: 0) }, sub: "Tailspin",
            wakesAt: 29 * 3_600_000
        )
    }

    /// A Snoozed row is a Needs you row quieted (board G), the same away or not: its dot 7 across with no glow, on the
    /// row's middle, its orange dimmed (`NeedsYouMarksTests`); its name 13 in the soft grey a Needs you row's count
    /// takes;
    /// its project in a lane at its right, ending 10 before the time's; and in its time's place, in the soft grey too,
    /// when it wakes, its lane grown past the 36 to fit it, still ending at 334.
    @Test(arguments: [false, true])
    func aSnoozedRowIsANeedsYouRowQuietedOnOneLineWithWhenItWakes(away: Bool) throws {
        let asleep = Self.asleep(away: away)
        let row = Self.card(asleep)
        let drawn = try Drawn(row.layer), needs = try Drawn(Self.card(Self.tailspin(2)).layer)
        let words = TextLine.text(asleep.timeText(at: 5 * 3_600_000, in: WakeTime.calendar), EdgeStyle.age, EdgeStyle.ink2)
        let wide = TextLine.width(words)
        let lane = CGRect(x: 324 - wide - Self.projectWidth - 1, y: 4, width: Self.projectWidth + 2, height: 22)
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 4, width: 22, height: 22), ground: Self.ground))
        let wakes = try #require(drawn.drawnBox(in: CGRect(x: 330 - wide, y: 4, width: wide + 14, height: 22), ground: Self.ground))
        let project = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let name = CGRect(x: 32, y: 6, width: 100, height: 18)
        let soft = try needs.brightest(in: CGRect(x: 32 + Self.nameWidth() + 3, y: 4, width: 30, height: 22))

        #expect(row.layer.bounds.height == 30 && row.layer.cornerRadius == 10)
        #expect(abs(dot.width - 7) <= 1 && abs(dot.height - 7) <= 1 && abs(dot.midY - 15) <= 0.5)
        #expect(try drawn.brightest(in: project).lightness < soft.lightness - 0.3)
        #expect(abs(project.maxX - (324 - wide)) <= 1)
        #expect(try drawn.brightest(in: name).isAlike(soft))
        #expect(try drawn.brightest(in: wakes).isAlike(soft))
        #expect((332.5 ... 334.5).contains(wakes.maxX))
        #expect(abs(wakes.width - wide) <= 1.5 && wakes.width > 36)
    }

    /// Tailspin's turn snoozed, until it moves, or waking a day after the time the rows are drawn at.
    private static func turnAsleep(wakesAt: Double?) -> Session {
        Session(
            id: "sr-4t2kq8", project: "Tailspin", name: name, kind: .snoozedTurn,
            lines: [Session.Line(title: "Stage 2 is in", since: 0)], sub: "Tailspin", wakesAt: wakesAt
        )
    }

    /// A turn snoozed, as board I draws it but for its mark: a dot 7 across, its blue dimmed (`NeedsYouMarksTests`), as
    /// a snoozed ask's is its orange dimmed (13 November 2026; a ring 9 across in the faint grey until then); its
    /// session's name 13 in the soft grey; its project in the lane at its right; and in its time's place, in the soft
    /// grey too, when it wakes, or "until it moves", its lane grown to fit, still ending at 334.
    @Test(arguments: [nil, 29 * 3_600_000.0])
    func aSnoozedTurnIsADimmedDotItsNameSoftAndWhenItWakesOrUntilItMoves(wakesAt: Double?) throws {
        let asleep = Self.turnAsleep(wakesAt: wakesAt)
        let drawn = try Drawn(Self.card(asleep).layer), needs = try Drawn(Self.card(Self.tailspin(2)).layer)
        let time = asleep.timeText(at: 5 * 3_600_000, in: WakeTime.calendar)
        let wide = TextLine.width(TextLine.text(time, EdgeStyle.age, EdgeStyle.ink2))
        let lane = CGRect(x: 324 - wide - Self.projectWidth - 1, y: 4, width: Self.projectWidth + 2, height: 22)
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 4, width: 22, height: 22), ground: Self.ground))
        let project = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let wakes = try #require(drawn.drawnBox(in: CGRect(x: 330 - wide, y: 4, width: wide + 14, height: 22), ground: Self.ground))
        let soft = try needs.brightest(in: CGRect(x: 32 + Self.nameWidth() + 3, y: 4, width: 30, height: 22))

        #expect((time == WakeTime.untilItMoves) == (wakesAt == nil))
        #expect(abs(dot.width - 7) <= 1 && abs(dot.height - 7) <= 1)
        #expect(abs(dot.midX - 16) <= 0.5 && abs(dot.midY - 15) <= 0.5)
        #expect(abs(project.maxX - (324 - wide)) <= 1)
        #expect(try drawn.brightest(in: CGRect(x: 32, y: 6, width: 100, height: 18)).isAlike(soft))
        #expect(try drawn.brightest(in: wakes).isAlike(soft))
        #expect((332.5 ... 334.5).contains(wakes.maxX))
        #expect(abs(wakes.width - wide) <= 1.5)
    }

    /// Its lane grown to fit when it wakes, its words laid out again are drawn at the row's scale, as on Retina, its
    /// project among them.
    @Test func aSnoozedRowsLinesLaidOutAgainAreAtItsScale() {
        let row = SessionRow(Self.asleep(), size: CGSize(width: Self.width, height: Item.lineHeight))

        rescale(row.layer, to: 2)
        row.showAge(at: 5 * 3_600_000)

        let lines = (row.layer.sublayers ?? []).filter { $0 is TextLine }

        #expect(lines.count >= 3)
        #expect(lines.allSatisfy { $0.contentsScale == 2 })
    }

    /// Its time in the lane ending at 334, as tall as its figures, off the row and under the pointer alike, over the
    /// lift of a row that jumps as over the bare black of an away one: nothing takes its place. Read against what is
    /// drawn just left of the lane, inside the lift's corners.
    @Test(arguments: [false, true], [false, true])
    func itsTimeShowsUnderThePointerAsOffIt(highlighted: Bool, away: Bool) throws {
        let row = Self.card(Self.tailspin(1, away: away))

        row.isHighlighted = highlighted

        let drawn = try Drawn(row.layer)
        let time = try #require(drawn.drawnBox(
            in: CGRect(x: 290, y: 4, width: 50, height: 22), ground: CGPoint(x: 292, y: 15)
        ))

        #expect(time.height < 12 && abs(time.maxX - 334) <= 1.5)
    }
}
