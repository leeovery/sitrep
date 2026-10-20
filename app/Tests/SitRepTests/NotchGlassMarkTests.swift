@testable import SitRep
import SitRepPanel
import Testing

/// The glass notch reads as the black's does: tinted dark with a rim at the notch and as it reaches for the pointer,
/// easing off as the panel pours to the plain glass Lee liked with the panel out.
struct NotchGlassMarkTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)

    private static func marks(_ style: NotchApproach.Style) -> [NotchGlassMark] {
        NotchApproach.frames(style, needsLee: false, on: stage, content: Content(laying: [])).map(NotchGlassMark.init)
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

    @Test(arguments: NotchApproach.Style.allCases)
    func theMarkEasesOffAsThePanelPours(style: NotchApproach.Style) {
        let tints = Self.marks(style).map(\.tint)

        #expect(tints.contains { $0 > 0.1 && $0 < 0.4 })
        #expect(zip(tints, tints.dropFirst()).allSatisfy { $1 <= $0 + 0.05 })
    }
}
