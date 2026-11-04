import AppKit
@testable import SitRep
import SitRepLines
@testable import SitRepWindow
import Testing

/// The window's toolbar over its split, made, never shown: its items for a place and for a page filling the window,
/// each made afresh as it is inserted, what each enables, the title, the position's words and what VoiceOver reads of
/// each, where each press goes, from the toolbar and from its overflow menu, and the Go menu's Back and Forward.
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

        func item(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
            bar.toolbar.items.first { $0.itemIdentifier == identifier }
        }

        var backAndForward: NSToolbarItemGroup? { item(WindowToolbar.backAndForwardItem) as? NSToolbarItemGroup }
        var upAndDown: NSToolbarItemGroup? { item(WindowToolbar.upAndDownItem) as? NSToolbarItemGroup }
        var position: NSTextField? { item(WindowToolbar.positionItem)?.view as? NSTextField }
    }

    /// Your turn, its third row of five picked, a step back, none forward, a row above and none below.
    private static let yourTurn = Toolbar(
        title: "Your turn", canGoBack: true, canGoForward: false,
        listing: .init(position: .init(index: 3, count: 5), canStepUp: true, canStepDown: false)
    )

    /// Contoso's page: Back and Forward alone.
    private static let fullPage = Toolbar(title: "Contoso", canGoBack: false, canGoForward: true, listing: nil)

    /// Which sides of the group are enabled, in order.
    private static func enabled(_ group: NSToolbarItemGroup?) -> [Bool] {
        group?.subitems.map(\.isEnabled) ?? []
    }

    /// A side pressed as AppKit presses it, through its menu form, as the toolbar's overflow shows it.
    private static func press(_ group: NSToolbarItemGroup?, _ side: Int) throws {
        let menu = try #require(group?.subitems[side].menuFormRepresentation)
        let action = try #require(menu.action)

        NSApplication.shared.sendAction(action, to: menu.target, from: menu)
    }

    // MARK: The items

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

        let separator = try #require(made.item(WindowToolbar.listSeparator) as? NSTrackingSeparatorToolbarItem)

        #expect(separator.splitView === made.split.splitView)
        #expect(separator.dividerIndex == 1)
    }

    /// A project's page or a session's: Back and Forward alone, at the page's leading edge, the page's name the
    /// window's title but not shown.
    @Test func onAFullPageItHasBackAndForwardAloneItsTitleThePagesUnshown() {
        let made = Made()

        made.show(Self.fullPage)
        #expect(made.items == [.sidebarTrackingSeparator, WindowToolbar.backAndForwardItem])
        #expect(made.window.title == "Contoso")
        #expect(made.window.titleVisibility == .hidden)
    }

    /// Place, full page, place, twice: each place brings its items back made afresh, each with a view of its own, the
    /// list's divider tracked again, and what they show as the toolbar now says.
    @Test func eachPlaceAfterAFullPageMakesItsItemsAfresh() throws {
        let made = Made()
        var positions: [NSTextField] = []
        var separators: [NSToolbarItem] = []

        for _ in 0 ..< 2 {
            made.show(Self.yourTurn)
            made.show(Self.fullPage)
            made.show(Self.yourTurn)
            #expect(made.items == WindowToolbar.place)

            let separator = try #require(made.item(WindowToolbar.listSeparator) as? NSTrackingSeparatorToolbarItem)

            #expect(separator.splitView === made.split.splitView && separator.dividerIndex == 1)
            #expect(made.position?.stringValue == "3 / 5")
            #expect(Self.enabled(made.upAndDown) == [true, false])
            positions.append(try #require(made.position))
            separators.append(separator)
        }
        #expect(positions[0] !== positions[1])
        #expect(separators[0] !== separators[1])
    }

    @Test func backAndForwardAreTheToolbarsNavigationWithNothingToCustomise() throws {
        let made = Made()

        made.show(Self.yourTurn)
        #expect(made.backAndForward?.isNavigational == true)
        #expect(made.backAndForward?.subitems.count == 2)
        #expect(!made.bar.toolbar.allowsUserCustomization)
    }

    // MARK: What each shows

    /// Each side dimmed where there is nowhere to go, Back and Forward from the history, up and down from the list.
    @Test func eachSideIsDimmedWhereThereIsNowhereToGo() {
        let made = Made()

        made.show(Self.yourTurn)
        #expect(Self.enabled(made.backAndForward) == [true, false])
        #expect(Self.enabled(made.upAndDown) == [true, false])
        made.show(Self.fullPage)
        #expect(Self.enabled(made.backAndForward) == [false, true])
        #expect(made.bar.shown == Self.fullPage)
    }

    /// "3 / 5", which VoiceOver reads "3 of 5", once, as its value; with nothing shown picked, no words and nothing
    /// for VoiceOver.
    @Test func thePositionSaysWhereThePickStandsOnlyWhileOneShowsPicked() throws {
        let made = Made()

        made.show(Self.yourTurn)

        let position = try #require(made.position)

        #expect(position.stringValue == "3 / 5")
        #expect(position.accessibilityValue() == "3 of 5")
        #expect(position.accessibilityLabel() == nil)
        #expect(position.isAccessibilityElement())
        made.show(Toolbar(listing: .init(canStepDown: true)))
        #expect(position.stringValue.isEmpty)
        #expect(!position.isAccessibilityElement())
        #expect(Self.enabled(made.upAndDown) == [false, true])
    }

    /// VoiceOver reads each side in words, which are its tooltip too.
    @Test func eachSideReadsInWords() {
        let made = Made()
        let names = { (group: NSToolbarItemGroup?) in group?.subitems.map(\.image?.accessibilityDescription) ?? [] }
        let tips = { (group: NSToolbarItemGroup?) in group?.subitems.map(\.toolTip) ?? [] }

        made.show(Self.yourTurn)
        #expect(names(made.backAndForward) == ["Back", "Forward"])
        #expect(names(made.upAndDown) == ["Previous", "Next"])
        #expect(tips(made.backAndForward) == ["Back", "Forward"])
        #expect(tips(made.upAndDown) == ["Previous", "Next"])
    }

    // MARK: Presses

    /// Each side, pressed from its overflow menu form as from the toolbar, goes where it says.
    @Test func eachSideGoesWhereItSays() throws {
        let made = Made()

        made.show(Self.yourTurn)
        try Self.press(made.backAndForward, 0)
        try Self.press(made.backAndForward, 1)
        try Self.press(made.upAndDown, 0)
        try Self.press(made.upAndDown, 1)
        #expect(made.pressed == ["back", "forward", "up", "down"])
    }

    /// A press with no side selected, as VoiceOver or the keyboard can send a momentary control, goes nowhere.
    @Test func aPressWithNoSideSelectedGoesNowhere() throws {
        let made = Made()

        made.show(Self.yourTurn)
        for group in [made.backAndForward, made.upAndDown] {
            let group = try #require(group)
            let action = try #require(group.action)

            group.selectedIndex = -1
            NSApplication.shared.sendAction(action, to: group.target, from: group)
        }
        #expect(made.pressed.isEmpty)
    }

    /// ⌘[ and ⌘], the Go menu's, each only as the toolbar's side is enabled; any other item stays enabled.
    @Test func theGoMenusBackAndForwardFollowTheToolbar() {
        let made = Made()
        let item = { (action: Selector) in NSMenuItem(title: "", action: action, keyEquivalent: "") }
        let back = item(#selector(SitRepWindow.goBack(_:)))
        let forward = item(#selector(SitRepWindow.goForward(_:)))

        #expect(!made.bar.validate(back) && !made.bar.validate(forward))
        made.show(Self.yourTurn)
        #expect(made.bar.validate(back) && !made.bar.validate(forward))
        made.show(Self.fullPage)
        #expect(!made.bar.validate(back) && made.bar.validate(forward))
        #expect(made.bar.validate(item(#selector(NSWindow.performClose(_:)))))
    }

    // MARK: Through the model

    /// The model tells the toolbar with each change as it takes it: a project opened has Back and Forward alone, with a
    /// step back, and its name for the window's, at once.
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
        #expect(made.window.title == "Switchboard")
        #expect(made.bar.shown?.canGoBack == true)
    }

    /// The filter narrowing Needs you to Switchboard's two lines moves the position and what down can reach; cleared,
    /// the whole list's.
    @Test func aFilterMovesThePositionAndDown() throws {
        let model = try WindowModel.made()
        let made = Made()

        model.showToolbar = { made.show($0) }
        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened()
        #expect(made.position?.stringValue == "1 / 6")
        model.actions.filter("dash")
        #expect(made.position?.stringValue == "1 / 2")
        model.actions.step(true)
        #expect(made.position?.stringValue == "2 / 2")
        #expect(Self.enabled(made.upAndDown) == [true, false])
        model.actions.filter("")
        #expect(made.position?.stringValue == "3 / 6")
        #expect(Self.enabled(made.upAndDown) == [true, true])
    }

    /// Your turn's one row, its turn long over by the wall clock, under "1 earlier": down reaches it only as the fold
    /// opens, and picked it stands "1 / 1".
    @Test func aFoldOpeningGivesDownARowToGoTo() throws {
        let model = try WindowModel.made()
        let made = Made()

        model.showToolbar = { made.show($0) }
        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened()
        model.actions.click(.place(.yourTurn))
        #expect(Self.enabled(made.upAndDown) == [false, false])
        model.actions.toggleFold(.yourTurn)
        #expect(Self.enabled(made.upAndDown) == [false, true])
        model.actions.step(true)
        #expect(made.position?.stringValue == "1 / 1")
    }
}
