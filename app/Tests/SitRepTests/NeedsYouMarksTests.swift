import AppKit
@testable import SitRep
import SitRepMenu
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Needs you's marks in one grammar (13 November 2026): colour says what is needed, an ask's orange or Lee's turn's
/// blue; fill says where the session is, a dot with its glow where this Mac shows it and a hollow ring away; and a row
/// in Snoozed its dot, its colour dimmed. On the card, read from its pixels at 2×; and the menu's marks and glyph.
@MainActor
@Suite(.backstop)
struct NeedsYouMarksTests {
    private static let cardSize = CGSize(width: 344, height: Item.lineHeight)
    /// The mark's centre on a card's row, and 2.75 up, where an away ring's stroke runs.
    private static let centre = CGPoint(x: 16, y: 15), stroke = CGPoint(x: 16, y: 12.25)

    private static func session(_ kind: Session.Kind, away: Bool = false) -> Session {
        Session(
            id: "sr-a", project: "Litware", name: "The installer", kind: kind, away: away,
            lines: [Session.Line(ask: kind == .needs || kind == .snoozed ? "k1" : nil, title: "Plan saved", since: 0)],
            sub: "Litware"
        )
    }

    private static func black(_ session: Session) throws -> Drawn {
        let row = SessionRow(session, size: cardSize)

        row.showAge(at: 60_000)
        return try Drawn(row.layer)
    }

    /// Blue: blue well over red, as #3F93FB is; orange, red well over blue, as #E9643D is.
    private static func isBlue(_ colour: NSColor) -> Bool {
        colour.blueComponent > 0.75 && colour.redComponent < 0.35
    }

    private static func isOrange(_ colour: NSColor) -> Bool {
        colour.redComponent > 0.75 && colour.blueComponent < 0.35
    }

    /// A dot: its colour at its centre, and its glow past it, 4.5 up.
    private static func expectDot(
        _ drawn: Drawn, _ colour: (NSColor) -> Bool, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let inside = try #require(drawn.pixel(at: centre), sourceLocation: sourceLocation)
        let glow = try #require(
            drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)), sourceLocation: sourceLocation
        )

        #expect(colour(inside), sourceLocation: sourceLocation)
        #expect(glow.lightness > 0.05, sourceLocation: sourceLocation)
    }

    /// A hollow ring: its colour on its stroke, the black at its centre, and no glow past it.
    private static func expectRing(
        _ drawn: Drawn, _ colour: (NSColor) -> Bool, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let ring = try #require(drawn.pixel(at: stroke), sourceLocation: sourceLocation)
        let inside = try #require(drawn.pixel(at: centre), sourceLocation: sourceLocation)
        let outside = try #require(
            drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)), sourceLocation: sourceLocation
        )

        #expect(colour(ring), sourceLocation: sourceLocation)
        #expect(inside.lightness < 0.1 && outside.lightness < 0.1, sourceLocation: sourceLocation)
    }

    /// A dot asleep: at its centre the lit dot's hue, dimmed, as the away rows' 0.61 dims it over the black, with no
    /// glow past it. Read against the lit dot the same surface draws, as the pixels come blended, not multiplied.
    private static func expectAsleep(
        _ drawn: Drawn, as lit: Drawn, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let inside = try #require(drawn.pixel(at: centre), sourceLocation: sourceLocation)
        let awake = try #require(lit.pixel(at: centre), sourceLocation: sourceLocation)
        let outside = try #require(
            drawn.pixel(at: CGPoint(x: centre.x, y: centre.y - 4.5)), sourceLocation: sourceLocation
        )
        let dimmed = inside.brightnessComponent / awake.brightnessComponent

        #expect(
            abs(inside.hueComponent - awake.hueComponent) < 0.03, "\(inside) for \(awake)",
            sourceLocation: sourceLocation
        )
        #expect((0.55 ... 0.8).contains(dimmed), "dimmed to \(dimmed)", sourceLocation: sourceLocation)
        #expect(outside.lightness < 0.1, sourceLocation: sourceLocation)
    }

    // MARK: The black card

    @Test func onTheBlackCardATurnIsABlueDotHereAndABlueRingAway() throws {
        try Self.expectDot(Self.black(Self.session(.turn)), Self.isBlue)
        try Self.expectRing(Self.black(Self.session(.turn, away: true)), Self.isBlue)
    }

    @Test func onTheBlackCardAnAskIsAnOrangeDotHereAndAnOrangeRingAway() throws {
        try Self.expectDot(Self.black(Self.session(.needs)), Self.isOrange)
        try Self.expectRing(Self.black(Self.session(.needs, away: true)), Self.isOrange)
    }

    /// A snoozed ask's dot is its orange dimmed, a snoozed turn's its blue, away or not: no longer the faint grey.
    @Test(arguments: [false, true])
    func onTheBlackCardASnoozedDotIsItsColourDimmed(away: Bool) throws {
        try Self.expectAsleep(Self.black(Self.session(.snoozed, away: away)), as: Self.black(Self.session(.needs)))
        try Self.expectAsleep(Self.black(Self.session(.snoozedTurn, away: away)), as: Self.black(Self.session(.turn)))
    }

    // MARK: The menu

    /// The menu's marks are the card's: a turn the blue dot with its glow, and away the blue ring, unglowed; neither a
    /// template image, so a disabled item does not grey them to nothing.
    @Test func theMenusTurnIsABlueDotHereAndABlueRingAway() throws {
        let dot = MenuImages.mark(Self.session(.turn)), ring = MenuImages.mark(Self.session(.turn, away: true))
        let lit = try Self.bitmap(dot), hollow = try Self.bitmap(ring)
        let middle = try #require(lit.colorAt(x: 16, y: 16)?.usingColorSpace(.sRGB))
        let edge = try #require(hollow.colorAt(x: 16, y: 10)?.usingColorSpace(.sRGB))

        #expect(!dot.isTemplate && !ring.isTemplate)
        #expect(Self.isBlue(middle) && Self.isBlue(edge))
        #expect((lit.colorAt(x: 16, y: 7)?.alphaComponent ?? 0) > 0.05)
        #expect((hollow.colorAt(x: 16, y: 16)?.alphaComponent ?? 1) < 0.05)
        #expect((hollow.colorAt(x: 16, y: 7)?.alphaComponent ?? 1) < 0.05)
    }

    /// The glyph lit as the notch's light is: its bar orange for an ask, blue for Lee's turn.
    @Test func theGlyphsBarIsOrangeForAnAskAndBlueForLeesTurn() throws {
        let ask = try #require(Self.bitmap(MenuImages.glyph(.lit, ink: .white), side: 36).colorAt(x: 18, y: 18))
        let turn = try #require(Self.bitmap(MenuImages.glyph(.turn, ink: .white), side: 36).colorAt(x: 18, y: 18))

        #expect(Self.isOrange(try #require(ask.usingColorSpace(.sRGB))))
        #expect(Self.isBlue(try #require(turn.usingColorSpace(.sRGB))))
    }

    /// The image drawn at 2× into a clear bitmap this many pixels square, its top row first.
    private static func bitmap(
        _ image: NSImage, side: Int = 32, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> NSBitmapImageRep {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), sourceLocation: sourceLocation)
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap), sourceLocation: sourceLocation)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}
