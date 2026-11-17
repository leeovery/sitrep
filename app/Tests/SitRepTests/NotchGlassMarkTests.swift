@testable import SitRep
import SitRepPanel
import SitRepTestSupport
import Testing

/// The glass notch reads as the black's does: tinted dark with a rim at the notch and as it reaches for the pointer,
/// easing off as the panel pours to the plain glass Lee liked with the panel out.
@Suite(.backstop)
struct NotchGlassMarkTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)

    private static func frames(_ style: NotchApproach.Style, reducesMotion: Bool = false) -> [Frame] {
        NotchApproach.frames(
            style, needsLee: false, on: stage, content: Content(laying: []), reducesMotion: reducesMotion
        )
    }

    private static func marks(_ style: NotchApproach.Style) -> [NotchGlassMark] {
        frames(style).map { NotchGlassMark(openness: $0.openness) }
    }

    @Test(arguments: NotchApproach.Style.allCases)
    func theNotchAtRestIsMarkedInFull(style: NotchApproach.Style) throws {
        let mark = try #require(Self.marks(style).first)

        #expect(mark.tint == NotchGlassMark.notchTint)
        #expect(mark.rim == NotchGlassMark.notchRim)
    }

    @Test(arguments: NotchApproach.Style.allCases)
    func thePanelOutIsPlainGlass(style: NotchApproach.Style) throws {
        let mark = try #require(Self.marks(style).last)

        #expect(mark.tint == 0)
        #expect(mark.rim == 0)
    }

    /// Never a jump either way: the card pours in about six frames, giving up under a quarter of the mark in each.
    @Test(arguments: NotchApproach.Style.allCases)
    func theMarkEasesOffAsThePanelPours(style: NotchApproach.Style) {
        let tints = Self.marks(style).map(\.tint), drop = 0.3 * NotchGlassMark.notchTint

        #expect(tints.contains { $0 > 0.1 && $0 < 0.4 })
        expectEvery(zip(tints, tints.dropFirst())) { $1 <= $0 + 0.05 && $0 - $1 < drop }
    }

    /// Under reduced motion the notch cross-fades into the panel: the outline fading out keeps its own mark, the
    /// notch's, as it goes, and the panel coming in is plain glass from the start.
    @Test(arguments: NotchApproach.Style.allCases)
    func theOutlineFadingOutKeepsItsOwnMark(style: NotchApproach.Style) throws {
        let fadingIn = Self.frames(style, reducesMotion: true).filter { $0.fading != nil && $0.openness == 1 }
        let frame = try #require(fadingIn.first)
        let fading = try #require(frame.fading)

        #expect(NotchGlassMark(openness: Frame.openness(fading.outline)).tint == NotchGlassMark.notchTint)
        #expect(NotchGlassMark(openness: frame.openness).tint == 0)
    }
}
