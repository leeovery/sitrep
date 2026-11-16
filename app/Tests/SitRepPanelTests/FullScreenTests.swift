import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Lee's screens in the window list's coordinates, the Studio Display the main one and the built-in to its right, and
/// the windows as the list gave them while Paper went full screen on the Studio Display and out again.
@Suite(.backstop)
struct FullScreenTests {
    static let studio = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    static let builtIn = CGRect(x: 2560, y: 904, width: 1728, height: 1117)

    static func entry(_ owner: String, _ layer: Int, _ bounds: CGRect, name: String = "") -> [String: Any] {
        [
            kCGWindowOwnerName as String: owner,
            kCGWindowLayer as String: layer,
            kCGWindowBounds as String: [
                "X": bounds.minX, "Y": bounds.minY, "Width": bounds.width, "Height": bounds.height,
            ],
            kCGWindowName as String: name,
        ]
    }

    static func backdrop(_ display: CGRect) -> [String: Any] {
        entry("Dock", -2_147_483_622, display, name: "Fullscreen Backdrop")
    }

    static func wallpaper(_ display: CGRect) -> [String: Any] {
        entry("Dock", -2_147_483_624, display, name: "Wallpaper-D90D47CC")
    }

    static var paper: [String: Any] { entry("Paper", 0, studio) }
    static var menubar: [String: Any] {
        entry("Window Server", 24, CGRect(x: 0, y: 0, width: 2560, height: 30), name: "Menubar")
    }

    @Test func theDocksBackdropCoveringTheDisplaySaysAFullScreenAppHasIt() {
        let list = [Self.paper, Self.backdrop(Self.studio), Self.wallpaper(Self.studio), Self.wallpaper(Self.builtIn)]

        #expect(FullScreen.backdrop(on: Self.studio, in: list)?.bounds == Self.studio)
    }

    @Test func theBuiltInsOwnBackdropLeavesThePanelOnTheStudioDisplay() {
        let list = [Self.menubar, Self.backdrop(Self.builtIn), Self.wallpaper(Self.studio)]

        #expect(FullScreen.backdrop(on: Self.studio, in: list) == nil)
        #expect(FullScreen.backdrop(on: Self.builtIn, in: list) != nil)
    }

    @Test func theWallpaperAloneIsNoFullScreen() {
        #expect(FullScreen.backdrop(on: Self.studio, in: [Self.menubar, Self.wallpaper(Self.studio)]) == nil)
    }

    /// A Space swipe: for a moment the Dock has a window over the whole display, at the apps' layer.
    @Test func aSpaceSwipesDockWindowIsNoFullScreen() {
        let swipe = Self.entry("Dock", 0, Self.studio)

        #expect(FullScreen.backdrop(on: Self.studio, in: [swipe, Self.wallpaper(Self.studio)]) == nil)
    }

    @Test func withNoDockWindowsAtAllNothingIsFullScreen() {
        #expect(FullScreen.backdrop(on: Self.studio, in: [Self.paper, Self.menubar]) == nil)
    }

    /// Going in, the backdrop slides onto the display; until it covers it, the display isn't yet the app's.
    @Test func aBackdropStillSlidingOntoTheDisplayIsNotYetFullScreen() {
        let sliding = Self.backdrop(CGRect(x: 864, y: 0, width: 2560, height: 1440))

        #expect(FullScreen.backdrop(on: Self.studio, in: [sliding]) == nil)
    }

    @Test func onlyTheDocksBackdropCounts() {
        let other = Self.entry("CleanShot X", -2_147_483_622, Self.studio)

        #expect(FullScreen.backdrop(on: Self.studio, in: [other]) == nil)
    }

    @Test func anEntryMissingItsOwnerLayerOrBoundsIsPassedOver() {
        let full = Self.backdrop(Self.studio)
        let partial = [kCGWindowOwnerName, kCGWindowLayer, kCGWindowBounds].map { key in
            full.filter { $0.key != key as String }
        }

        #expect(partial.allSatisfy { ListedWindow($0) == nil })
        #expect(ListedWindow(full) == ListedWindow(owner: "Dock", layer: -2_147_483_622, bounds: Self.studio))
    }
}
