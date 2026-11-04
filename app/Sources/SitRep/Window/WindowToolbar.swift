import AppKit
import SitRepWindow

/// The SitRep window's toolbar, made of macOS's own parts, which macOS 26 draws on Liquid Glass by itself (see "The
/// frame is macOS's own"). On a place: past the sidebar, Back and Forward; beside them the place's name, as the
/// window's title, which macOS draws there; the list's divider tracked, so the title keeps over the list; then trailing
/// over the page, where the pick stands in the list, "1 / 5", and up and down. A page filling the window has Back and
/// Forward alone, at its leading edge, its title the window's name but not shown. Nothing to customise, so a
/// right-click on it offers no Customize Toolbar. It keeps only what it shows: each item is made afresh, with a view of
/// its own, as the toolbar inserts it, from that.
@MainActor
final class WindowToolbar: NSObject, NSToolbarDelegate {
    let toolbar = NSToolbar(identifier: "SitRepWindow")
    /// The toolbar as last shown; none before the window first shows it.
    private(set) var shown: Toolbar?
    private let splitView: NSSplitView
    private let actions: WindowActions

    /// Over the window's split, whose divider between the list and the page it tracks; its presses to the actions.
    init(splitView: NSSplitView, actions: WindowActions) {
        self.splitView = splitView
        self.actions = actions
        super.init()
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
    }

    /// The toolbar as the window stands, its items changing as a page comes to fill the window or a place shows, and
    /// the window's title with it, shown only on a place. Told on every change the window takes, the clock's too, it
    /// does nothing while what it shows is unchanged.
    func show(_ bar: Toolbar, in window: NSWindow) {
        guard bar != shown else {
            return
        }

        shown = bar
        arrange(bar.showsTitle ? Self.place : Self.fullPage)
        toolbar.items.forEach(update)
        window.title = bar.title
        window.titleVisibility = bar.showsTitle ? .visible : .hidden
    }

    /// The items as given, those already in place left there, so a capsule pressed is never made again under the
    /// pointer.
    private func arrange(_ identifiers: [NSToolbarItem.Identifier]) {
        let current = toolbar.items.map(\.itemIdentifier)
        let kept = zip(current, identifiers).prefix { $0 == $1 }.count

        for index in (kept ..< current.count).reversed() {
            toolbar.removeItem(at: index)
        }
        for index in kept ..< identifiers.count {
            toolbar.insertItem(withItemIdentifier: identifiers[index], at: index)
        }
    }

    /// An item, made or already in place, as the toolbar shows it now.
    private func update(_ item: NSToolbarItem) {
        let bar = shown ?? Toolbar()
        let listing = bar.listing ?? Toolbar.Listing()

        switch item.itemIdentifier {
        case Self.backAndForwardItem:
            (item as? NSToolbarItemGroup)?.enable([bar.canGoBack, bar.canGoForward])
        case Self.upAndDownItem:
            (item as? NSToolbarItemGroup)?.enable([listing.canStepUp, listing.canStepDown])
        case Self.positionItem:
            (item.view as? PositionLabel).map { Self.show(listing.position, in: $0) }
        default:
            break
        }
    }

    /// "3 / 5", which VoiceOver reads "3 of 5"; with nothing shown picked, no words and nothing for VoiceOver.
    private static func show(_ position: PlaceList.Position?, in label: PositionLabel) {
        label.stringValue = position?.text ?? ""
        label.spoken = position?.spoken
        label.setAccessibilityElement(position != nil)
    }

    /// The Go menu's Back and Forward, ⌘[ and ⌘], each enabled only as the toolbar's side is; anything else enabled.
    func validate(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(SitRepWindow.goBack(_:)): shown?.canGoBack ?? false
        case #selector(SitRepWindow.goForward(_:)): shown?.canGoForward ?? false
        default: true
        }
    }

    @objc private func goBackOrForward(_ sender: Any?) {
        switch NSToolbarItemGroup.side(of: sender) {
        case 0: actions.back()
        case 1: actions.forward()
        default: break
        }
    }

    @objc private func stepUpOrDown(_ sender: Any?) {
        switch NSToolbarItemGroup.side(of: sender) {
        case 0: actions.step(false)
        case 1: actions.step(true)
        default: break
        }
    }

    // MARK: The items

    static let backAndForwardItem = NSToolbarItem.Identifier("SitRepBackAndForward")
    static let listSeparator = NSToolbarItem.Identifier("SitRepListSeparator")
    static let positionItem = NSToolbarItem.Identifier("SitRepPosition")
    static let upAndDownItem = NSToolbarItem.Identifier("SitRepUpAndDown")

    static let place: [NSToolbarItem.Identifier] = [
        .sidebarTrackingSeparator, backAndForwardItem, listSeparator, .flexibleSpace, positionItem, upAndDownItem,
    ]
    static let fullPage: [NSToolbarItem.Identifier] = [.sidebarTrackingSeparator, backAndForwardItem]

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.place
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.place
    }

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = made(identifier)

        item.map(update)
        return item
    }

    private func made(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        switch identifier {
        case Self.backAndForwardItem:
            let item = NSToolbarItemGroup.steps(
                identifier, [("chevron.left", "Back"), ("chevron.right", "Forward")], label: "Back/Forward",
                target: self, action: #selector(goBackOrForward(_:))
            )

            item.isNavigational = true
            return item
        case Self.listSeparator:
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: splitView, dividerIndex: 1)
        case Self.positionItem:
            return Self.position(identifier)
        case Self.upAndDownItem:
            return NSToolbarItemGroup.steps(
                identifier, [("chevron.up", "Previous"), ("chevron.down", "Next")], label: "Previous/Next",
                target: self, action: #selector(stepUpOrDown(_:))
            )
        default:
            return nil
        }
    }

    /// Where the pick stands, 13 in tabular figures in the secondary colour.
    private static func position(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let label = PositionLabel(labelWithString: "")

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabelColor
        item.view = label
        item.label = "Position"
        item.autovalidates = false
        return item
    }
}

/// The position's words, "3 / 5", which VoiceOver reads once, as its value, in words, "3 of 5". A text field gives
/// VoiceOver its text for its value whatever is set on it, so the value is its own.
private final class PositionLabel: NSTextField {
    var spoken: String?

    override func accessibilityValue() -> String? {
        spoken
    }
}
