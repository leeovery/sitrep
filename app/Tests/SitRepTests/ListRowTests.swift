import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// A row of the list beside the page as Paper's A1 revised draws it, drawn alone as a still, 300 wide, its words 16
/// in: a line of Needs you is its session's name over its own words, one line a row, never a count of the others; under
/// the pointer a row a window holds gives its time's place to a 22 square button on its middle, its right where the
/// time ends, which jumps to its window; an away row shows none.
@MainActor
struct ListRowTests {
    private static let width: CGFloat = 300
    nonisolated static let now = Date(timeIntervalSince1970: 1_792_445_000)
    private static let ground = CGPoint(x: 4, y: 4)

    nonisolated static func needs(away: Bool = false) -> PlaceList.Row {
        let since = now.addingTimeInterval(-3600)
        let session = Listed.Row(
            id: "sr-4g01a7", session: "sr-4g01a7", name: "Harness modernisation", project: "Harness",
            section: .needsYou, mark: .needs, isAway: away, since: since,
            lines: (0 ..< 3).map { Listed.Line(id: "ask:\($0)", ask: "k\($0)", lead: "Ask \($0)", code: nil, more: nil, since: since) }
        )

        return .line(PlaceList.LineRow(session: session, line: session.lines[0]))
    }

    nonisolated static let working = PlaceList.Row.session(Listed.Row(
        id: "sr-macapp", session: "sr-macapp", name: "The Mac app", project: "SitRep", section: .working,
        mark: .working, isAway: false,
        since: now, lines: [Listed.Line(id: "turn:sr-macapp", lead: "Reading", code: "Board.swift", more: nil, since: now)]
    ))

    nonisolated static let turn = PlaceList.Row.session(Listed.Row(
        id: "sr-v3t7a0", session: "sr-v3t7a0", name: "Licensing", project: "Fumi", section: .yourTurn, mark: .turn,
        isAway: false, since: now,
        lines: [Listed.Line(id: "turn:sr-v3t7a0", lead: "Sketched", code: nil, more: nil, since: now)]
    ))

    private static func height(of row: PlaceList.Row) -> CGFloat {
        switch row {
        case .line, .parked: WindowStyle.lineHeight
        case let .session(session): session.section == .yourTurn ? WindowStyle.oneLineHeight : WindowStyle.twoLineHeight
        }
    }

    /// The row drawn as a still, the pointer over it or not.
    private static func drawn(_ row: PlaceList.Row, hovered: Bool = false) throws -> Drawn {
        let line = ListLine(item: .row(row), place: .needsYou, picked: nil, filter: Filter(), now: now)
            .environment(\.isStill, true)
            .environment(\.isHoveredStill, hovered)

        return try Drawn(line, size: CGSize(width: width, height: height(of: row)))
    }

    /// Its session's name from 46, 10 down, alone on its line up to its age, no count of the other lines its session
    /// has waiting; its own words under it, from 46 too.
    @Test func aLineIsItsSessionsNameOverItsWords() throws {
        let drawn = try Self.drawn(Self.needs())
        let name = try #require(drawn.drawnBox(in: CGRect(x: 42, y: 8, width: 200, height: 20), ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 42, y: 28, width: 200, height: 16), ground: Self.ground))
        let after = CGRect(x: name.maxX + 2, y: 10, width: 250 - name.maxX - 2, height: 16)

        #expect((46 ... 47.5).contains(name.minX))
        #expect(name.minY >= 10 && name.maxY <= 26)
        #expect(drawn.drawnBox(in: after, ground: Self.ground) == nil)
        #expect((46 ... 47.5).contains(words.minX))
        #expect(words.minY >= 28)
    }

