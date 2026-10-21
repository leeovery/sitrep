import AppKit
@testable import SitRep
import SwiftUI
import Testing

/// The system's own controls, as wide as Settings' column.
@MainActor
struct SystemControlsTests {
    private static func hosted<Control: NSView>(_ view: some View, _ kind: Control.Type) throws -> Control {
        let hosting = NSHostingView(rootView: view.frame(width: WindowStyle.controls))

        hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
        hosting.layoutSubtreeIfNeeded()
        return try #require(Self.find(kind, in: hosting))
    }

    private static func find<Control: NSView>(_ kind: Control.Type, in view: NSView) -> Control? {
        view.subviews.lazy.compactMap { $0 as? Control ?? find(kind, in: $0) }.first
    }

    @Test func aSegmentedControlFillsTheColumnInEqualSegments() throws {
        let control = try Self.hosted(
            Segments(label: "Edge", values: ["Left", "Right"], title: \.self, selection: .constant("Right")),
            NSSegmentedControl.self
        )

        #expect(control.frame.width == WindowStyle.controls)
        #expect(control.segmentDistribution == .fillEqually)
        #expect(control.selectedSegment == 1)
        #expect(control.accessibilityLabel() == "Edge")
    }

    @Test func aSegmentedControlTakesItsSegmentsAgainAsTheyChange() throws {
        let segments = { (values: [String]) in
            Segments(label: "Edge", values: values, title: \.self, selection: .constant("Right"))
                .frame(width: WindowStyle.controls)
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

    @Test func aPopUpFillsTheColumnItsSectionsSplitBySeparators() throws {
        let button = try Self.hosted(
            PopUp(
                label: "Display", sections: [["Main display"], ["Studio Display", "LG"]], title: \.self,
                selection: .constant("LG")
            ),
            NSPopUpButton.self
        )

        #expect(button.frame.width == WindowStyle.controls)
        #expect(button.itemArray.map { $0.isSeparatorItem ? "—" : $0.title } == ["Main display", "—", "Studio Display", "LG"])
        #expect(button.titleOfSelectedItem == "LG")
    }
}
