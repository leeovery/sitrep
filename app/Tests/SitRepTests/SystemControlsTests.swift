import AppKit
@testable import SitRep
import SwiftUI
import Testing

/// The system's own controls, as SitRep hosts them.
@MainActor
struct SystemControlsTests {
    private static func hosted<Control: NSView>(_ view: some View, _ kind: Control.Type) throws -> Control {
        let hosting = NSHostingView(rootView: view)

        hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
        hosting.layoutSubtreeIfNeeded()
        return try #require(Self.find(kind, in: hosting))
    }

    private static func find<Control: NSView>(_ kind: Control.Type, in view: NSView) -> Control? {
        view.subviews.lazy.compactMap { $0 as? Control ?? find(kind, in: $0) }.first
    }

    private static func popUp(choosing chosen: String) throws -> NSPopUpButton {
        try Self.hosted(
            PopUp(
                label: "Display", sections: [["Main display"], ["Built-in Retina Display", "LG"]], title: \.self,
                selection: .constant(chosen)
            ),
            NSPopUpButton.self
        )
    }

    @Test func aPopUpSplitsItsSectionsBySeparators() throws {
        let button = try Self.popUp(choosing: "LG")

        #expect(button.itemArray.map { $0.isSeparatorItem ? "—" : $0.title } == ["Main display", "—", "Built-in Retina Display", "LG"])
        #expect(button.titleOfSelectedItem == "LG")
    }

    /// The system's own width for its items, its widest choice's, whichever is chosen.
    @Test func aPopUpIsTheSystemsOwnWidthForItsItems() throws {
        let main = try Self.popUp(choosing: "Main display")
        let wide = try Self.popUp(choosing: "Built-in Retina Display")

        #expect(main.frame.size == NSPopUpButton.stock(holding: main.itemArray).intrinsicContentSize)
        #expect(main.frame.height == 24)
        #expect(wide.frame.size == main.frame.size)
    }
}
