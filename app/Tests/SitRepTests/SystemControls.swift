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

extension NSSegmentedControl {
    /// A stock segmented control of these labels, its segments equal, as AppKit sizes one: what SitRep's are measured
    /// against.
    static func stock(labels: [String]) -> NSSegmentedControl {
        let stock = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)

        stock.segmentDistribution = .fillEqually
        return stock
    }

    /// Its segments' labels, left to right.
    var labels: [String] {
        (0 ..< segmentCount).map { label(forSegment: $0) ?? "" }
    }
}
