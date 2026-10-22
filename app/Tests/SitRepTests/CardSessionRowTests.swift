import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// A row on the black card as Paper's board F draws it, taken relative to the built row: a Needs you row is its
/// session, one row of standard height whatever its count, its name over its project, a quiet "+2" 6 after the name for
/// its lines after the first; under the pointer any row's time gives way to its button, 24 square on the row's middle,
/// and its right-click menu offers to open it in SitRep or jump to its window. Read from its pixels at 2×.
@MainActor
struct CardSessionRowTests {
    private static let width = 344.0
    private static let name = "Harness modernisation"
    private static let titles = [
        "Approve the first fix batch", "Choose how the release notes are grouped", "Paste the failing output",
    ]

    private static func harness(_ count: Int, name: String = name, away: Bool = false) -> Session {
        Session(
            id: "sr-4g01a7", project: "Harness", name: name, kind: .needs, away: away,
            lines: titles.prefix(count).enumerated().map { Session.Line(title: $1, since: Double($0) * 3_600_000) },
            sub: away ? "No window holds it. Carry it on in Claude." : "Harness"
        )
    }

    /// The row as the panel lays it out: its item's height, less the gap under it.
    private static func card(_ session: Session) -> SessionRow {
        let row = SessionRow(session, size: CGSize(width: width, height: Item.session(session).height - Item.rowGap))

        row.showAge(at: 5 * 3_600_000)
        return row
    }

    private static let ground = CGPoint(x: 2, y: 2)

