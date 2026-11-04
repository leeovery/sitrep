@testable import SitRep
import SitRepWindow
import Testing

/// A project's page fills the window beside the sidebar, inside the page's inset: Now and Log go three across at the
/// window's size, as A3 revised draws them, and two at its narrowest.
struct ProjectPageGridTests {
    private static func columns(atWindowWidth width: Double) -> Int {
        ProjectPage.columns(across: width - WindowStyle.boardWidth - 2 * WindowStyle.pageInset)
    }

    @Test func threeAcrossAtTheWindowsSizeTwoAtItsNarrowest() {
        #expect(Self.columns(atWindowWidth: WindowStyle.size.width) == 3)
        #expect(Self.columns(atWindowWidth: WindowStyle.smallest.width) == 2)
    }
}
