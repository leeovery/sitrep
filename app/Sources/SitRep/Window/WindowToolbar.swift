import AppKit
import SitRepWindow

/// The SitRep window's toolbar, made of macOS's own parts, which macOS 26 draws on Liquid Glass by itself (see "The
/// frame is macOS's own"). On a place: past the sidebar, Back and Forward; beside them the place's name, as the
/// window's title, which macOS draws there; the list's divider tracked, so the title keeps over the list; then trailing
/// over the page, where the pick stands in the list, "1 / 5", and up and down. A page filling the window has Back and
/// Forward alone, at its leading edge. Nothing to customise, so a right-click on it offers no Customize Toolbar.
@MainActor
final class WindowToolbar: NSObject, NSToolbarDelegate {
    let toolbar = NSToolbar(identifier: "SitRepWindow")
    /// Back and forward, in one capsule.
    let backAndForward = NSSegmentedControl.steps([("chevron.left", "Back"), ("chevron.right", "Forward")])
    /// Where the pick stands in the list, empty while it shows nothing picked.
    let position = NSTextField(labelWithString: "")
    /// Up and down, in one capsule: the row before the pick and the row after it, as ↑ and ↓.
    let upAndDown = NSSegmentedControl.steps([("chevron.up", "Previous"), ("chevron.down", "Next")])
    /// The toolbar as last shown.
    private(set) var shown = Toolbar()
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
        backAndForward.target = self
        backAndForward.action = #selector(goBackOrForward(_:))
        upAndDown.target = self
        upAndDown.action = #selector(stepUpOrDown(_:))
        position.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        position.textColor = .secondaryLabelColor
        showSteps(shown)
    }

    /// The toolbar as the window stands, its items changing as a page comes to fill the window or a place shows, and
    /// the window's title with it, shown only on a place.
    func show(_ bar: Toolbar, in window: NSWindow) {
        shown = bar
        arrange(bar.listing == nil ? Self.fullPage : Self.place)
        showSteps(bar)
        position.stringValue = bar.listing?.position?.text ?? ""
        position.setAccessibilityLabel(bar.listing?.position?.spoken)
        window.title = bar.listing?.title ?? "SitRep"
        window.titleVisibility = bar.listing == nil ? .hidden : .visible
    }

    private func showSteps(_ bar: Toolbar) {
        backAndForward.setEnabled(bar.canGoBack, forSegment: Self.first)
        backAndForward.setEnabled(bar.canGoForward, forSegment: Self.second)
        upAndDown.setEnabled(bar.listing?.canStepUp ?? false, forSegment: Self.first)
        upAndDown.setEnabled(bar.listing?.canStepDown ?? false, forSegment: Self.second)
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

    @objc private func goBackOrForward(_ control: NSSegmentedControl) {
        if control.selectedSegment == Self.first {
            actions.back()
        } else {
            actions.forward()
        }
    }

    @objc private func stepUpOrDown(_ control: NSSegmentedControl) {
        actions.step(control.selectedSegment == Self.second)
    }

    // MARK: The items

    static let backAndForwardItem = NSToolbarItem.Identifier("SitRepBackAndForward")
    static let listSeparator = NSToolbarItem.Identifier("SitRepListSeparator")
    static let positionItem = NSToolbarItem.Identifier("SitRepPosition")
    static let upAndDownItem = NSToolbarItem.Identifier("SitRepUpAndDown")
    private static let first = 0
    private static let second = 1

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
        switch identifier {
        case Self.backAndForwardItem:
            let item = Self.item(identifier, view: backAndForward, label: "Back/Forward")

            item.isNavigational = true
            return item
        case Self.listSeparator:
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: splitView, dividerIndex: 1)
        case Self.positionItem:
            return Self.item(identifier, view: position, label: "Position")
        case Self.upAndDownItem:
            return Self.item(identifier, view: upAndDown, label: "Previous/Next")
        default:
            return nil
        }
    }

    /// An item over its control, enabled as the toolbar says, never by AppKit's validation.
    private static func item(_ identifier: NSToolbarItem.Identifier, view: NSView, label: String) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)

        item.view = view
        item.label = label
        item.autovalidates = false
        return item
    }
}
