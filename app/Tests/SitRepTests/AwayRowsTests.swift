import AppKit
@testable import SitRep
import SitRepMenu
@testable import SitRepCore
import SitRepEdge
@testable import SitRepPanel
import SwiftUI
import Testing

/// A session no window holds with an ask waiting, alike on every surface (`Away`): its mark a hollow orange ring 7
/// across, unglowed, where a held one's is the orange dot; its title and the line under it, or on the card's one line
/// its count, dimmed by the one factor, so the title stays the brighter of the two, and its time, and on the card its
/// project, never brighter than its title. On the black card and the strip's, and on glass, each read from its pixels
/// at 2×.
@MainActor
struct AwayRowsTests {
    private static func asking(away: Bool, lines: Int = 1) -> Session {
        Session(
            id: "sr-ask001", project: Sample.project, name: "Session", kind: .needs, away: away,
            lines: (0 ..< lines).map { Session.Line(ask: "k\($0)", title: Sample.needsYou, since: 0) }, sub: Sample.project
        )
    }

    /// The card's row, on one line (board J).
    private static let cardSize = CGSize(width: 344, height: Item.lineHeight)
    /// The session's name, 13 medium, as the card sets it.
    private static let named = TextLine.width(TextLine.text("Session", EdgeStyle.lineMedium, EdgeStyle.ink))
    /// A card row's title, its "2" 6 after it, its project at the right, and its time.
    private static let cardTitle = CGRect(x: 30, y: 6, width: 2 + named, height: 18)
    private static let cardCount = CGRect(x: 32 + named + 3, y: 6, width: 20, height: 18)
    private static let cardProject = CGRect(x: 200, y: 6, width: 88, height: 18)
    private static let cardTime = CGRect(x: 290, y: 6, width: 50, height: 18)

    // MARK: The black card

    @Test func onTheBlackCardAnAwayAskIsAHollowOrangeRing() throws {
        let away = try Self.black(Self.asking(away: true)), held = try Self.black(Self.asking(away: false))

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 15))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 15))
    }

    /// Its name and its "2" dim as one; its project and its time, faint, are never brighter than its name.
    @Test func onTheBlackCardAnAwayRowsWordsDimAsOne() throws {
        let away = try Self.black(Self.asking(away: true, lines: 2))
        let held = try Self.black(Self.asking(away: false, lines: 2))

        try Self.expectDimmedAsOne(away, held, title: Self.cardTitle, sub: Self.cardCount)
        try Self.expectTimeNoBrighter(away, title: Self.cardTitle, time: Self.cardTime)
        try Self.expectTimeNoBrighter(away, title: Self.cardTitle, time: Self.cardProject)
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
            id: 1, key: .count(.working), content: content, frame: tab, scroll: 0, alpha: 1, dy: 0, isPressed: false,
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
    @Test func onGlassAnAwayAskIsAHollowOrangeRingAndItsWordsDimAsOne() throws {
        let away = try Self.glass(Self.asking(away: true, lines: 2))
        let held = try Self.glass(Self.asking(away: false, lines: 2))

        try Self.expectRing(away, centre: CGPoint(x: 16, y: 15))
        try Self.expectDot(held, centre: CGPoint(x: 16, y: 15))
        try Self.expectDimmedAsOne(away, held, title: Self.cardTitle, sub: Self.cardCount)
        try Self.expectTimeNoBrighter(away, title: Self.cardTitle, time: Self.cardTime)
    }

    @available(macOS 26, *)
    private static func glass(_ session: Session) throws -> Drawn {
        let row = GlassSessionRow(
            session: session, size: cardSize, hovered: false, pressed: false, now: 60_000, wash: 0
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

    // MARK: Not here, in any state

    /// A session a window holds that this Mac does not show keeps its state (stage 8's "The rows"): a turn, a working
    /// row, one on its own work, drawn with the away look as an ask is, its words dimmed by the one factor.
    private nonisolated static let states: [Session.Kind] = [.turn, .working, .onItsWork]

    private static func line(_ kind: Session.Kind, away: Bool) -> Session {
        let isTurn = kind == .turn

        return Session(
            id: "sr-row001", project: Sample.project, kind: kind, away: away,
            title: isTurn ? "Over to you" : "Reading ", subject: isTurn ? nil : "notes.md",
            sub: "\(Sample.project) · Session", since: 0
        )
    }

    /// The card's title, up to its project's lane.
    private static let cardLine = CGRect(x: 30, y: 6, width: 160, height: 18)

    @Test(arguments: states)
    func onTheBlackCardARowNotHereDimsItsWordsWhateverItsState(kind: Session.Kind) throws {
        let away = try Self.black(Self.line(kind, away: true)), held = try Self.black(Self.line(kind, away: false))

        try Self.expectDimmed(away, held, in: Self.cardLine)
    }

    @Test(arguments: states)
    func onTheBlackStripARowNotHereDimsItsTwoLinesWhateverItsState(kind: Session.Kind) throws {
        let away = Self.line(kind, away: true), held = Self.line(kind, away: false)
        let tab = StripRowLayout(away, note: StripNote(), in: Self.tab.size, now: 0)
        let rows = StripRowsLayout(0, width: Self.tab.width)

        try Self.expectDimmed(Self.strip(away, .row(away)), Self.strip(held, .row(held)), in: tab.title)
        try Self.expectDimmed(Self.strip(away, .row(away)), Self.strip(held, .row(held)), in: tab.sub)
        try Self.expectDimmed(
            Self.strip(away, .rows([away])), Self.strip(held, .rows([held])),
            in: rows.title.offsetBy(dx: rows.box.minX, dy: rows.box.minY)
        )
    }

    @available(macOS 26, *)
    @Test(arguments: states)
    func onGlassARowNotHereDimsItsWordsWhateverItsState(kind: Session.Kind) throws {
        let away = Self.line(kind, away: true), held = Self.line(kind, away: false)
        let at = StripRowLayout(away, note: StripNote(), in: Self.tab.size, now: 0)
        let tab = { (session: Session) in
            try Drawn(
                GlassRow(session: session, size: Self.tab.size, pressed: false, scene: StripScene.resting()),
                size: Self.tab.size
            )
        }

        try Self.expectDimmed(Self.glass(away), Self.glass(held), in: Self.cardLine)
        try Self.expectDimmed(tab(away), tab(held), in: at.title)
    }

    // MARK: Reading them

    /// The away row's words in the box dimmed from the held row's by about `Away.dim`, by their brightest pixels.
    private static func expectDimmed(_ away: Drawn, _ held: Drawn, in box: CGRect) throws {
        let dimmed = try away.brightest(in: box).lightness / held.brightest(in: box).lightness

        #expect(abs(dimmed - Away.dim) < 0.1)
    }

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

    /// The orange dot: orange at its centre too, and its glow past it.
    private static func expectDot(_ drawn: Drawn, centre: CGPoint) throws {
        let inside = try #require(drawn.pixel(at: centre))
        let outside = try #require(drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)))

        #expect(inside.redComponent > 0.75 && inside.blueComponent < 0.35)
        #expect(outside.lightness > 0.05)
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
