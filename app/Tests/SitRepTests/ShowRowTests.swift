import AppKit
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What stays on screen's Show row, set as System Settings sets Appearance's on macOS 26: on the real page, as the
/// window lays it out (`Hosted`), and its tiles' edges, each in a window of its own.
@MainActor
struct ShowRowTests {
    /// What stays on screen's card's top, under the title and the header, at any width.
    private static let top: CGFloat = 146

    /// The card's right at a page's width: the page less 44.
    private static func right(_ page: CGFloat) -> CGFloat {
        page - 44
    }

    /// The pictures' lefts, Notch, Strip and Nothing: 67 wide, 15 apart, the last 13.5 in from the card's right.
    private static func lefts(_ page: CGFloat) -> [CGFloat] {
        [2.0, 1, 0].map { right(page) - 13.5 - 67 - $0 * 82 }
    }

    /// The page drawn, Notch chosen unless `change` says, in a window (`atTwice()`).
    private static func page(
        _ width: CGFloat, _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async throws -> Drawn {
        try await Hosted.drawn(width: width, change).atTwice()
    }

    /// A view in a window over `ground`, laid out as the page is (`atTwice()`).
    private static func inAWindow(_ view: some View, size: CGSize, over ground: Color = .black) throws -> Drawn {
        try Drawn(Hosted(view.frame(width: size.width, height: size.height).background(ground), size: size).hosting).atTwice()
    }

    /// Where the Show row draws nothing but the card's raise: under its label, clear of a line.
    private static let raisePoint = CGPoint(x: 54, y: top + 70)

    /// The card's raise.
    private static func raise(_ drawn: Drawn) throws -> NSColor {
        try #require(drawn.pixels(in: CGRect(origin: raisePoint, size: CGSize(width: 0.5, height: 0.5))).first)
    }

    /// Across the pictures' middle, Notch chosen: its ring, 3 wide past a gap of the raise, 0.5, round its picture,
    /// then Strip's and Nothing's, each 67 wide, 15 apart, the last 13.5 in from the card's right, whatever the
    /// width.
    @Test(arguments: [564.0, 956, 1400])
    func thePicturesKeepTheirSizeAndPlaceAtAnyWidth(page: CGFloat) async throws {
        let drawn = try await Self.page(page)
        let lefts = Self.lefts(page)
        let across = drawn.spans(
            atY: Self.top + 13.5 + 22, unlike: Self.raisePoint, from: lefts[0] - 8, to: Self.right(page) - 1
        )
        let expected = [
            lefts[0] - 3.5 ... lefts[0] - 0.5, lefts[0] ... lefts[0] + 67, lefts[0] + 67.5 ... lefts[0] + 70.5,
            lefts[1] ... lefts[1] + 67, lefts[2] ... lefts[2] + 67,
        ]

        #expect(across.count == expected.count)
        for (span, expected) in zip(across, expected) {
            #expect(expected.isWithinAPixel(of: span, at: drawn.scale))
        }
    }

    /// A choice changes the tiles at once, as Appearance's do: drawn as soon as Show is the strip, the ring is whole
    /// round the strip's picture and gone from the notch's.
    @Test func aChoiceChangesTheTilesAtOnce() async throws {
        let page = await Hosted.pageView()
        let hosted = Hosted(PageColumn(page: .settings, now: Date()) { page }, size: CGSize(width: 956, height: 1069))
        let lefts = Self.lefts(956)
        var accent = NSColor.controlAccentColor

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? accent
        }
        page.settings.preferences.edit { $0.show = .strip }
        await Task.yield()
        hosted.hosting.layoutSubtreeIfNeeded()

        let drawn = try Drawn(hosted.hosting).atTwice()
        let strip = try #require(drawn.colour(at: CGPoint(x: lefts[1] - 2, y: Self.top + 35)))
        let notch = try #require(drawn.colour(at: CGPoint(x: lefts[0] - 2, y: Self.top + 35)))
        let raise = try #require(drawn.colour(at: Self.raisePoint))

        for (drawn, expected) in zip(strip.channels, accent.channels) {
            #expect(abs(drawn - expected) < 0.02)
        }
        for (drawn, expected) in zip(notch.channels, raise.channels) {
            #expect(abs(drawn - expected) < 0.02)
        }
    }

