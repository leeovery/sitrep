import CoreGraphics
@testable import SitRepPanel
import Testing

/// On Lee's screens, the Studio Display with the menu bar and its Dock, and the built-in with its notch and no Dock.
struct FullScreenTests {
    static let studio = ScreenEdgeTests.studio
    static let builtIn = ScreenEdge(
        frame: ScreenEdgeTests.builtIn, visible: CGRect(x: 2560, y: -581, width: 1728, height: 1084)
    )

    static let plex: Int32 = 301, ghostty: Int32 = 302

    /// Plex full screen on the Studio Display, the menu bar's place and all, and the window maximised there: up to
    /// the menu bar, down to the Dock.
    static let onStudio = AppWindow(number: 1, app: plex, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440))
    static let maximised = AppWindow(number: 1, app: plex, frame: CGRect(x: 0, y: 86, width: 2560, height: 1324))
    /// Plex full screen on the built-in, under the notch: where a window maximised there is too.
    static let underTheNotch = AppWindow(
        number: 2, app: plex, frame: CGRect(x: 2560, y: -581, width: 1728, height: 1084)
    )
    static let terminal = AppWindow(number: 3, app: ghostty, frame: CGRect(x: 2766, y: -581, width: 1522, height: 900))

    static let plexFullScreen = FrontApp(id: plex, isFullScreen: true)
    static let plexWindowed = FrontApp(id: plex, isFullScreen: false)
    static let ghosttyInFront = FrontApp(id: ghostty, isFullScreen: false)

    private func taking(_ front: FrontApp?, _ windows: [AppWindow], on edge: ScreenEdge = studio) -> FullScreen {
        var fullScreen = FullScreen()
        fullScreen.take(front: front, windows: windows, on: edge)
        return fullScreen
    }

    @Test func aFullScreenAppHasThePanelsDisplay() {
        let fullScreen = taking(Self.plexFullScreen, [Self.onStudio])

        #expect(fullScreen.hasDisplay)
        #expect(fullScreen.window == Self.onStudio)
    }

    @Test func aMaximisedWindowLeavesThePanelOnItsDisplay() {
        #expect(!taking(Self.plexWindowed, [Self.maximised]).hasDisplay)
    }

    /// The size can't tell them apart under the notch; the app saying it is full screen does.
    @Test func underTheNotchAMaximisedWindowIsFullScreensSizeAndStillLeavesThePanel() {
        #expect(!taking(Self.plexWindowed, [Self.underTheNotch], on: Self.builtIn).hasDisplay)
        #expect(taking(Self.plexFullScreen, [Self.underTheNotch], on: Self.builtIn).hasDisplay)
    }

    /// An app saying it has the screen with no window filling the display, its sheet or a window it has elsewhere.
    @Test func aFullScreenAppsWindowThatDoesNotFillTheDisplayLeavesThePanel() {
        let sheet = AppWindow(number: 4, app: Self.plex, frame: CGRect(x: 980, y: 520, width: 600, height: 400))

        #expect(!taking(Self.plexFullScreen, [sheet]).hasDisplay)
    }

    @Test func eachOfSplitViewsWindowsFillsTheDisplay() {
        let left = AppWindow(number: 5, app: Self.plex, frame: CGRect(x: 0, y: 0, width: 1278, height: 1440))
        let right = AppWindow(number: 6, app: Self.ghostty, frame: CGRect(x: 1282, y: 0, width: 1278, height: 1440))

        #expect(taking(Self.plexFullScreen, [left, right]).hasDisplay)
        #expect(taking(FrontApp(id: Self.ghostty, isFullScreen: true), [left, right]).hasDisplay)
    }

    @Test func aFullScreenAppOnTheOtherDisplayLeavesThePanelWhereItIs() {
        #expect(!taking(Self.plexFullScreen, [Self.underTheNotch]).hasDisplay)
        #expect(!taking(Self.plexFullScreen, [Self.onStudio], on: Self.builtIn).hasDisplay)
    }

    @Test func anotherAppComingToTheFrontOnTheOtherDisplayLeavesTheDisplayToTheFullScreenApp() {
        var fullScreen = taking(Self.plexFullScreen, [Self.onStudio])

        fullScreen.take(front: Self.ghosttyInFront, windows: [Self.terminal, Self.onStudio], on: Self.studio)
        #expect(fullScreen.hasDisplay)

        fullScreen.take(front: nil, windows: [Self.terminal, Self.onStudio], on: Self.studio)
        #expect(fullScreen.hasDisplay)
    }

    @Test func theDisplaysSpaceChangingAwayFromTheFullScreenAppBringsThePanelBack() {
        var fullScreen = taking(Self.plexFullScreen, [Self.onStudio])

        fullScreen.take(front: Self.ghosttyInFront, windows: [Self.terminal], on: Self.studio)

        #expect(!fullScreen.hasDisplay)
    }

    @Test func theAppLeavingFullScreenBringsThePanelBackThoughItsWindowStaysTheSameSize() {
        var fullScreen = taking(Self.plexFullScreen, [Self.underTheNotch], on: Self.builtIn)

        fullScreen.take(front: Self.plexWindowed, windows: [Self.underTheNotch], on: Self.builtIn)

        #expect(!fullScreen.hasDisplay)
    }

    @Test func theFullScreenAppQuittingBringsThePanelBack() {
        var fullScreen = taking(Self.plexFullScreen, [Self.onStudio])

        fullScreen.take(front: nil, windows: [], on: Self.studio)

        #expect(!fullScreen.hasDisplay)
    }

    @Test func theWindowMovingOnTheScreenIsNoLongerTheFullScreenOne() {
        var fullScreen = taking(Self.plexFullScreen, [Self.onStudio])

        fullScreen.take(front: Self.ghosttyInFront, windows: [Self.maximised], on: Self.studio)

        #expect(!fullScreen.hasDisplay)
    }

    @Test func backOnTheFullScreenAppsSpaceThePanelStepsAsideAgain() {
        var fullScreen = taking(Self.plexFullScreen, [Self.onStudio])
        fullScreen.take(front: Self.ghosttyInFront, windows: [Self.terminal], on: Self.studio)

        fullScreen.take(front: Self.plexFullScreen, windows: [Self.onStudio], on: Self.studio)

        #expect(fullScreen.hasDisplay)
    }
}
