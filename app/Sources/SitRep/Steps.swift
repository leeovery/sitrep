import AppKit

extension NSToolbarItemGroup {
    /// A pair of the system's steps for a toolbar, as back and forward are in Finder's and Safari's: AppKit's own
    /// segmented pair of two chevrons, each its own button, VoiceOver reading each by its name, which is its tooltip
    /// too, and each a menu item of its own where the toolbar spills into ». A press sends the action with the group,
    /// its `selectedIndex` the side pressed (`side(of:)`). Each side is enabled only as the window says.
    static func steps(
        _ identifier: NSToolbarItem.Identifier, _ sides: [(symbol: String, name: String)], label: String,
        target: AnyObject?, action: Selector
    ) -> NSToolbarItemGroup {
        let images = sides.map { symbol, name in
            NSImage(systemSymbolName: symbol, accessibilityDescription: name) ?? NSImage()
        }
        let group = NSToolbarItemGroup(
            itemIdentifier: identifier, images: images, selectionMode: .momentary, labels: sides.map(\.name),
            target: target, action: action
        )

        group.label = label
        for (side, step) in zip(group.subitems, sides) {
            side.toolTip = step.name
            side.autovalidates = false
        }
        return group
    }

    /// The side a press of the group pressed, 0 or 1; none where it came with no side selected, as a press from
    /// VoiceOver or the keyboard on a momentary control can.
    static func side(of sender: Any?) -> Int? {
        guard let group = sender as? NSToolbarItemGroup, group.subitems.indices.contains(group.selectedIndex) else {
            return nil
        }
        return group.selectedIndex
    }

    /// Each side enabled as given, in order.
    func enable(_ sides: [Bool]) {
        for (side, isEnabled) in zip(subitems, sides) {
            side.isEnabled = isEnabled
        }
    }
}
