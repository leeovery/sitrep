import AppKit
@testable import SitRep
import SitRepMenu
@testable import SitRepCore
import SitRepEdge
@testable import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// A session no window holds with an ask waiting, alike on every surface (`Away`): its mark a hollow orange ring 7
/// across, unglowed, where a held one's is the orange dot; its title and the line under it dimmed by the one factor,
/// so the title stays the brighter of the two, and its time never brighter than its title. On the black card and the
/// strip's, on glass, in the window's list and on its pages, each read from its pixels at 2×.
@MainActor
struct AwayRowsTests {
    private static func asking(away: Bool) -> Session {
        Session(
            id: "sr-ask001", project: Sample.project, name: "Session", kind: .needs, away: away,
            lines: [Session.Line(title: Sample.needsYou, since: 0)], sub: Sample.project
        )
    }

    private static let cardSize = CGSize(width: 344, height: Item.session(asking(away: false)).height - Item.rowGap)
    /// A card row's title, short of its time, the line under it, and its time.
    private static let cardTitle = CGRect(x: 30, y: 6, width: 160, height: 18)
    private static let cardSub = CGRect(x: 30, y: 26, width: 60, height: 14)
    private static let cardTime = CGRect(x: 290, y: 6, width: 50, height: 18)

    // MARK: The black card