    /// The pointer over a row a window holds: its time gone, a 22 square on the row's middle, its right at 284, an
    /// arrow up and to the right on the button's middle.
    @Test(arguments: [ListRowTests.needs(), ListRowTests.working, ListRowTests.turn])
    func underThePointerARowAWindowHoldsShowsItsJump(row: PlaceList.Row) throws {
        let drawn = try Self.drawn(row, hovered: true)
        let height = Self.height(of: row)
        let button = try #require(Self.brighter(than: 0.14, in: CGRect(x: 254, y: 0, width: 46, height: height), of: drawn))
        let arrow = try #require(drawn.drawnBox(
            in: button.insetBy(dx: 2, dy: 2), ground: CGPoint(x: button.minX + 2, y: button.maxY - 3)
        ))

        #expect(abs(button.width - 22) <= 1 && abs(button.height - 22) <= 1)
        #expect(abs(button.maxX - 284) <= 0.5 && abs(button.midY - height / 2) <= 0.5)
        #expect(arrow.minX >= button.minX + 5 && arrow.maxX <= button.minX + 17)
        #expect(arrow.minY >= button.minY + 5 && arrow.maxY <= button.minY + 17)
        #expect(abs(arrow.width - arrow.height) <= 1 && arrow.width >= 8)
    }

    /// Off the row, its time; over an away row, no button, its time staying.
    @Test(arguments: [(ListRowTests.needs(), false), (ListRowTests.needs(away: true), true)])
    func theTimeStaysOffTheRowAndOnAnAwayOne(row: PlaceList.Row, hovered: Bool) throws {
        let drawn = try Self.drawn(row, hovered: hovered)
        let time = try #require(Self.brighter(than: 0.14, in: CGRect(x: 254, y: 8, width: 46, height: 20), of: drawn))

        #expect(time.height < 14 && (282.5 ... 284.5).contains(time.maxX))
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

    /// Harness's ask asleep, waking tomorrow; away, or a window holding it.
    nonisolated static func asleep(away: Bool = false) -> PlaceList.Row {
        var line = Listed.Line(id: "ask:0", ask: "k0", lead: "Ask 0", code: nil, more: nil, since: now)

        line.wakesAt = now.addingTimeInterval(24 * 3600)
        return .line(PlaceList.LineRow(
            session: Listed.Row(
                id: "sr-4g01a7", session: "sr-4g01a7", name: "Harness modernisation", project: "Harness",
                section: .snoozed, mark: .snoozed,
                isAway: away, since: now.addingTimeInterval(-3600), lines: [line], wakesAt: line.wakesAt
            ),
            line: line
        ))
    }

    /// An ask asleep is the line quieted (board H), the same away or not: its mark the clock, a neutral grey, fainter
    /// than its words; its name dimmer, at its 60% however it stands; and in its time's place when it wakes, wider than
    /// an age, its right where an age's is, in the age's soft.
    @Test(arguments: [false, true])
    func anAskAsleepIsALineQuietedWithWhenItWakes(away: Bool) throws {
        let asleep = try Self.drawn(Self.asleep(away: away)), needs = try Self.drawn(Self.needs())
        let held = try Self.drawn(Self.asleep())
        let slot = CGRect(x: 16, y: 10, width: 26, height: 16), title = CGRect(x: 46, y: 10, width: 120, height: 16)
        let words = CGRect(x: 46, y: 28, width: 200, height: 16), time = CGRect(x: 205, y: 8, width: 95, height: 20)
        let wakes = try #require(Self.brighter(than: 0.14, in: time, of: asleep))
        let age = try #require(Self.brighter(than: 0.14, in: time, of: needs))
        let mark = try asleep.brightest(in: slot)

        #expect(abs(mark.redComponent - mark.blueComponent) < 0.02)
        #expect(try mark.lightness < needs.brightest(in: title).lightness - 0.1)
        #expect(try asleep.brightest(in: title).lightness < needs.brightest(in: title).lightness - 0.3)
        #expect(try asleep.brightest(in: title).isAlike(held.brightest(in: title)))
        #expect(try asleep.brightest(in: words).isAlike(held.brightest(in: words)))
        #expect(wakes.width > age.width + 10 && (282.5 ... 284.5).contains(wakes.maxX))
        #expect(try asleep.brightest(in: wakes).isAlike(needs.brightest(in: age)))
    }

    /// Harness's turn asleep until it moves, its line what Claude left Lee.
    nonisolated static let turnAsleep: PlaceList.Row = {
        let line = Listed.Line(id: "turn:sr-4g01a7", lead: "Stage 2 is in", code: nil, more: nil, since: now)
        let session = Listed.Row(
            id: "turn:sr-4g01a7", session: "sr-4g01a7", name: "Harness modernisation", project: "Harness",
            section: .snoozed, mark: .snoozed, isAway: false, since: now, lines: [line], isTurn: true
        )

        return .line(PlaceList.LineRow(session: session, line: line))
    }()

    /// A turn asleep is a line asleep whose mark is your turn's ring, faint (board I): hollow, in the clock's neutral
    /// grey; and in its time's place "until it moves", its right where an age's is.
    @Test func aTurnAsleepIsALineAsleepMarkedByTheFaintRingUntilItMoves() throws {
        let drawn = try Self.drawn(Self.turnAsleep)
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 16, y: 10, width: 26, height: 16), ground: Self.ground))
        let stroke = try drawn.brightest(in: ring)
        let hole = try drawn.brightest(in: CGRect(x: ring.midX - 0.5, y: ring.midY - 0.5, width: 1, height: 1))
        let time = try #require(Self.brighter(than: 0.14, in: CGRect(x: 205, y: 8, width: 95, height: 20), of: drawn))

        #expect(abs(ring.width - 9) <= 1 && abs(ring.height - 9) <= 1)
        #expect(hole.lightness < stroke.lightness - 0.2)
        #expect(abs(stroke.redComponent - stroke.blueComponent) < 0.02)
        #expect((282.5 ... 284.5).contains(time.maxX))
        #expect(time.width > 50)
    }

    /// Northwind's item parked an hour ago from Ledger export.
    nonisolated static let parked = PlaceList.Row.parked(Listed.Parked(
        item: SessionBoard.Parked(
            id: "77k4", title: "Handle multi-currency rows", where: nil, ref: nil, at: now.addingTimeInterval(-3600)
        ),
        session: "sr-nwdgr4", sessionName: "Ledger export", project: "northwind", projectName: "Northwind"
    ))

    /// A parked item is a line's shape (A4 revised): its diamond in the mark's slot, its title from 46, 10 down, its
    /// session's name under it from 46 too; under the pointer no button, as it is the item and not its session, its
    /// age staying.
    @Test func aParkedItemIsItsTitleOverItsSessionWithNoJump() throws {
        let drawn = try Self.drawn(Self.parked)
        let hovered = try Self.drawn(Self.parked, hovered: true)
        let mark = try #require(drawn.drawnBox(in: CGRect(x: 16, y: 10, width: 26, height: 16), ground: Self.ground))
        let title = try #require(drawn.drawnBox(in: CGRect(x: 42, y: 8, width: 160, height: 20), ground: Self.ground))
        let session = try #require(drawn.drawnBox(in: CGRect(x: 42, y: 28, width: 160, height: 16), ground: Self.ground))
        let time = try #require(Self.brighter(than: 0.14, in: CGRect(x: 254, y: 8, width: 46, height: 20), of: hovered))

        #expect(abs(mark.width - 9) <= 1 && abs(mark.midX - 29) <= 1)
        #expect((46 ... 47.5).contains(title.minX) && title.minY >= 10 && title.maxY <= 26)
        #expect((46 ... 47.5).contains(session.minX) && session.minY >= 28)
        #expect(time.height < 14 && (282.5 ... 284.5).contains(time.maxX))
    }

    /// A project's heading over its items: its name from 16, 11 semibold, and its count at the age's end.
    @Test func aParkedHeadingIsItsProjectsNameAndCount() throws {
        let heading = ListLine(
            item: .heading(PlaceList.Heading(project: "northwind", name: "Northwind", count: 2)), place: .parked,
            picked: nil, filter: Filter(), now: Self.now, isFirst: true
        )
        .environment(\.isStill, true)
        let drawn = try Drawn(heading, size: CGSize(width: Self.width, height: 28))
        let name = try #require(drawn.drawnBox(in: CGRect(x: 12, y: 4, width: 120, height: 24), ground: Self.ground))
        let count = try #require(drawn.drawnBox(in: CGRect(x: 254, y: 4, width: 46, height: 24), ground: Self.ground))

        #expect((16 ... 17.5).contains(name.minX) && name.height <= 11)
        #expect((282.5 ... 284.5).contains(count.maxX))
    }

    /// The button jumps to its session's window by itself, a press of its own, so the window's jump moves no pick.
    @Test func theButtonsJumpIsItsSessions() {
        #expect(JumpPress.row("sr-4g01a7").session == "sr-4g01a7")
    }
}