    /// Down the chosen picture, clear of its corners and its name: the ring's top 10 under the card's, over its
    /// picture, 44 tall, and under it.
    @Test func theChosenPictureIs44TallInItsRing() async throws {
        let drawn = try await Self.page(956)
        let down = drawn.spans(
            atX: Self.lefts(956)[0] + 14, unlike: Self.raisePoint, from: Self.top + 1, to: Self.top + 85
        )
        let picture = Self.top + 13.5 ... Self.top + 57.5
        let expected = [Self.top + 10 ... Self.top + 13, picture, Self.top + 58 ... Self.top + 61]

        #expect(down.count == expected.count)
        for (span, expected) in zip(down, expected) {
            #expect(expected.isWithinAPixel(of: span, at: drawn.scale))
        }
    }

    /// The ring is drawn in the accent, the system's, as Appearance's is.
    @Test func theRingIsTheAccent() async throws {
        let drawn = try await Self.page(956)
        let ring = try #require(drawn.colour(at: CGPoint(x: Self.lefts(956)[0] - 2, y: Self.top + 35)))
        var accent = NSColor.controlAccentColor

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? accent
        }
        for (drawn, expected) in zip(ring.channels, accent.channels) {
            #expect(abs(drawn - expected) < 0.02)
        }
    }

    /// Each picture's name, 11, its baseline 73 under the card's top, centred under it: the chosen one's semibold in
    /// the label colour, the others' regular in the secondary colour. Each name's line of 14 is drawn to the pixel as
    /// the word is at that size, weight and colour over the card's raise, centred in its tile's 74, in a window: the
    /// line and the word stand on whole pixels alike, so nothing but the type can part them.
    @Test(arguments: EdgeSettings.Show.allCases)
    func theChosenNameIsSemiboldInTheLabelColour(chosen: EdgeSettings.Show) async throws {
        let drawn = try await Self.page(956) { $0.show = chosen }
        let raise = try Self.raise(drawn)
        let pixel = 1 / drawn.scale

        for (choice, left) in zip(EdgeSettings.Show.allCases, Self.lefts(956)) {
            let isChosen = choice == chosen
            let line = CGRect(x: left - 3.5, y: Self.top + 62, width: 74, height: 14)
            let word = try Self.word(
                choice.title, isChosen ? .semibold : .regular, isChosen ? .labelColor : .secondaryLabelColor
            )
            let name = try #require(drawn.ink(in: line, over: raise))

            #expect(drawn.pixels(in: line) == word.pixels(in: CGRect(origin: .zero, size: line.size)))
            #expect(abs(name.midX - (left + 33.5)) < 2 * pixel)
            if choice == .notch {
                // with nothing below its line
                #expect(abs(name.maxY - (Self.top + 73)) < pixel)
            }
        }
    }

    /// A word, 11 at `weight` in `colour`, centred in a line of 74 by 14 over the card's raise, drawn in a window as
    /// the page is.
    private static func word(_ word: String, _ weight: Font.Weight, _ colour: NSColor) throws -> Drawn {
        let size = CGSize(width: 74, height: 14)
        let words = Text(word)
            .font(.subheadline.weight(weight))
            .foregroundStyle(Color(nsColor: colour))
            .frame(width: size.width, height: size.height)
            .background(WindowStyle.raise)

        return try inAWindow(words, size: size)
    }

    /// Show stands at the top of its row, in a label's line 10 under the card's top, as Appearance's label does.
    @Test func showStandsAtTheTopOfItsRow() async throws {
        let drawn = try await Self.page(956)
        let show = try #require(drawn.ink(in: CGRect(x: 54, y: Self.top, width: 60, height: 86), over: Self.raise(drawn)))

        #expect(show.minY >= Self.top + 10)
        #expect(show.maxY <= Self.top + 26)
    }

    /// With Nothing chosen, the card is the Show row alone, 86 tall, its line under Show in the secondary colour saying
    /// what carries the board; with the notch or the strip, Show has no line.
    @Test(arguments: [564.0, 956])
    func withNothingTheCardIsTheShowRowWithItsLine(page: CGFloat) async throws {
        let nothing = try await Self.page(page) { $0.show = .nothing }
        let strip = try await Self.page(page) { $0.show = .strip }
        // down the gap between the row's words and its pictures
        let x = Self.right(page) - 256
        let card = try #require(nothing.litSpans(atX: x).first)
        // the line's place, under Show's line of 16 and the 2 between
        let line = CGRect(x: 54, y: Self.top + 28, width: 100, height: 14)
        let pixel = 1 / nothing.scale

        #expect(abs(card.lowerBound - Self.top) < pixel)
        #expect(abs(card.upperBound - (Self.top + 86)) < pixel)
        #expect(nothing.lines(atX: x, in: card).isEmpty)
        try nothing.expectWords(in: line, .secondaryLabelColor, over: Self.raise(nothing))
        #expect(try strip.ink(in: line, over: Self.raise(strip)) == nil)
    }

    /// A picture at the Show row's size.
    private static func picture(_ show: EdgeSettings.Show) throws -> Drawn {
        try Drawn(EdgePicture(show: show), size: CGSize(width: 67, height: 44))
    }

    /// The strip's rings drawn no finer than half a point, so your turn's, white, lights a whole pixel at 2× somewhere
    /// round it, where its line drawn to scale, 0.27, would light at most about half of one.
    @Test func theStripsRingsAreNoFinerThanHalfAPoint() throws {
        // round your turn's ring: its middle 4.05 in and 17.3 down, 1.5 out
        let turn = try Self.picture(.strip).brightest(in: CGRect(x: 2, y: 15.3, width: 4.1, height: 4))

        #expect(turn.channels.allSatisfy { $0 > 0.7 })
    }

    /// Nothing's menu bar seen closer, until the glyph's housing stands 5 tall: the orange bar in it 3.6 tall, its
    /// rounded ends' blend aside 3, where drawn to scale it would stand 1.6.
    @Test func nothingsGlyphStandsTallEnoughToRead() throws {
        let drawn = try Self.picture(.nothing)
        let orange = (0..<drawn.bitmap.pixelsHigh).filter { y in
            (0..<drawn.bitmap.pixelsWide).contains { x in
                guard let pixel = drawn.bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    return false
                }
                return pixel.redComponent > 0.6 && pixel.greenComponent < 0.5 && pixel.blueComponent < 0.4
            }
        }
        let rows = try #require(orange.last) - #require(orange.first) + 1

        #expect(CGFloat(rows) / drawn.scale >= 2.5)
    }

    /// A tile in a window over a mid grey, 10 clear of it all round, so its edge's shadow can be read: the picture from
    /// (13.5, 13.5), 67 × 44, the ring's room round it, then its name.
    private static func tile(_ choice: EdgeSettings.Show, isChosen: Bool) throws -> Drawn {
        try inAWindow(
            TileFace(choice: choice, isChosen: isChosen).padding(10), size: CGSize(width: 94, height: 86),
            over: Color(white: 0.5)
        )
    }

    /// How much darker than the ground the edge leaves each pixel at 2×, 1 to 8 out from the picture, round
    /// Appearance's unchosen thumbnails in a capture of System Settings on macOS 26: (32,33,42), (33,35,43),
    /// (34,36,45), (35,37,46), (36,37,47), (36,38,48), (36,38,48), then the card's (37,39,49), alike on all four sides.
    /// They are 8-bit readings on a ground of about 37 levels, each rounded to its level, so one level there is about
    /// 2.7% of the darkening (`level`).
    private static let appearancesEdge: [CGFloat] = [0.144, 0.111, 0.080, 0.055, 0.040, 0.024, 0.024, 0]
    /// How near the edge's darkening matches the capture's: a level of the capture's, on its ground of 37, and one of
    /// ours, on the mid grey's 128, as each is rounded to its level.
    private static let level: CGFloat = 1.0 / 37 + 1.0 / 128

    /// How much darker than the ground each pixel `steps` out from `edge`, a pixel on the picture's edge, is.
    private static func darkening(_ drawn: Drawn, from edge: (x: Int, y: Int), by step: (x: Int, y: Int)) throws -> [CGFloat] {
        let ground = try #require(drawn.bitmap.colorAt(x: 1, y: 1)).redComponent

        return try (1...8).map { out in
            let pixel = try #require(drawn.bitmap.colorAt(x: edge.x + out * step.x, y: edge.y + out * step.y))

            return 1 - pixel.redComponent / ground
        }
    }

    /// Round a picture not chosen, its edge as Appearance draws its unchosen thumbnails': a soft shadow, darkest at
    /// the picture, gone 4 out, alike on every side, so with no offset; no hairline.
    @Test func aPictureNotChosenStandsOnAppearancesSoftShadow() throws {
        let drawn = try Self.tile(.strip, isChosen: false)
        // the picture's edges, in pixels: left 27, right 160, top 27, foot 114; down its side at 71, across at 47
        let sides: [(edge: (x: Int, y: Int), step: (x: Int, y: Int))] = [
            ((27, 71), (-1, 0)), ((160, 71), (1, 0)), ((47, 27), (0, -1)), ((47, 114), (0, 1)),
        ]

        for side in sides {
            for (drawn, appearance) in zip(try Self.darkening(drawn, from: side.edge, by: side.step), Self.appearancesEdge) {
                #expect(abs(drawn - appearance) <= Self.level)
            }
        }
    }

    /// Round the chosen picture, as round Appearance's, no shadow: its gap and what is past its ring are the ground.
    @Test func theChosenPictureHasNoShadow() throws {
        let drawn = try Self.tile(.notch, isChosen: true)
        // left of the picture: the gap's pixel, then past the ring, from 7 out
        let darkening = try Self.darkening(drawn, from: (27, 71), by: (-1, 0))

        #expect(darkening[0] == 0)
        #expect(darkening[7] == 0)
    }
}