    @Test func onTheBlackCardAnAwayAskIsAHollowOrangeRing() throws {
        let away = try Self.black(Self.asking(away: true)), held = try Self.black(Self.asking(away: false))

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 16))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 16))
    }

    @Test func onTheBlackCardAnAwayRowsTwoLinesDimAsOne() throws {
        let away = try Self.black(Self.asking(away: true)), held = try Self.black(Self.asking(away: false))

        try Self.expectDimmedAsOne(away, held, title: Self.cardTitle, sub: Self.cardSub)
        try Self.expectTimeNoBrighter(away, title: Self.cardTitle, time: Self.cardTime)
    }

    /// A card's row, its time a minute on.
    private static func black(_ session: Session) throws -> Drawn {
        let row = SessionRow(session, size: cardSize)

        row.showAge(at: 60_000)
        return try Drawn(row.layer)
    }

    /// The least factor that keeps the black card's second line, its ink2 dimmed, as readable as the faint ink, 0x5C.
    @Test func theFactorKeepsTheBlackCardsSecondLineAsReadableAsTheFaintInk() {
        #expect(Double(0x98) * Away.dim >= Double(0x5C))
        #expect(Double(0x98) * (Away.dim - 0.01) < Double(0x5C))
    }

    // MARK: The black strip

    private static let tab = CGRect(x: 0, y: 0, width: 260, height: 46)

    private static func strip(_ session: Session, _ content: StripFrame.Words.Content) throws -> Drawn {
        let words = StripFrame.Words(
            id: 1, key: .more, content: content, frame: tab, scroll: 0, alpha: 1, dy: 0, isPressed: false,
            pressedRow: nil
        )

        return try Drawn(StripWordsLayer(words, in: tab, StripScene.resting()).layer)
    }

    /// A session's tab: its title and the line under it, and its time no brighter than its title.
    @Test func onTheBlackStripAnAwayTabsTwoLinesDimAsOne() throws {
        let away = Self.asking(away: true), held = Self.asking(away: false)
        let at = StripRowLayout(away, note: StripNote(), in: Self.tab.size, now: 0)

        try Self.expectDimmedAsOne(
            Self.strip(away, .row(away)), Self.strip(held, .row(held)), title: at.title, sub: at.sub
        )
        try Self.expectTimeNoBrighter(Self.strip(away, .row(away)), title: at.title, time: at.age)
    }

    @Test func onTheBlackStripAnAwayCountRowsTwoLinesDimAsOne() throws {
        let away = Self.asking(away: true), held = Self.asking(away: false)
        let at = StripRowsLayout(0, width: Self.tab.width)

        try Self.expectDimmedAsOne(
            Self.strip(away, .rows([away])), Self.strip(held, .rows([held])),
            title: at.title.offsetBy(dx: at.box.minX, dy: at.box.minY),
            sub: at.sub.offsetBy(dx: at.box.minX, dy: at.box.minY)
        )
    }

    // MARK: Glass

    @available(macOS 26, *)
    @Test func onGlassAnAwayAskIsAHollowOrangeRingAndItsTwoLinesDimAsOne() throws {
        let away = try Self.glass(Self.asking(away: true)), held = try Self.glass(Self.asking(away: false))

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 16))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 16))
        try Self.expectDimmedAsOne(away, held, title: Self.cardTitle, sub: Self.cardSub)
        try Self.expectTimeNoBrighter(away, title: Self.cardTitle, time: Self.cardTime)
    }

    @available(macOS 26, *)
    private static func glass(_ session: Session) throws -> Drawn {
        let row = GlassSessionRow(
            session: session, size: cardSize, oneLine: false, hovered: false, pressed: false, now: 60_000, wash: 0
        )

        return try Drawn(row, size: cardSize)
    }

    @available(macOS 26, *)
    @Test func onTheGlassStripAnAwayTabsTwoLinesDimAsOne() throws {
        let away = Self.asking(away: true), held = Self.asking(away: false)
        let at = StripRowLayout(away, note: StripNote(), in: Self.tab.size, now: 0)
        let tab = { (session: Session) in
            try Drawn(
                GlassRow(session: session, size: Self.tab.size, pressed: false, scene: StripScene.resting()),
                size: Self.tab.size
            )
        }

        try Self.expectDimmedAsOne(tab(away), tab(held), title: at.title, sub: at.sub)
        try Self.expectTimeNoBrighter(tab(away), title: at.title, time: at.age)
    }

    @available(macOS 26, *)
    @Test func onTheGlassStripAnAwayCountRowsTwoLinesDimAsOne() throws {
        let away = Self.asking(away: true), held = Self.asking(away: false)
        let at = StripRowsLayout(0, width: Self.tab.width)
        let rows = { (session: Session) in
            try Drawn(
                GlassRows(sessions: [session], width: Self.tab.width, lit: nil, pressed: false, now: 0),
                size: CGSize(width: Self.tab.width, height: at.box.maxY)
            )
        }

        try Self.expectDimmedAsOne(
            rows(away), rows(held), title: at.title.offsetBy(dx: at.box.minX, dy: at.box.minY),
            sub: at.sub.offsetBy(dx: at.box.minX, dy: at.box.minY)
        )
    }

    // MARK: The window

    private static func line(away: Bool) -> PlaceList.LineRow {
        let line = Listed.Line(id: "ask:sr-ask001:k1", lead: Sample.needsYou, code: nil, more: nil, since: .now)

        return PlaceList.LineRow(
            session: Listed.Row(
                id: "sr-ask001", name: "Session", project: Sample.project, section: .needsYou,
                mark: away ? .awayAsk : .needs, isAway: away, since: Date(timeIntervalSince1970: 0), lines: [line]
            ),
            line: line
        )
    }

    private static func listed(away: Bool) throws -> Drawn {
        try Drawn(
            LineRowView(row: line(away: away), filter: Filter(), now: Date(timeIntervalSince1970: 60)),
            size: CGSize(width: 268, height: WindowStyle.lineHeight)
        )
    }

    /// The mark's slot, 26 wide, from the row's left; its first line's middle 10 + 8 down.
    @Test func inTheListAnAwayAskIsAHollowOrangeRing() throws {
        try Self.expectRing(Self.listed(away: true), centre: CGPoint(x: 13, y: 18))
        try Self.expectDot(Self.listed(away: false), centre: CGPoint(x: 13, y: 18), glows: false)
    }

    /// Its session's name and its words under it, each by the one factor; its time dimmed with them, where it would
    /// read brighter than its name.
    @Test func inTheListAnAwayLinesTwoLinesDimAsOne() throws {
        let title = CGRect(x: 30, y: 10, width: 150, height: 16)

        try Self.expectDimmedAsOne(
            Self.listed(away: true), Self.listed(away: false),
            title: title, sub: CGRect(x: 30, y: 28, width: 60, height: 16)
        )
        try Self.expectTimeNoBrighter(
            Self.listed(away: true), title: title, time: CGRect(x: 218, y: 10, width: 50, height: 16)
        )
    }

    @Test func onAPageAnAwayAsksMarkIsTheRing() throws {
        let size = CGSize(width: WindowStyle.lane.width, height: WindowStyle.lane.height)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        try Self.expectRing(Drawn(MarkView(mark: .awayAsk), size: size), centre: centre)
        try Self.expectDot(Drawn(MarkView(mark: .needs), size: size), centre: centre, glows: false)
    }

    private static let projectRowSize = CGSize(width: 600, height: 32)

    /// A session with two asks waiting, its window there or not, so the words where it stands are the same either way.
    private static func projectRow(away: Bool) throws -> Drawn {
        let session = ProjectPage.Session(
            id: "sr-ask001", name: "Session", mark: away ? .awayAsk : .needs, isAway: away, isOffScreen: false,
            standing: .waits(stop: nil, asks: 2), since: Date(timeIntervalSince1970: 0), now: nil, next: nil,
            updated: Date(timeIntervalSince1970: 0), log: []
        )

        return try Drawn(
            ProjectSessionRow(session: session, now: Date(timeIntervalSince1970: 60)), size: projectRowSize
        )
    }

    /// A project page's row of a session no window holds: its name and where it stands, each by the one factor; its
    /// time, in the faint ink, never brighter than its name.
    @Test func onAProjectPageAnAwayRowsNameAndStandingDimAsOne() throws {
        let title = CGRect(x: 22, y: 8, width: 60, height: 16)

        try Self.expectDimmedAsOne(
            Self.projectRow(away: true), Self.projectRow(away: false),
            title: title, sub: CGRect(x: 312, y: 8, width: 100, height: 16)
        )
        try Self.expectTimeNoBrighter(
            Self.projectRow(away: true), title: title, time: CGRect(x: 560, y: 8, width: 40, height: 16)
        )
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

        #expect(abs(titles - subs) < 0.05)
        #expect(abs(titles - Away.dim) < 0.1)
        #expect(try away.brightest(in: title).lightness > away.brightest(in: sub).lightness)
    }

    /// Its time, where it has one, no brighter than its title.
    private static func expectTimeNoBrighter(_ away: Drawn, title: CGRect, time: CGRect) throws {
        let time = try away.brightest(in: time).lightness

        #expect(time > 0.05)
        #expect(try time <= away.brightest(in: title).lightness)
    }
}
