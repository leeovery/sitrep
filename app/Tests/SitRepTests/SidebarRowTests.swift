import AppKit
@testable import SitRep
import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// A sidebar row as Paper's board F draws it, drawn alone as a still, 296 wide, its words 16 in: a Needs you row is its
/// session's name, a quiet "+2" 5 after it, over its project; under the pointer a row a window holds gives its time's
/// place to a 22 square button on its middle, its right where the time ends, which jumps to its window; an away row
/// shows none.
@MainActor
struct SidebarRowTests {
    private static let width: CGFloat = 296
    nonisolated static let now = Date(timeIntervalSince1970: 1_792_445_000)
    private static let ground = CGPoint(x: 4, y: 4)

    nonisolated static func needs(lines: Int, away: Bool = false) -> Listed.Row {
        Listed.Row(
            id: "sr-4g01a7", name: "Harness modernisation", project: "Harness", section: .needsYou, mark: .needs,
            isAway: away, since: now.addingTimeInterval(-3600),
            lines: (0 ..< lines).map { Listed.Line(id: "ask:\($0)", lead: "Ask \($0)", code: nil, more: nil, since: now) }
        )
    }

    nonisolated static let working = Listed.Row(
        id: "sr-macapp", name: "The Mac app", project: "SitRep", section: .working, mark: .working, isAway: false,
        since: now, lines: [Listed.Line(id: "turn:sr-macapp", lead: "Reading", code: "Board.swift", more: nil, since: now)]
    )

    nonisolated static let turn = Listed.Row(
        id: "sr-v3t7a0", name: "Licensing", project: "Fumi", section: .yourTurn, mark: .turn, isAway: false, since: now,
        lines: [Listed.Line(id: "turn:sr-v3t7a0", lead: "Sketched", code: nil, more: nil, since: now)]
    )

    /// The row drawn as a still, the pointer over it or not.
    private static func drawn(_ row: Listed.Row, hovered: Bool = false) throws -> Drawn {
        let height = row.section == .yourTurn ? WindowStyle.oneLineHeight : WindowStyle.twoLineHeight
        let line = SidebarLine(line: .session(row), isRuled: false, picked: nil, filter: Filter(), now: now)
            .environment(\.isStill, true)
            .environment(\.isHoveredStill, hovered)

        return try Drawn(line, size: CGSize(width: width, height: height))
    }