extension Drawn {
    /// Words drawn in `colour` over `ground`: their brightest pixel within 0.07 of it, flattened over the ground, in
    /// each channel.
    func expectWords(in rect: CGRect, _ colour: NSColor, over ground: NSColor) throws {
        let brightest = try brightest(in: rect)

        for (drawn, expected) in zip(brightest.channels, colour.dark(over: ground).channels) {
            #expect(abs(drawn - expected) < 0.07)
        }
    }

    /// Where a row of pixels across the drawing, from `start` to `end`, is not what is drawn at `ground`, each span from
    /// its first such pixel's left to its last's right.
    func spans(atY y: CGFloat, unlike ground: CGPoint, from start: CGFloat, to end: CGFloat) -> [ClosedRange<CGFloat>] {
        let row = Int((y * scale).rounded())

        return spans(Int((start * scale).rounded())..<Int((end * scale).rounded()), unlike: ground) {
            bitmap.colorAt(x: $0, y: row)
        }
    }

    /// Where a column of pixels down the drawing, from `start` to `end`, is not what is drawn at `ground`, each span
    /// from its first such pixel's top to its last's foot.
    func spans(atX x: CGFloat, unlike ground: CGPoint, from start: CGFloat, to end: CGFloat) -> [ClosedRange<CGFloat>] {
        let column = Int((x * scale).rounded())

        return spans(Int((start * scale).rounded())..<Int((end * scale).rounded()), unlike: ground) {
            bitmap.colorAt(x: column, y: $0)
        }
    }

