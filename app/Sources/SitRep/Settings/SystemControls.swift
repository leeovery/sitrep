import AppKit
import SwiftUI

/// The system's segmented control, as wide as it is given, its segments equal, as the sidebar's switch spans the
/// sidebar: SwiftUI's segmented picker keeps to its words' widths.
struct Segments<Value: Hashable>: NSViewRepresentable {
    let label: String
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: [], trackingMode: .selectOne, target: context.coordinator, action: #selector(Coordinator.chose(_:))
        )

        control.segmentDistribution = .fillEqually
        control.setAccessibilityLabel(label)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        let labels = values.map(title)
        let selection = $selection

        control.segmentCount = labels.count
        for (segment, label) in labels.enumerated() where control.label(forSegment: segment) != label {
            control.setLabel(label, forSegment: segment)
        }
        context.coordinator.choose = { [values] in selection.wrappedValue = values[$0] }
        control.selectedSegment = values.firstIndex(of: self.selection) ?? -1
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView control: NSSegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? control.intrinsicContentSize.width, height: control.intrinsicContentSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var choose: (Int) -> Void = { _ in }

        @objc func chose(_ control: NSSegmentedControl) {
            choose(control.selectedSegment)
        }
    }
}

/// The system's pop-up button, its choices in sections, a separator between each two. It is as wide as its chosen
/// title makes it, whatever its other choices, as a grouped form sets its pop-up (123 for Main display, measured on
/// macOS 26), where AppKit's and SwiftUI's menu picker take their widest choice's width.
struct PopUp<Value: Hashable>: NSViewRepresentable {
    let label: String
    let sections: [[Value]]
    let title: (Value) -> String
    @Binding var selection: Value

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)

        button.target = context.coordinator
        button.action = #selector(Coordinator.chose(_:))
        button.setAccessibilityLabel(label)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let values = sections.flatMap(\.self)
        let titles = sections.map { $0.map(title) }
        let selection = $selection

        if context.coordinator.titles != titles {
            context.coordinator.titles = titles
            fill(button.menu, with: titles)
        }
        context.coordinator.choose = { selection.wrappedValue = values[$0] }
        button.selectItem(withTag: values.firstIndex(of: self.selection) ?? -1)
    }

    /// The menu's items, each tagged with its place among every choice.
    private func fill(_ menu: NSMenu?, with titles: [[String]]) {
        var place = 0

        menu?.removeAllItems()
        for (offset, section) in titles.enumerated() {
            if offset > 0 {
                menu?.addItem(.separator())
            }
            for title in section {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

                item.tag = place
                place += 1
                menu?.addItem(item)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: NSPopUpButton, context: Context) -> CGSize? {
        let chosen = NSPopUpButtonCell(textCell: title(selection), pullsDown: false)

        chosen.font = button.font
        chosen.controlSize = button.controlSize
        return chosen.cellSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var titles: [[String]] = []
        var choose: (Int) -> Void = { _ in }

        @objc func chose(_ button: NSPopUpButton) {
            choose(button.selectedTag())
        }
    }
}
