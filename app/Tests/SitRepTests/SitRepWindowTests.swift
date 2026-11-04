import AppKit
@testable import SitRep
import SitRepLines
@testable import SitRepWindow
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

/// The window's toolbar over its split, made, never shown: its items for a place and for a page filling the window,
/// what each enables, the position's words and what VoiceOver reads of each, and where each press goes.
@MainActor
struct WindowToolbarTests {
    /// The toolbar in a window over the split, the presses its actions hear, recorded.
    @MainActor
    private final class Made {
        let split = SitRepWindow.split(
            sidebar: NSViewController.with(NSView()), list: NSViewController.with(NSView()),
            page: NSViewController.with(NSView())
        )
        var pressed: [String] = []
        private(set) lazy var bar = WindowToolbar(splitView: split.splitView, actions: actions)
        private(set) lazy var window = SitRepWindow.window(split, toolbar: bar.toolbar)

        private var actions: WindowActions {
            var actions = WindowActions()

            actions.back = { [weak self] in self?.pressed.append("back") }
            actions.forward = { [weak self] in self?.pressed.append("forward") }
            actions.step = { [weak self] down in self?.pressed.append(down ? "down" : "up") }
            return actions
        }

        func show(_ toolbar: Toolbar) {
            bar.show(toolbar, in: window)
        }

        var items: [NSToolbarItem.Identifier] {
            bar.toolbar.items.map(\.itemIdentifier)
        }
    }

    /// Your turn, its third row of five picked, a step back, none forward, a row above and none below.
    private static let yourTurn = Toolbar(
        canGoBack: true, canGoForward: false,
        listing: .init(title: "Your turn", position: .init(index: 3, count: 5), canStepUp: true, canStepDown: false)
    )

    /// A project's page: Back and Forward alone.
    private static let fullPage = Toolbar(canGoBack: false, canGoForward: true, listing: nil)

    /// Back and Forward past the sidebar; the place's name as the title over the list, whose divider is tracked; then
    /// the position and up and down trailing over the page.
    @Test func onAPlaceItHasBackAndForwardThePlacesTitleThePositionAndUpAndDown() throws {
        let made = Made()

        made.show(Self.yourTurn)
        #expect(made.items == [
            .sidebarTrackingSeparator, WindowToolbar.backAndForwardItem, WindowToolbar.listSeparator, .flexibleSpace,
            WindowToolbar.positionItem, WindowToolbar.upAndDownItem,
        ])
        #expect(made.window.title == "Your turn")
        #expect(made.window.titleVisibility == .visible)

        let separator = try #require(made.bar.toolbar.items[2] as? NSTrackingSeparatorToolbarItem)

        #expect(separator.splitView === made.split.splitView)
        #expect(separator.dividerIndex == 1)
    }

    /// A project's page or a session's: Back and Forward alone, at the page's leading edge, no title; a place again
    /// brings the rest back.
    @Test func onAFullPageItHasBackAndForwardAlone() {
        let made = Made()

        made.show(Self.fullPage)
        #expect(made.items == [.sidebarTrackingSeparator, WindowToolbar.backAndForwardItem])
        #expect(made.window.titleVisibility == .hidden)
        made.show(Self.yourTurn)
        #expect(made.items == WindowToolbar.place)
        #expect(made.window.titleVisibility == .visible)
    }

    @Test func backAndForwardAreTheToolbarsNavigationWithNothingToCustomise() throws {
        let made = Made()

        made.show(Self.yourTurn)

        let steps = try #require(made.bar.toolbar.items.first { $0.itemIdentifier == WindowToolbar.backAndForwardItem })

        #expect(steps.isNavigational)
        #expect(steps.view === made.bar.backAndForward)
        #expect(!made.bar.toolbar.allowsUserCustomization)
    }

    /// Each side dimmed where there is nowhere to go, Back and Forward from the history, up and down from the list.
    @Test func eachSideIsDimmedWhereThereIsNowhereToGo() {
        let made = Made()

        made.show(Self.yourTurn)
        #expect(made.bar.backAndForward.isEnabled(forSegment: 0) && !made.bar.backAndForward.isEnabled(forSegment: 1))
        #expect(made.bar.upAndDown.isEnabled(forSegment: 0) && !made.bar.upAndDown.isEnabled(forSegment: 1))
        made.show(Self.fullPage)
        #expect(!made.bar.backAndForward.isEnabled(forSegment: 0) && made.bar.backAndForward.isEnabled(forSegment: 1))
        #expect(made.bar.shown == Self.fullPage)
    }

    /// "3 / 5", which VoiceOver reads "3 of 5"; with nothing shown picked, no words.
    @Test func thePositionSaysWhereThePickStandsOnlyWhileOneShowsPicked() {
        let made = Made()

        made.show(Self.yourTurn)
        #expect(made.bar.position.stringValue == "3 / 5")
        #expect(made.bar.position.accessibilityLabel() == "3 of 5")
        made.show(Toolbar(listing: .init(title: "Needs you", canStepDown: true)))
        #expect(made.bar.position.stringValue.isEmpty)
        #expect(made.bar.position.accessibilityLabel() == nil)
        #expect(!made.bar.upAndDown.isEnabled(forSegment: 0) && made.bar.upAndDown.isEnabled(forSegment: 1))
    }

    /// VoiceOver reads each side in words.
    @Test func eachSideReadsInWords() {
        let made = Made()
        let names = { (control: NSSegmentedControl) in
            (0 ..< control.segmentCount).map { control.image(forSegment: $0)?.accessibilityDescription }
        }

        #expect(names(made.bar.backAndForward) == ["Back", "Forward"])
        #expect(names(made.bar.upAndDown) == ["Previous", "Next"])
    }

    /// The model tells the toolbar with each change as it takes it: a project opened has Back and Forward alone, with a
    /// step back, at once.
    @Test func theModelTellsTheToolbarWithEachChange() throws {
        let model = try WindowModel.made()
        let made = Made()

        model.showToolbar = { made.show($0) }
        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened()
        #expect(made.items == WindowToolbar.place)
        #expect(made.window.title == "Needs you")
        model.actions.click(.project("switchboard"))
        #expect(made.items == WindowToolbar.fullPage)
        #expect(made.bar.shown.canGoBack)
    }

    /// A momentary control holds the segment pressed only while a click sends its action, so a press is sent from a
    /// control holding it.
    @Test func eachSideGoesWhereItSays() {
        let made = Made()
        let press = { (control: NSSegmentedControl, segment: Int) in
            let pressed = NSSegmentedControl(labels: ["", ""], trackingMode: .selectOne, target: nil, action: nil)

            pressed.selectedSegment = segment
            _ = pressed.sendAction(control.action, to: control.target)
        }

        made.show(Self.yourTurn)
        press(made.bar.backAndForward, 0)
        press(made.bar.backAndForward, 1)
        press(made.bar.upAndDown, 0)
        press(made.bar.upAndDown, 1)
        #expect(made.pressed == ["back", "forward", "up", "down"])
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
