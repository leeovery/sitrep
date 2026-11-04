import AppKit
@testable import SitRep
import Testing

/// The SitRep window, made, never shown. What macOS draws of it, its glass and the traffic lights' place, shows only
/// on the screen; its parts can be read here.
@MainActor
struct SitRepWindowTests {
    private static func split() -> NSSplitViewController {
        SitRepWindow.split(
            sidebar: NSViewController.with(NSView()), list: NSViewController.with(NSView()),
            page: NSViewController.with(NSView())
        )
    }

    /// It goes to the Space Lee is on only as SitRep brings it forward (`ForwardWindowTests`).
    @Test func itStaysOnItsOwnSpaceTillSitRepBringsItForward() {
        let window = SitRepWindow.window(Self.split(), toolbar: NSToolbar())

        #expect(!window.collectionBehavior.contains(.moveToActiveSpace))
    }

    @Test func theSidebarIsTheSystemsOwnTheListItsContentListAndThePageBesideThem() {
        #expect(Self.split().splitViewItems.map(\.behavior) == [.sidebar, .contentList, .default])
    }

    /// With no toggle to bring them back, neither the sidebar nor the list can be dragged shut nor shut by the window
    /// narrowing.
    @Test(arguments: [0, 1])
    func theSidebarAndTheListNeverCollapseByLee(item: Int) throws {
        let side = Self.split().splitViewItems[item]

        #expect(!side.canCollapse)
        #expect(!side.canCollapseFromWindowResize)
    }

    @Test(arguments: [(0, WindowStyle.boardWidth), (1, WindowStyle.listWidth)])
    func theSidebarAndTheListKeepTheDrawingsWidths(item: Int, width: CGFloat) throws {
        let split = Self.split()
        let window = SitRepWindow.window(split, toolbar: NSToolbar())

        window.layoutIfNeeded()

        let side = split.splitViewItems[item]

        #expect(side.minimumThickness == width)
        #expect(side.maximumThickness == width)
        #expect(side.viewController.view.frame.width == width)
        #expect(WindowStyle.boardWidth == 236 && WindowStyle.listWidth == 300)
    }

    /// A project's page and a session's fill the window, the list folded away; a place brings it back.
    @Test func theListFoldsAwayWhileThePageFillsTheWindow() throws {
        let split = Self.split()
        let window = SitRepWindow.window(split, toolbar: NSToolbar())
        let list = split.splitViewItems[1]
        let page = try #require(split.splitViewItems.last).viewController.view

        window.layoutIfNeeded()
        let beside = page.frame.width
        SitRepWindow.fold(list, isFullPage: true)
        window.layoutIfNeeded()
        let filling = page.frame.width

        #expect(list.isCollapsed)
        #expect(filling - beside >= WindowStyle.listWidth)
        SitRepWindow.fold(list, isFullPage: false)
        window.layoutIfNeeded()
        #expect(!list.isCollapsed)
        #expect(page.frame.width == beside)
    }

    /// The toolbar's titlebar is what macOS 26 sets the traffic lights inside the sidebar's glass by, which only the
    /// screen shows. Its title shows only as the toolbar shows it.
    @Test func itHasAUnifiedToolbarOverItsFullSizeContent() throws {
        let toolbar = NSToolbar()
        let window = SitRepWindow.window(Self.split(), toolbar: toolbar)

        #expect(window.toolbar === toolbar)
        #expect(window.toolbarStyle == .unified)
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titleVisibility == .hidden)
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