    /// Each run of pixels in `pixels` more than 4 levels of 255 from the pixel at `ground` in any channel, both read in
    /// the levels the bitmap holds. Read through sRGB, as `pixels(in:)` reads a window's (`colour(at:)`), the darkest
    /// of an unchosen picture's shadow on the card's raise, 3 levels there, would stretch to 4.6.
    private func spans(
        _ pixels: Range<Int>, unlike ground: CGPoint, at color: (Int) -> NSColor?
    ) -> [ClosedRange<CGFloat>] {
        let ground = bitmap.colorAt(x: Int((ground.x * scale).rounded()), y: Int((ground.y * scale).rounded()))
        var spans: [ClosedRange<CGFloat>] = []
        var first: Int?

        for pixel in pixels.lowerBound...pixels.upperBound {
            let colour = pixel < pixels.upperBound ? color(pixel) : nil

            if let colour, let ground,
               zip(colour.channels, ground.channels).contains(where: { abs($0 - $1) * 255 > 4 }) {
                first = first ?? pixel
            } else if let start = first {
                spans.append(CGFloat(start) / scale ... CGFloat(pixel) / scale)
                first = nil
            }
        }
        return spans
    }

    /// The pixel at `point` in sRGB, its values read in the bitmap's own colour space. A window draws in its screen's,
    /// but `colorAt` hands its values back as calibrated RGB, so `pixels(in:)` reads a window's colours a little off:
    /// near enough for greys, not for the accent.
    func colour(at point: CGPoint) -> NSColor? {
        guard let raw = bitmap.colorAt(x: Int((point.x * scale).rounded()), y: Int((point.y * scale).rounded())) else {
            return nil
        }

        var components = [raw.redComponent, raw.greenComponent, raw.blueComponent, raw.alphaComponent]

        return NSColor(colorSpace: bitmap.colorSpace, components: &components, count: 4).usingColorSpace(.sRGB)
    }

