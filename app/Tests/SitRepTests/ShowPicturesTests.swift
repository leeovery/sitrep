import AppKit
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What Stays on Screen's three pictures: still under the pointer, filling the page's column, as Paper draws them.
@MainActor
struct ShowPicturesTests {
    /// The row's height at a width: the picture, 8, its label 16 tall, 14 below.
    private static func height(at width: CGFloat) -> CGFloat {
        NSHostingController(rootView: ShowPictures(show: .constant(.notch), isOnScreen: true))
            .sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }

    /// The three fill any column equally, 16 apart, each keeping the drawing's 225:145: at 704, 224 × 144.4.
    @Test(arguments: [704.0, 500.0])
    func theThreeFillTheColumnInTheDrawingsShape(width: CGFloat) {
        let picture = (width - 2 * 16) / 3 * 145 / 225

        #expect(abs(Self.height(at: width) - (picture + 8 + 16 + 14)) < 0.5)
    }

    /// Across the 704 column, Notch chosen: each tile 224 wide, 16 apart; round the chosen one, 2 of the page's
    /// black, then the accent ring to 4.5 past its edge.
    @Test func atTheColumnEachTileIs224WideAndTheChosenOneRinged() throws {
        let drawn = try Drawn(
            ShowPictures(show: .constant(.notch), isOnScreen: true).frame(width: 704), size: CGSize(width: 704, height: 200)
        )
        let lit = { (x: CGFloat) in try drawn.brightest(in: CGRect(x: x - 0.25, y: 60, width: 0.5, height: 1)).lightness > 0.05 }

        // the tiles' edges, the second's and third's hairlines lit at their left
        for (left, right) in [(240.0, 464.0), (480.0, 704.0)] {
            #expect(try !lit(left - 0.5))
            #expect(try lit(left + 0.25))
            #expect(try lit(right - 0.25))
        }
        #expect(try !lit(464.5))
        // the chosen tile: its picture to 224, black to 226, the ring to 228.5
        #expect(try lit(223.75))
        #expect(try !lit(225))
        #expect(try lit(227.25))
        #expect(try !lit(229))
    }

    /// A tile not chosen, drawn 225 wide, the pointer over it or not.
    private static func tile(isOver: Bool) throws -> Drawn {
        try Drawn(TileFace(choice: .strip, isChosen: false, isOver: isOver), size: CGSize(width: 225, height: 169))
    }

    /// The hairline along the tile's top, and its label.
    private static let hairline = CGRect(x: 100, y: 0, width: 25, height: 0.5)
    private static let label = CGRect(x: 80, y: 153, width: 65, height: 16)

    /// The hairline is drawn as the strip's picture under a hairline of white at `alpha` is.
    private static func expectHairline(_ drawn: Drawn, alpha: CGFloat) throws {
        let picture = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let drawing = try Drawn(
            EdgePicture(show: .strip)
                .frame(width: 225, height: 145)
                .clipShape(picture)
                .overlay(picture.strokeBorder(.white.opacity(alpha), lineWidth: 0.5))
                .frame(maxHeight: .infinity, alignment: .top),
            size: CGSize(width: 225, height: 169)
        )

        #expect(drawn.pixels(in: hairline) == drawing.pixels(in: hairline))
    }

    /// Words drawn in `colour`: their brightest pixel within 0.07 of it, flattened over black, in each channel.
    private static func expectWords(_ drawn: Drawn, _ colour: NSColor) throws {
        #expect(abs(try drawn.brightest(in: label).lightness / 3 - colour.dark.whiteComponent) < 0.07)
    }

    /// Under the pointer its hairline lifts from white at 15% to 40%, and its label from the secondary colour to the
    /// label colour; nothing else changes: the picture inside the hairline is drawn the same to the pixel.
    @Test func underThePointerOnlyTheHairlineAndTheLabelLift() throws {
        let away = try Self.tile(isOver: false)
        let over = try Self.tile(isOver: true)
        // inside the hairline, clear of the corners, where it curves in 12
        let inside = [CGRect(x: 1, y: 12, width: 223, height: 121), CGRect(x: 12, y: 1, width: 201, height: 143)]

        try Self.expectHairline(away, alpha: 0.15)
        try Self.expectHairline(over, alpha: 0.4)
        try Self.expectWords(away, .secondaryLabelColor)
        try Self.expectWords(over, .labelColor)
        for part in inside {
            #expect(over.pixels(in: part) == away.pixels(in: part))
        }
    }

    @Test func theChosenTilesLabelIsTheLabelColourUnderThePointerOrNot() throws {
        for isOver in [false, true] {
            try Self.expectWords(
                Drawn(TileFace(choice: .notch, isChosen: true, isOver: isOver), size: CGSize(width: 225, height: 169)),
                .labelColor
            )
        }
    }
}

extension NSColor {
    /// The colour in the dark, flattened over black.
    fileprivate var dark: NSColor {
        var flat = NSColor.black

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            let colour = usingColorSpace(.genericGray) ?? self

            flat = NSColor(white: colour.whiteComponent * colour.alphaComponent, alpha: 1)
        }
        return flat
    }
}
