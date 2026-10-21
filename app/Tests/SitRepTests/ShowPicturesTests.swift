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

    /// `#FFFFFF26` lifted to `#FFFFFF4D`, at once: the only thing the pointer changes.
    @Test func aTileNotChosenLiftsItsHairlineUnderThePointer() {
        #expect(abs(PictureHover.hairline(isOver: false) - 0x26 / 255) < 0.002)
        #expect(abs(PictureHover.hairline(isOver: true) - 0x4D / 255) < 0.002)
    }

    @Test func theNotchsCrestIsAStraightRunAtX9() {
        #expect(abs(NotchPicture.outline.boundingRect.maxX - 9) < 0.001)
    }

    @Test func theStripsWorkingRingsStandAtTwelveAndFortyFiveAndTheRestAreWhole() {
        #expect(StripPicture.restingArcs == [nil, nil, 0, 45])
        #expect(StripPicture.rings.map(\.ring) == [.needs, .turn, .working, .working])
    }
}
