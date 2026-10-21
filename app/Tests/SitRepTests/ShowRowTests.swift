import AppKit
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What stays on screen's Show row, set as System Settings sets Appearance's on macOS 26: on the real page, as the
/// window lays it out (`Hosted`), and its tiles drawn under the pointer, which a window never shown can't be given.
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

    /// The card's raise, where the Show row draws nothing: under its label, clear of a line.
    private static func raise(_ drawn: Drawn) throws -> NSColor {
        try #require(drawn.pixels(in: CGRect(x: 54, y: top + 70, width: 0.5, height: 0.5)).first)
    }

    /// Across the pictures' middle, Notch chosen: its ring, 3 wide past a gap of the raise, 0.5, round its picture,
    /// then Strip's and Nothing's, each 67 wide, 15 apart, the last 13.5 in from the card's right, whatever the
    /// width.
    @Test(arguments: [564.0, 956, 1400])
    func thePicturesKeepTheirSizeAndPlaceAtAnyWidth(page: CGFloat) async throws {
        let drawn = try await Hosted.drawn(width: page)
        let lefts = Self.lefts(page)
        let across = try drawn.spans(
            atY: Self.top + 13.5 + 22, unlike: Self.raise(drawn), from: lefts[0] - 8, to: Self.right(page) - 1
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

    /// Down the chosen picture, clear of its corners and its name: the ring's top 10 under the card's, over its
    /// picture, 44 tall, and under it.
    @Test func theChosenPictureIs44TallInItsRing() async throws {
        let drawn = try await Hosted.drawn(width: 956)
        let down = try drawn.spans(
            atX: Self.lefts(956)[0] + 14, unlike: Self.raise(drawn), from: Self.top + 1, to: Self.top + 85
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
        let drawn = try await Hosted.drawn(width: 956)
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
    /// the label colour, the others' regular in the secondary colour. Its weight is told by its ink, near the same
    /// word's at the weight it should have, drawn alike in a window.
    @Test(arguments: EdgeSettings.Show.allCases)
    func theChosenNameIsSemiboldInTheLabelColour(chosen: EdgeSettings.Show) async throws {
        let drawn = try await Hosted.drawn(width: 956) { $0.show = chosen }
        let raise = try Self.raise(drawn)
        let pixel = 1 / drawn.scale

        for (choice, left) in zip(EdgeSettings.Show.allCases, Self.lefts(956)) {
            let isChosen = choice == chosen
            let colour: NSColor = isChosen ? .labelColor : .secondaryLabelColor
            let area = CGRect(x: left - 3.5, y: Self.top + 62, width: 74, height: 14)
            let name = try #require(drawn.ink(in: area, over: raise))
            let ink = drawn.inkMass(in: area, over: raise)
            let semibold = try Self.inkMass(choice.title, .semibold, colour, over: raise)
            let regular = try Self.inkMass(choice.title, .regular, colour, over: raise)
            let (weight, other) = isChosen ? (semibold, regular) : (regular, semibold)

            try drawn.expectWords(in: area, colour, over: raise)
            // within a quarter of the way to the other weight: a medium between them is neither
            #expect(abs(ink - weight) < abs(other - weight) / 4)
            #expect(abs(name.midX - (left + 33.5)) < 2 * pixel)
            if choice == .notch {
                // with nothing below its line
                #expect(abs(name.maxY - (Self.top + 73)) < pixel)
            }
        }
    }

    /// A word's ink, 11 at `weight` in `colour` over the card's raise, drawn in a window as the page is.
    private static func inkMass(
        _ word: String, _ weight: Font.Weight, _ colour: NSColor, over raise: NSColor
    ) throws -> CGFloat {
        let size = CGSize(width: 74, height: 14)
        let words = Text(word)
            .font(.subheadline.weight(weight))
            .foregroundStyle(Color(nsColor: colour))
            .frame(width: size.width, height: size.height)
            .background(WindowStyle.raise)

        return try Drawn(Hosted(words, size: size).hosting).inkMass(in: CGRect(origin: .zero, size: size), over: raise)
    }

    /// Show stands at the top of its row, in a label's line 10 under the card's top, as Appearance's label does.
    @Test func showStandsAtTheTopOfItsRow() async throws {
        let drawn = try await Hosted.drawn(width: 956)
        let show = try #require(drawn.ink(in: CGRect(x: 54, y: Self.top, width: 60, height: 86), over: Self.raise(drawn)))

        #expect(show.minY >= Self.top + 10)
        #expect(show.maxY <= Self.top + 26)
    }

    /// With Nothing chosen, the card is the Show row alone, 86 tall, its line under Show in the secondary colour saying
    /// what carries the board; with the notch or the strip, Show has no line.
    @Test(arguments: [564.0, 956])
    func withNothingTheCardIsTheShowRowWithItsLine(page: CGFloat) async throws {
        let nothing = try await Hosted.drawn(width: page) { $0.show = .nothing }
        let strip = try await Hosted.drawn(width: page) { $0.show = .strip }
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

    /// A tile as it lays out: the ring's room round its 67 × 44 picture, then its name's line of 14, 1 under it.
    private static let size = CGSize(width: 74, height: 66)
    /// Round the picture, the gap and the ring.
    private static let room: CGFloat = 3.5

    private static func tile(_ choice: EdgeSettings.Show, isChosen: Bool, isOver: Bool) throws -> Drawn {
        try Drawn(TileFace(choice: choice, isChosen: isChosen, isOver: isOver), size: size)
    }

    /// The hairline along the picture's top, clear of its corners, and the tile's name.
    private static let hairline = CGRect(x: 30, y: room, width: 14, height: 0.5)
    private static let name = CGRect(x: 10, y: 52, width: 54, height: 14)

    /// The hairline is drawn as the strip's picture under a hairline of white at `alpha` is.
    private static func expectHairline(_ drawn: Drawn, alpha: CGFloat) throws {
        let picture = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let drawing = try Drawn(
            EdgePicture(show: .strip)
                .frame(width: 67, height: 44)
                .clipShape(picture)
                .overlay(picture.strokeBorder(.white.opacity(alpha), lineWidth: 0.5))
                .padding(room)
                .frame(maxHeight: .infinity, alignment: .top),
            size: size
        )

        #expect(drawn.pixels(in: hairline) == drawing.pixels(in: hairline))
    }

    /// Under the pointer a tile not chosen lifts its hairline from white at 15% to 40%, and its name from the secondary
    /// colour to the label colour; nothing else changes: the picture inside the hairline is drawn the same to the pixel.
    @Test func underThePointerOnlyTheHairlineAndTheNameLift() throws {
        let away = try Self.tile(.strip, isChosen: false, isOver: false)
        let over = try Self.tile(.strip, isChosen: false, isOver: true)
        // inside the hairline, clear of the corners, whose continuous curve runs 8 along each edge
        let inside = [
            CGRect(x: Self.room + 1, y: Self.room + 8, width: 65, height: 28),
            CGRect(x: Self.room + 8, y: Self.room + 1, width: 51, height: 42),
        ]

        try Self.expectHairline(away, alpha: 0.15)
        try Self.expectHairline(over, alpha: 0.4)
        try away.expectWords(in: Self.name, .secondaryLabelColor, over: .black)
        try over.expectWords(in: Self.name, .labelColor, over: .black)
        for part in inside {
            #expect(over.pixels(in: part) == away.pixels(in: part))
        }
    }

    /// The chosen tile is drawn the same under the pointer or not: its ring, its picture and its name.
    @Test func theChosenTileHoldsStillUnderThePointer() throws {
        let away = try Self.tile(.notch, isChosen: true, isOver: false)
        let over = try Self.tile(.notch, isChosen: true, isOver: true)
        let whole = CGRect(origin: .zero, size: Self.size)

        #expect(over.pixels(in: whole) == away.pixels(in: whole))
        try over.expectWords(in: Self.name, .labelColor, over: .black)
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

    /// Where a row of pixels across the drawing, from `start` to `end`, is not `ground`, each span from its first such
    /// pixel's left to its last's right.
    func spans(atY y: CGFloat, unlike ground: NSColor, from start: CGFloat, to end: CGFloat) -> [ClosedRange<CGFloat>] {
        let row = Int((y * scale).rounded())

        return spans(Int((start * scale).rounded())..<Int((end * scale).rounded()), unlike: ground) {
            bitmap.colorAt(x: $0, y: row)
        }
    }

    /// Where a column of pixels down the drawing, from `start` to `end`, is not `ground`, each span from its first
    /// such pixel's top to its last's foot.
    func spans(atX x: CGFloat, unlike ground: NSColor, from start: CGFloat, to end: CGFloat) -> [ClosedRange<CGFloat>] {
        let column = Int((x * scale).rounded())

        return spans(Int((start * scale).rounded())..<Int((end * scale).rounded()), unlike: ground) {
            bitmap.colorAt(x: column, y: $0)
        }
    }

    /// Each run of pixels in `pixels` more than 4 levels of 255 from `ground` in any channel.
    private func spans(
        _ pixels: Range<Int>, unlike ground: NSColor, at color: (Int) -> NSColor?
    ) -> [ClosedRange<CGFloat>] {
        var spans: [ClosedRange<CGFloat>] = []
        var first: Int?

        for pixel in pixels.lowerBound...pixels.upperBound {
            let colour = pixel < pixels.upperBound ? color(pixel)?.usingColorSpace(.sRGB) : nil

            if let colour, zip(colour.channels, ground.channels).contains(where: { abs($0 - $1) * 255 > 4 }) {
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
