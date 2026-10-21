import AppKit
@testable import SitRep
import Testing

/// The SitRep window, made, never shown. What macOS draws of it, its glass and the traffic lights' place, shows only
/// on the screen; its parts can be read here.
@MainActor
struct SitRepWindowTests {
    private static func split() -> NSSplitViewController {
        SitRepWindow.split(sidebar: NSViewController.with(NSView()), page: NSViewController.with(NSView()))
    }

    @Test func itOpensOnTheSpaceLeeIsOn() {
        #expect(SitRepWindow.window(Self.split()).collectionBehavior.contains(.moveToActiveSpace))
    }

    @Test func theBoardIsTheSystemsOwnSidebarAndThePageSitsBesideIt() {
        #expect(Self.split().splitViewItems.map(\.behavior) == [.sidebar, .default])
    }

    /// With no toggle to bring it back, it can neither be dragged shut nor shut by the window narrowing.
    @Test func theSidebarNeverCollapses() throws {
        let sidebar = try #require(Self.split().splitViewItems.first)

        #expect(!sidebar.canCollapse)
        #expect(!sidebar.canCollapseFromWindowResize)
    }

    @Test func theSidebarKeepsTheDrawingsWidth() throws {
        let split = Self.split()
        let window = SitRepWindow.window(split)

        window.layoutIfNeeded()

        let sidebar = try #require(split.splitViewItems.first)

        #expect(sidebar.minimumThickness == WindowStyle.boardWidth)
        #expect(sidebar.maximumThickness == WindowStyle.boardWidth)
        #expect(sidebar.viewController.view.frame.width == WindowStyle.boardWidth)
    }

    /// The toolbar's titlebar is what macOS 26 sets the traffic lights inside the sidebar's glass by, which only the
    /// screen shows.
    @Test func itHasAnEmptyUnifiedToolbarOverItsFullSizeContent() throws {
        let window = SitRepWindow.window(Self.split())
        let toolbar = try #require(window.toolbar)

        #expect(toolbar.items.isEmpty)
        #expect(!toolbar.allowsUserCustomization)
        #expect(window.toolbarStyle == .unified)
        #expect(window.styleMask.contains(.fullSizeContentView))
    }
}

extension NSViewController {
    /// A controller over this view, for a window made in a test.
    static func with(_ view: NSView) -> NSViewController {
        let controller = NSViewController()

        controller.view = view
        return controller
    }
}