    /// How much lighter than `ground` what is drawn in `rect` is, all told: words' ink, heavier the bolder they are.
    func inkMass(in rect: CGRect, over ground: NSColor) -> CGFloat {
        let floor = ground.usingColorSpace(.sRGB)?.lightness ?? 0

        return pixels(in: rect).reduce(0) { $0 + max(0, $1.lightness - floor) }
    }

    /// The box round what is drawn in `rect` well lighter than `ground`: words' ink, their edges' blend aside.
    func ink(in rect: CGRect, over ground: NSColor) -> CGRect? {
        let columns = Int((rect.minX * scale).rounded())..<Int((rect.maxX * scale).rounded())
        let rows = Int((rect.minY * scale).rounded())..<Int((rect.maxY * scale).rounded())
        let least = (ground.usingColorSpace(.sRGB)?.lightness ?? 0) + 0.6
        let inked = rows.flatMap { y in
            columns.compactMap { x in
                (bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)?.lightness ?? 0) > least ? (x, y) : nil
            }
        }

        guard let left = inked.map(\.0).min(), let right = inked.map(\.0).max(),
              let top = inked.map(\.1).min(), let foot = inked.map(\.1).max() else {
            return nil
        }
        return CGRect(
            x: CGFloat(left) / scale, y: CGFloat(top) / scale,
            width: CGFloat(right + 1 - left) / scale, height: CGFloat(foot + 1 - top) / scale
        )
    }
}

extension NSColor {
    /// The colour in the dark, flattened over `ground`, in sRGB.
    func dark(over ground: NSColor) -> NSColor {
        var flat = ground

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            guard let colour = usingColorSpace(.sRGB), let ground = ground.usingColorSpace(.sRGB) else {
                return
            }

            let alpha = colour.alphaComponent

            flat = NSColor(
                srgbRed: colour.redComponent * alpha + ground.redComponent * (1 - alpha),
                green: colour.greenComponent * alpha + ground.greenComponent * (1 - alpha),
                blue: colour.blueComponent * alpha + ground.blueComponent * (1 - alpha), alpha: 1
            )
        }
        return flat
    }

    var channels: [CGFloat] {
        [redComponent, greenComponent, blueComponent]
    }
}
