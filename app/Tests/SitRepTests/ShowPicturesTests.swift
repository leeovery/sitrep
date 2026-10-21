import AppKit
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What Stays on Screen's three pictures: still under the pointer, sharing the page's column, as Paper draws them.
@MainActor
struct ShowPicturesTests {
    /// The row's height at a width: 4 above, the picture, 10, its label 18 tall, 8 below.
    private static func height(at width: CGFloat) -> CGFloat {
        NSHostingController(rootView: ShowPictures(show: .constant(.notch), isOnScreen: true))
            .sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }

    /// 3 × 225 + 2 × 16 is the drawn column's 707, each picture 225 × 145.
    @Test func atTheDrawnColumnEachPictureIsTheDrawingsSize() {
        #expect(abs(Self.height(at: 707) - (4 + 145 + 10 + 18 + 8)) < 0.5)
    }

    /// The three share any column equally, 16 apart, each keeping the drawing's shape.
    @Test(arguments: [500.0, 1000.0])
    func atAnyWidthTheThreeShareTheColumnInTheDrawingsShape(width: CGFloat) {
        let picture = (width - 2 * 16) / 3 * 145 / 225

        #expect(abs(Self.height(at: width) - (4 + picture + 10 + 18 + 8)) < 0.5)
    }

    /// A tile not chosen, drawn 225 wide, the pointer over it or not.
    private static func tile(isOver: Bool) throws -> Drawn {
        try Drawn(TileFace(choice: .strip, isChosen: false, isOver: isOver), size: CGSize(width: 225, height: 173))
    }

    /// Under the pointer its hairline, `#FFFFFF26`, lifts to `#FFFFFF4D`, and nothing else changes: the picture inside
    /// the hairline is drawn the same to the pixel, so nothing in it moves.
    @Test func underThePointerOnlyTheHairlineLifts() throws {
        let away = try Self.tile(isOver: false)
        let over = try Self.tile(isOver: true)
        let hairline = CGRect(x: 100, y: 0, width: 25, height: 0.5)
        // inside the hairline, clear of the corners, where it curves in 12
        let inside = [CGRect(x: 1, y: 12, width: 223, height: 121), CGRect(x: 12, y: 1, width: 201, height: 143)]

        #expect(try over.brightest(in: hairline).lightness > away.brightest(in: hairline).lightness + 3 * 0.05)
        for part in inside {
            #expect(over.pixels(in: part) == away.pixels(in: part))
        }
    }
}