    private static func nameWidth(_ name: String = name) -> CGFloat {
        TextLine.width(TextLine.text(name, EdgeStyle.title, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.title)))
    }

    /// 55 and the gap under it, however many lines wait.
    @Test(arguments: [1, 2, 3])
    func aRowIsOneRowOfStandardHeight(count: Int) {
        #expect(Item.session(Self.harness(count)).height == 55 + Item.rowGap)
    }

    /// Its dot at 16 by 19; its session's name from 32, medium, none of its asks' words; its project at 32 by 28; its
    /// time in the lane ending at 334; nothing under the first line but the project.
    @Test func aRowNeedingLeeIsItsNameOverItsProject() throws {
        let drawn = try Drawn(Self.card(Self.harness(1)).layer)
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 10, width: 22, height: 18), ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 8, width: 270, height: 22), ground: Self.ground))
        let project = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 28, width: 270, height: 16), ground: Self.ground))
        let projectWidth = TextLine.width(TextLine.text("Harness", EdgeStyle.sub, EdgeStyle.ink2))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 10, width: 54, height: 18), ground: Self.ground))

        #expect(abs(dot.midX - 16) <= 0.5 && abs(dot.midY - 19) <= 0.5)
        #expect((32 ... 33.5).contains(words.minX))
        #expect(abs(words.width - Self.nameWidth()) <= 1.5)
        // drawn inside its set width by the glyphs' side bearings
        #expect((32 ... 33.5).contains(project.minX))
        #expect(project.width <= projectWidth + 0.5 && project.width >= projectWidth - 3)
        #expect((332.5 ... 334.5).contains(age.maxX))
        #expect(drawn.drawnBox(in: CGRect(x: 4, y: 44, width: 340, height: 11), ground: Self.ground) == nil)
    }

    /// "+2" for two lines after the first: 13 medium in tabular figures, 6 after the name, on its baseline.
    @Test func severalLinesShowACount6AfterTheNameOnItsBaseline() throws {
        let drawn = try Drawn(Self.card(Self.harness(3)).layer)
        let after = 32 + Self.nameWidth()
        let name = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 8, width: after - 26, height: 22), ground: Self.ground))
        let count = try #require(drawn.drawnBox(in: CGRect(x: after + 2, y: 8, width: 40, height: 22), ground: Self.ground))
        let set = TextLine.width(TextLine.text("+2", EdgeStyle.count, EdgeStyle.ink2))

        #expect(abs(count.minX - (after + 6)) <= 1.5)
        #expect(abs(count.width - set) <= 1.5)
        #expect(abs(count.maxY - name.maxY) <= 0.5)
    }

    /// A name too long for the line is cut short before its count, which shows whole, 6 after it, inside the line.
    @Test func aLongNameIsCutShortBeforeItsCount() throws {
        let long = String(repeating: "Finish the Harness modernisation ", count: 3)
        let drawn = try Drawn(Self.card(Self.harness(2, name: long)).layer)
        let line = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 8, width: 270, height: 22), ground: Self.ground))
        let set = TextLine.width(TextLine.text("+1", EdgeStyle.count, EdgeStyle.ink2))
        let room = 256 - set - 6
        let cut = TextLine(
            TextLine.text(long, EdgeStyle.title, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.title)),
            in: CGRect(x: 0, y: 0, width: room, height: 18)
        ).width
        let name = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 8, width: 6 + cut, height: 22), ground: Self.ground))
        let count = try #require(drawn.drawnBox(
            in: CGRect(x: 32 + cut + 2, y: 8, width: 256 - cut, height: 22), ground: Self.ground
        ))

        #expect(line.maxX <= 288.5)
        #expect(cut <= room && cut > room - 20)
        #expect(name.maxX <= 32 + cut + 0.5)
        #expect(abs(count.minX - (32 + cut + 6)) <= 1.5)
        // drawn inside its set width by the figures' side bearings
        #expect(count.width <= set + 0.5 && count.width >= set - 3)
    }

    /// Under the pointer the time gives way to the button: 24 square, its right at 334, on the row's middle, its
    /// glyph 13 by 11 on its middle.
    @Test func underThePointerTheButtonTakesTheTimesPlace() throws {
        let row = Self.card(Self.harness(1, away: true))

        row.isHighlighted = true

        let drawn = try Drawn(row.layer)
        let button = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 0, width: 54, height: 55), ground: Self.ground))
        let glyph = try #require(drawn.drawnBox(
            in: button.insetBy(dx: 2, dy: 2), ground: CGPoint(x: button.minX + 2, y: button.midY)
        ))

        #expect(abs(button.width - 24) <= 1 && abs(button.height - 24) <= 1)
        #expect(abs(button.maxX - 334) <= 0.5 && abs(button.midY - 27.5) <= 0.5)
        #expect(abs(glyph.width - 13) <= 1 && abs(glyph.height - 11) <= 1)
        #expect(abs(glyph.midX - button.midX) <= 0.5 && abs(glyph.midY - button.midY) <= 0.5)
    }

    /// Board F's button on a one-line your-turn row too, on its 30's middle.
    @Test func aOneLineRowsButtonSitsOnItsMiddle() {
        let turn = Session(id: "t", project: "Fumi", kind: .turn, title: "Sketched", sub: "", since: 0)
        let row = SessionRow(turn, size: CGSize(width: Self.width, height: Item.turnHeight), oneLine: true)

        #expect(row.opener.frame == CGRect(x: 310, y: 3, width: 24, height: 24))
        #expect(row.opener.cornerRadius == 7 && row.opener.backgroundColor == EdgeStyle.opener)
    }

    /// A row a window holds lifts under the pointer as before, its button over the lift; an away row takes no fill,
    /// but shows its button. Pressed in, the button gives way to the spinner.
    @Test(arguments: [false, true])
    func underThePointerOnlyARowThatJumpsLifts(away: Bool) {
        let row = Self.card(Self.harness(1, away: away))

        row.isHighlighted = true
        #expect(row.layer.backgroundColor == (away ? nil : EdgeStyle.hover))
        #expect(!row.opener.isHidden)

        row.isPressed = true
        #expect(row.opener.isHidden)

        row.isPressed = false
        row.isHighlighted = false
        #expect(row.opener.isHidden)
    }

    /// Off the row, its time in the lane ending at 334, as tall as its figures; under the pointer, the button's glyph
    /// alone on the button, the time gone from under it (`underThePointerTheButtonTakesTheTimesPlace`).
    @Test func offTheRowItsTimeShows() throws {
        let drawn = try Drawn(Self.card(Self.harness(1, away: true)).layer)
        let time = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 0, width: 54, height: 55), ground: Self.ground))

        #expect(time.height < 12 && abs(time.maxX - 334) <= 1.5)
    }

    /// The right-click menu: Open in SitRep, then Jump to the window, disabled on an away row; each for its session.
    @Test(arguments: [false, true])
    func theMenuOpensOrJumpsJumpingDisabledAway(away: Bool) {
        let target = NSObject()
        let menu = CardRowMenu.make(
            for: Self.harness(1, away: away), target: target, open: #selector(NSObject.copy), jump: #selector(NSObject.mutableCopy)
        )

        #expect(menu.items.map(\.title) == ["Open in SitRep", "Jump to the window"])
        #expect(menu.items.map(\.isEnabled) == [true, !away])
        #expect(menu.items.map { $0.representedObject as? String } == ["sr-4g01a7", "sr-4g01a7"])
        #expect(menu.items.map(\.action) == [#selector(NSObject.copy), #selector(NSObject.mutableCopy)])
        #expect(menu.items.allSatisfy { $0.target === target })
    }
}
