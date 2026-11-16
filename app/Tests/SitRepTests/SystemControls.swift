import AppKit

extension NSPopUpButton {
    /// A stock pop-up holding these items, as AppKit sizes one: what SitRep's pop-ups are measured against.
    static func stock(holding items: [NSMenuItem]) -> NSPopUpButton {
        let stock = NSPopUpButton(frame: .zero, pullsDown: false)

        for item in items {
            stock.menu?.addItem(
                item.isSeparatorItem ? .separator() : NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            )
        }
        return stock
    }
}
