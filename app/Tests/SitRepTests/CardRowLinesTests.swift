import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// A Needs you row on the black card, one shape whatever its count, as Paper's board D draws Harness's three asks,
/// taken relative to the built row: each ask a line of its own, its dot, its words in medium and its age, 22 under the
/// last; its project and session under the last line as under a row's one; one press across them all. One ask is that
/// shape with one line, as built. Read from its pixels at 2×.
@MainActor
struct CardRowLinesTests {
    private static let width = 344.0
    private static let titles = [
        "Approve the first fix batch", "Choose how the release notes are grouped", "Paste the failing output",
    ]

    private static func harness(_ count: Int) -> Session {
        Session(
            id: "sr-4g01a7", project: "Harness", kind: .needs,
            lines: titles.prefix(count).enumerated().map { Session.Line(title: $1, since: Double($0) * 3_600_000) },
            sub: "Harness · Finish the Harness modernisation"
        )
    }

    /// The row as the panel lays it out: its item's height, less the gap under it.
    private static func card(_ session: Session) throws -> (row: SessionRow, drawn: Drawn) {
        let row = SessionRow(session, size: CGSize(width: width, height: Item.session(session).height - Item.rowGap))

        row.showAge(at: 5 * 3_600_000)
        return (row, try Drawn(row.layer))
    }

    private static let ground = CGPoint(x: 2, y: 2)

    /// 55 for one line, as built; each line more its 18 and the 4 over it.
    @Test(arguments: [(1, 55.0), (2, 77), (3, 99)])
    func aRowIsAsTallAsItsLines(count: Int, height: Double) {
        #expect(Item.session(Self.harness(count)).height == height + Item.rowGap)
    }

    /// Each line's dot centred in the 12 mark lane at 16, 9 down its 18; its words from 32 inside its 18; its age right
    /// in the 36 time lane, ending at 334; each line 22 under the last.
    @Test func eachLineSitsUnderTheLastWithItsDotItsWordsAndItsAge() throws {
        let drawn = try Self.card(Self.harness(3)).drawn

        for line in 0 ..< 3 {
            let top = 10 + 22 * Double(line)
            let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: top, width: 22, height: 18), ground: Self.ground))
            let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: top - 2, width: 200, height: 22), ground: Self.ground))
            let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: top, width: 54, height: 18), ground: Self.ground))

            #expect(abs(dot.midX - 16) <= 0.5 && abs(dot.midY - (top + 9)) <= 0.5)
            #expect((32 ... 33.5).contains(words.minX))
            #expect(words.minY >= top && words.maxY <= top + 18)
            #expect((332.5 ... 334.5).contains(age.maxX))
            #expect(age.minY >= top && age.maxY <= top + 18)
        }
    }

    /// The project and session's line sits under the last line as under a row's one: at 28 on a row of one, 72 on a
    /// row of three, drawn alike in its 16, and nothing beside it in the mark's lane or the time's.
    @Test func theSecondLineSitsUnderTheLastLine() throws {
        let one = try Self.card(Self.harness(1)).drawn, three = try Self.card(Self.harness(3)).drawn
        let sub = try #require(one.drawnBox(in: CGRect(x: 26, y: 28, width: 300, height: 16), ground: Self.ground))
        let under = try #require(three.drawnBox(in: CGRect(x: 26, y: 72, width: 300, height: 16), ground: Self.ground))

        #expect((32 ... 33.5).contains(sub.minX))
        #expect(under == sub.offsetBy(dx: 0, dy: 44))
        #expect(three.drawnBox(in: CGRect(x: 4, y: 72, width: 22, height: 16), ground: Self.ground) == nil)
        #expect(three.drawnBox(in: CGRect(x: 290, y: 72, width: 54, height: 16), ground: Self.ground) == nil)
    }

    /// One ask is the shape with one line: its parts in the built row's boxes, the mark at 16 by 19, the title at 32
    /// by 10, its second line at 32 by 28, its time in the lane at 298.
    @Test func oneLineIsTheBuiltRow() {
        let at = SessionRowLayout(size: CGSize(width: Self.width, height: 55), lines: 1)

        #expect(at.lines.count == 1)
        #expect(at.mark == CGPoint(x: 16, y: 19))
        #expect(at.title == CGRect(x: 32, y: 10, width: 256, height: 18))
        #expect(at.sub == CGRect(x: 32, y: 28, width: 256, height: 16))
        #expect(at.age == CGRect(x: 298, y: 10, width: 36, height: 18))
    }

    /// Every ask's words in medium, as the card's other titles, not semibold: one line drawn as wide as its words set
    /// in medium.
    @Test(arguments: [1, 3])
    func anAsksWordsAreMedium(count: Int) throws {
        let drawn = try Self.card(Self.harness(count)).drawn
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 8, width: 260, height: 22), ground: Self.ground))
        let medium = TextLine.width(TextLine.text(Self.titles[0], EdgeStyle.title, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.title)))
        let semibold = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let bolder = TextLine.width(TextLine.text(Self.titles[0], semibold, EdgeStyle.ink, kern: EdgeStyle.tightKern(semibold)))

        #expect(abs(words.width - medium) <= 1.5)
        #expect(bolder - medium > 2)
    }

    /// One press across the row: an arc spins in the first line's time lane, and no line shows its time meanwhile.
    /// Pressed in, the row's fill is the ground, read in the time lane under its lines.
    @Test func aPressedRowHidesEveryLinesTime() throws {
        let row = try Self.card(Self.harness(3)).row

        row.isPressed = true

        let drawn = try Drawn(row.layer), fill = CGPoint(x: 310, y: 80)

        #expect(drawn.drawnBox(in: CGRect(x: 290, y: 10, width: 48, height: 18), ground: fill) != nil)
        for line in 1 ..< 3 {
            let top = 10 + 22 * Double(line)

            #expect(drawn.drawnBox(in: CGRect(x: 290, y: top, width: 48, height: 18), ground: fill) == nil)
        }
    }

    /// One lift across the row: under the pointer the whole row lifts, every line with it.
    @Test func underThePointerTheWholeRowLifts() throws {
        let row = try Self.card(Self.harness(3)).row

        row.isHighlighted = true
        #expect(row.layer.backgroundColor == EdgeStyle.hover)
        #expect(row.layer.bounds.height == 99)
    }
}
