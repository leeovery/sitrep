import AppKit
@testable import SitRep
import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// A session no window holds with an ask waiting, alike on every surface (`Away`): its mark a hollow orange ring 7
/// across, unglowed, where a held one's is the orange dot; its title and the line under it dimmed by the one factor,
/// so the title stays the brighter of the two. On the black card, on glass, in the window's sidebar and on its pages,
/// each read from its pixels at 2×.
@MainActor
struct AwayRowsTests {
    private static func asking(away: Bool) -> Session {
        Session(
            id: "sr-4g01a7", project: "Harness", name: "Harness modernisation", kind: .needs, away: away,
            lines: [Session.Line(title: "Approve the first fix batch", since: 0)], sub: "Harness"
        )
    }

    private static let cardSize = CGSize(width: 344, height: Item.session(asking(away: false)).height - Item.rowGap)
    /// A card row's title, short of its time, and the line under it.
    private static let cardTitle = CGRect(x: 30, y: 6, width: 160, height: 18)
    private static let cardSub = CGRect(x: 30, y: 26, width: 60, height: 14)

    // MARK: The black card

    @Test func onTheBlackCardAnAwayAskIsAHollowOrangeRing() throws {
        let away = try Drawn(SessionRow(Self.asking(away: true), size: Self.cardSize).layer)
        let held = try Drawn(SessionRow(Self.asking(away: false), size: Self.cardSize).layer)

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 16))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 16))
    }

    @Test func onTheBlackCardAnAwayRowsTwoLinesDimAsOne() throws {
        let away = try Drawn(SessionRow(Self.asking(away: true), size: Self.cardSize).layer)
        let held = try Drawn(SessionRow(Self.asking(away: false), size: Self.cardSize).layer)

        try Self.expectDimmedAsOne(
            away, held, title: Self.cardTitle, sub: Self.cardSub
        )
    }

    // MARK: Glass

    @available(macOS 26, *)
    @Test func onGlassAnAwayAskIsAHollowOrangeRingAndItsTwoLinesDimAsOne() throws {
        let away = try Self.glass(Self.asking(away: true)), held = try Self.glass(Self.asking(away: false))

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 16))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 16))
        try Self.expectDimmedAsOne(
            away, held, title: Self.cardTitle, sub: Self.cardSub
        )
    }

    @available(macOS 26, *)
    private static func glass(_ session: Session) throws -> Drawn {
        let row = GlassSessionRow(
            session: session, size: cardSize, oneLine: false, hovered: false, pressed: false, now: 60_000, wash: 0
        )

        return try Drawn(row, size: cardSize)
    }

    // MARK: The window

    private static func row(away: Bool) -> Listed.Row {
        Listed.Row(
            id: "sr-4g01a7", name: "Harness modernisation", project: "Harness", section: .needsYou,
            mark: away ? .awayAsk : .needs, isAway: away, since: Date(timeIntervalSince1970: 0),
            lines: [Listed.Line(id: "ask:sr-4g01a7:k1", lead: "Approve", code: nil, more: nil, since: .now)]
        )
    }

    private static func sidebar(away: Bool) throws -> Drawn {
        try Drawn(
            NeedsYouRow(row: row(away: away), filter: Filter(), now: Date(timeIntervalSince1970: 60)),
            size: CGSize(width: 280, height: WindowStyle.twoLineHeight)
        )
    }

    /// The mark's slot, 26 wide, from the row's left; its first line's middle 4 + 8 down.
    @Test func inTheSidebarAnAwayAskIsAHollowOrangeRing() throws {
        try Self.expectRing(Self.sidebar(away: true), centre: CGPoint(x: 13, y: 12))
        try Self.expectDot(Self.sidebar(away: false), centre: CGPoint(x: 13, y: 12), glows: false)
    }

    /// Its session's name and its project under it, each by the one factor, where its name had dimmed and its project
    /// had not.
    @Test func inTheSidebarAnAwayRowsTwoLinesDimAsOne() throws {
        try Self.expectDimmedAsOne(
            Self.sidebar(away: true), Self.sidebar(away: false),
            title: CGRect(x: 30, y: 4, width: 150, height: 16), sub: CGRect(x: 30, y: 21, width: 60, height: 14)
        )
    }

    @Test func onAPageAnAwayAsksMarkIsTheRing() throws {
        let size = CGSize(width: WindowStyle.lane.width, height: WindowStyle.lane.height)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        try Self.expectRing(Drawn(MarkView(mark: .awayAsk), size: size), centre: centre)
        try Self.expectDot(Drawn(MarkView(mark: .needs), size: size), centre: centre, glows: false)
    }

    // MARK: Reading them

    /// A ring 7 across, its stroke 1.5 inside it: orange at its middle, 2.75 out; the black at its centre; nothing past
    /// it, 4.5 out, where the dot's glow, on the card, still shows.
    private static func expectRing(_ drawn: Drawn, centre: CGPoint) throws {
        let ring = try #require(drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 2.75)))
        let inside = try #require(drawn.pixel(at: centre))
        let outside = try #require(drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)))

        #expect(ring.redComponent > 0.75 && ring.blueComponent < 0.35)
        #expect(inside.lightness < 0.1)
        #expect(outside.lightness < 0.1)
    }

    /// The orange dot: orange at its centre too, and on the card, its glow past it.
    private static func expectDot(_ drawn: Drawn, centre: CGPoint, glows: Bool = true) throws {
        let inside = try #require(drawn.pixel(at: centre))
        let outside = try #require(drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)))

        #expect(inside.redComponent > 0.75 && inside.blueComponent < 0.35)
        #expect(!glows || outside.lightness > 0.05)
    }

    /// The away row's title and the line under it each dimmed from the held row's by the one factor, about
    /// `Away.dim`: the words' brightest pixels, as Core Text draws fainter words a little darker than their colour,
    /// the same for both lines.
    private static func expectDimmedAsOne(_ away: Drawn, _ held: Drawn, title: CGRect, sub: CGRect) throws {
        let titles = try away.brightest(in: title).lightness / held.brightest(in: title).lightness
        let subs = try away.brightest(in: sub).lightness / held.brightest(in: sub).lightness

        #expect(abs(titles - subs) < 0.04)
        #expect(abs(titles - Away.dim) < 0.1)
        #expect(try away.brightest(in: title).lightness > away.brightest(in: sub).lightness)
    }
}
