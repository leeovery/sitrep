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

    @Test func aSegmentedControlFillsItsWidthInEqualSegments() throws {
        let control = try Self.hosted(
            Segments(label: "Edge", values: ["Left", "Right"], title: \.self, selection: .constant("Right")).frame(width: 200),
            NSSegmentedControl.self
        )

        #expect(control.frame.width == 200)
        #expect(control.segmentDistribution == .fillEqually)
        #expect(control.selectedSegment == 1)
        #expect(control.accessibilityLabel() == "Edge")
    }

    @Test func aSegmentedControlTakesItsSegmentsAgainAsTheyChange() throws {
        let segments = { (values: [String]) in
            Segments(label: "Edge", values: values, title: \.self, selection: .constant("Right")).frame(width: 200)
        }
        let hosting = NSHostingView(rootView: segments(["Left", "Right"]))

        hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
        hosting.layoutSubtreeIfNeeded()
        hosting.rootView = segments(["Left", "Middle", "Right"])
        hosting.layoutSubtreeIfNeeded()
        let control = try #require(Self.find(NSSegmentedControl.self, in: hosting))

        #expect((0..<control.segmentCount).map { control.label(forSegment: $0) } == ["Left", "Middle", "Right"])
        #expect(control.selectedSegment == 2)
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

    /// A stock pop-up holding these items, as AppKit sizes one.
    static func stock(_ items: [NSMenuItem]) -> NSPopUpButton {
        let stock = NSPopUpButton(frame: .zero, pullsDown: false)

        for item in items {
            stock.menu?.addItem(item.isSeparatorItem ? .separator() : NSMenuItem(title: item.title, action: nil, keyEquivalent: ""))
        }
        return stock
    }

    /// The system's own width for its items, its widest choice's, whichever is chosen.
    @Test func aPopUpIsTheSystemsOwnWidthForItsItems() throws {
        let main = try Self.popUp(choosing: "Main display")
        let wide = try Self.popUp(choosing: "Built-in Retina Display")

        #expect(main.frame.size == Self.stock(main.itemArray).intrinsicContentSize)
        #expect(main.frame.height == 24)
        #expect(wide.frame.size == main.frame.size)
    }
}