    /// Its name from 46, then "+2" 5 after it on its baseline, 12 medium in tabular figures; one line, its name alone;
    /// its project 1 under, 14 tall.
    @Test func aNeedsYouRowIsItsNameAndItsCountOverItsProject() throws {
        let one = try Self.drawn(Self.needs(lines: 1)), three = try Self.drawn(Self.needs(lines: 3))
        let title = CGRect(x: 42, y: 4, width: 220, height: 16)
        let name = try #require(one.drawnBox(in: title, ground: Self.ground))
        let named = try #require(three.drawnBox(in: CGRect(x: 42, y: 4, width: name.maxX - 42 + 0.5, height: 16), ground: Self.ground))
        let count = try #require(three.drawnBox(
            in: CGRect(x: name.maxX + 2, y: 4, width: 40, height: 16), ground: Self.ground
        ))
        let set = NSAttributedString(string: "+2", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        ]).size().width
        let project = try #require(one.drawnBox(in: CGRect(x: 42, y: 21, width: 200, height: 14), ground: Self.ground))

        #expect((46 ... 47.5).contains(name.minX))
        #expect(named == name)
        #expect(abs(count.minX - (name.maxX + 5)) <= 1.5)
        #expect(abs(count.width - set) <= 1.5)
        #expect(abs(count.maxY - name.maxY) <= 0.5)
        #expect(one.drawnBox(in: CGRect(x: name.maxX + 2, y: 4, width: 40, height: 16), ground: Self.ground) == nil)
        #expect((46 ... 47.5).contains(project.minX))
    }

    /// The pointer over a row a window holds: its time gone, a 22 square on the row's middle, its right at 280, an
    /// arrow up and to the right on the button's middle.
    @Test(arguments: [SidebarRowTests.needs(lines: 2), SidebarRowTests.working, SidebarRowTests.turn])
    func underThePointerARowAWindowHoldsShowsItsJump(row: Listed.Row) throws {
        let drawn = try Self.drawn(row, hovered: true)
        let height = row.section == .yourTurn ? WindowStyle.oneLineHeight : WindowStyle.twoLineHeight
        let button = try #require(Self.brighter(than: 0.14, in: CGRect(x: 250, y: 0, width: 46, height: height), of: drawn))
        let arrow = try #require(drawn.drawnBox(
            in: button.insetBy(dx: 2, dy: 2), ground: CGPoint(x: button.minX + 2, y: button.maxY - 3)
        ))

        #expect(abs(button.width - 22) <= 1 && abs(button.height - 22) <= 1)
        #expect(abs(button.maxX - 280) <= 0.5 && abs(button.midY - height / 2) <= 0.5)
        #expect(arrow.minX >= button.minX + 5 && arrow.maxX <= button.minX + 17)
        #expect(arrow.minY >= button.minY + 5 && arrow.maxY <= button.minY + 17)
        #expect(abs(arrow.width - arrow.height) <= 1 && arrow.width >= 8)
    }

    /// Off the row, its time; over an away row, no button, its time staying.
    @Test(arguments: [(SidebarRowTests.needs(lines: 1), false), (SidebarRowTests.needs(lines: 1, away: true), true)])
    func theTimeStaysOffTheRowAndOnAnAwayOne(row: Listed.Row, hovered: Bool) throws {
        let drawn = try Self.drawn(row, hovered: hovered)
        let time = try #require(Self.brighter(than: 0.14, in: CGRect(x: 250, y: 0, width: 46, height: 39), of: drawn))

        #expect(time.height < 14 && (278.5 ... 280.5).contains(time.maxX))
    }

    /// The bounds of what is drawn brighter than this inside `rect`, in points to the pixel, over the row's fill under
    /// the pointer, which is darker, and the black past it: the button, white at 10% over the fill, and what is on it;
    /// or the time.
    private static func brighter(than level: CGFloat, in rect: CGRect, of drawn: Drawn) -> CGRect? {
        let step = 1 / drawn.scale
        let pixels = stride(from: rect.minY, to: rect.maxY, by: step).flatMap { y in
            stride(from: rect.minX, to: rect.maxX, by: step).map { CGRect(x: $0, y: y, width: step, height: step) }
        }
        let lit = pixels.filter { (drawn.pixel(at: $0.origin)?.redComponent ?? 0) > level }

        return lit.dropFirst().reduce(lit.first) { box, pixel in box?.union(pixel) }
    }

    /// Harness's two asks asleep, the sooner waking tomorrow.
    nonisolated static let asleep = Listed.Row(
        id: "sr-4g01a7", name: "Harness modernisation", project: "Harness", section: .snoozed, mark: .snoozed,
        isAway: false, since: now.addingTimeInterval(-3600),
        lines: (0 ..< 2).map { Listed.Line(id: "ask:\($0)", ask: "k\($0)", lead: "Ask \($0)", code: nil, more: nil, since: now) },
        wakesAt: now.addingTimeInterval(24 * 3600)
    )

    /// A Snoozed row is the Needs you row quieted (board H): its dot a neutral grey, fainter than its project; its name
    /// dimmer; and in its time's place when it wakes, wider than an age, its right where an age's is, in the age's soft.
    @Test func aSnoozedRowIsANeedsYouRowQuietedWithWhenItWakes() throws {
        let asleep = try Self.drawn(Self.asleep), needs = try Self.drawn(Self.needs(lines: 2))
        let slot = CGRect(x: 10, y: 4, width: 32, height: 16), title = CGRect(x: 42, y: 4, width: 120, height: 16)
        let project = CGRect(x: 42, y: 21, width: 200, height: 14), time = CGRect(x: 210, y: 0, width: 86, height: 39)
        let wakes = try #require(Self.brighter(than: 0.14, in: time, of: asleep))
        let age = try #require(Self.brighter(than: 0.14, in: time, of: needs))
        let dot = try asleep.brightest(in: slot)

        #expect(abs(dot.redComponent - dot.blueComponent) < 0.02)
        #expect(try dot.lightness < asleep.brightest(in: project).lightness - 0.1)
        #expect(try asleep.brightest(in: title).lightness < needs.brightest(in: title).lightness - 0.3)
        #expect(wakes.width > age.width + 10 && (278.5 ... 280.5).contains(wakes.maxX))
        #expect(try asleep.brightest(in: wakes).isAlike(needs.brightest(in: age)))
    }

    /// The button jumps to its session's window by itself, a press of its own, so the window's jump moves no pick.
    @Test func theButtonsJumpIsItsSessions() {
        #expect(JumpPress.row("sr-4g01a7").session == "sr-4g01a7")
    }
}
