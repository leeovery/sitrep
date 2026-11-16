import AppKit
@testable import SitRep
import Testing

/// A line of the card's words cut short with an ellipsis fits its box: Core Text's own cut runs past the width it is
/// given by up to the ellipsis at many widths, so a name cut short before its count or its project would run into
/// them.
@MainActor
struct TextLineTests {
    private static let long = TextLine.text(
        String(repeating: "Finish the Tailspin migration ", count: 3), EdgeStyle.lineMedium, EdgeStyle.ink,
        kern: EdgeStyle.tightKern(EdgeStyle.lineMedium)
    )

    @Test(arguments: Array(stride(from: 160.0, through: 190.0, by: 1)))
    func aLineCutShortFitsItsBox(width: Double) {
        let line = TextLine(Self.long, in: CGRect(x: 0, y: 0, width: width, height: 18))

        #expect(line.width <= width && line.width > width - 12)
    }

    /// Narrower than the ellipsis, where Core Text cuts none, nothing is drawn; as wide as the ellipsis, the ellipsis
    /// alone: never the whole line, overrunning its box.
    @Test func narrowerThanAnyCutItIsTheEllipsisAloneOrNothing() {
        let font = EdgeStyle.lineMedium
        let ellipsis = TextLine.width(TextLine.text("…", font, EdgeStyle.ink, kern: EdgeStyle.tightKern(font)))
        let none = TextLine(Self.long, in: CGRect(x: 0, y: 0, width: ellipsis - 1, height: 18))
        let alone = TextLine(Self.long, in: CGRect(x: 0, y: 0, width: ellipsis + 0.5, height: 18))

        #expect(none.width == 0)
        #expect(abs(alone.width - ellipsis) < 0.01)
    }

    /// A line that fits its box is drawn whole, though the box is narrower than the ellipsis, where Core Text cuts
    /// none: a count of one figure, as wide as it is set.
    @Test func aLineNarrowerThanTheEllipsisThatFitsIsWhole() {
        let count = TextLine.text("3", EdgeStyle.count, EdgeStyle.ink2)
        let set = TextLine.width(count)
        let line = TextLine(count, in: CGRect(x: 0, y: 0, width: set, height: 18))

        #expect(set < TextLine.width(TextLine.text("…", EdgeStyle.count, EdgeStyle.ink2)))
        #expect(line.width == set)
    }
}
