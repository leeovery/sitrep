import AppKit
import Testing

extension NSMenu {
    /// Its item at the index chosen, as AppKit sends the item's action, through the app, made here if no other test
    /// has: `performActionForItem(at:)` sends through `NSApp`, so sends nothing in a test run that has none yet.
    @MainActor
    func choose(_ index: Int, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let item = items[index]

        try #require(item.isEnabled, sourceLocation: sourceLocation)
        NSApplication.shared.sendAction(try #require(
            item.action, sourceLocation: sourceLocation
        ), to: item.target, from: item)
    }
}
