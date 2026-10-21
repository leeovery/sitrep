import AppKit
import SitRepWindow
import SwiftUI

/// Settings at the sidebar's foot, fixed under a rule as the list runs on under it (spec 2.5): the rule, 8 of space,
/// its row of 32, and 10 to the glass's bottom, every part of it SitRep's own. Live, a foot that was a list of its one
/// row, in the list's bar, rose by what a window on screen gives the sidebar, which no window offscreen reproduced.
/// Picked, its row takes the selection, drawn as a heading's is; under the pointer and not picked, a session row's
/// quiet fill. Its row is a stop of its own in the window's key loop (`SettingsFootControl`). Drawn as a still, it
/// lays out as it does on screen.
struct SettingsFooter: View {
    let pick: Pick?

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @Environment(\.controlActiveState) private var activeState
    @State private var isFocused = false
    @State private var isHovered = false

    /// Its rule, and its row with the space above and below it.
    static let height = WindowStyle.footerRule + WindowStyle.footerTop + WindowStyle.footerRow + WindowStyle.footerBottom

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(WindowStyle.separator)
                .frame(height: WindowStyle.footerRule)
                .padding(.horizontal, WindowStyle.selectionInset)
            row.padding(.top, WindowStyle.footerTop).padding(.bottom, WindowStyle.footerBottom)
        }
        // A click on the foot outside its row, on the rule or the space round it, lands on nothing of the list's
        // under it.
        .background(Color.clear.contentShape(Rectangle()))
    }

    @ViewBuilder private var row: some View {
        let isPicked = pick == .settings
        let drawn = SettingsFootRow(fill: fill(isPicked: isPicked), isEmphasized: isPicked && isEmphasized)

        if isStill {
            drawn
        } else {
            drawn.allowsHitTesting(false).background {
                FootControl(
                    isPicked: isPicked, press: open, focused: { isFocused = $0 }, hovered: { isHovered = $0 }
                )
            }
        }
    }

    private func fill(isPicked: Bool) -> Color? {
        switch Highlight.of(isPicked: isPicked, isPressed: false, isHovered: isHovered || isHoveredStill) {
        case .picked: WindowStyle.selection(isEmphasized: isEmphasized, isStill: isStill)
        case .hover: WindowStyle.sidebarHover
        case .none: nil
        }
    }

    /// Its row has the key window's focus, so a selection on it shows in the accent.
    private var isEmphasized: Bool {
        isFocused && activeState == .key
    }

    private func open() {
        if pick != .settings {
            act.pick(.settings)
        }
    }
}

/// Settings' row as drawn: the gear, in the accent, and its word, on `fill`, shaped as the selection; on the
/// emphasized selection, both white.
private struct SettingsFootRow: View {
    let fill: Color?
    let isEmphasized: Bool

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(WindowStyle.colour(Color.accentColor, on: prominence))
                .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Text(SettingsFootControl.words)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, WindowStyle.rowInset)
        .frame(height: WindowStyle.footerRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let fill {
                SelectionShaped(fill: fill, radius: WindowStyle.rowRadius)
            }
        }
        .environment(\.backgroundProminence, prominence)
        .accessibilityHidden(true)
    }

    private var prominence: BackgroundProminence {
        isEmphasized ? .increased : .standard
    }
}

/// The row's control, behind what it draws.
private struct FootControl: NSViewRepresentable {
    let isPicked: Bool
    let press: () -> Void
    let focused: (Bool) -> Void
    let hovered: (Bool) -> Void

    func makeNSView(context: Context) -> SettingsFootControl {
        let control = SettingsFootControl()

        updateNSView(control, context: context)
        return control
    }

    func updateNSView(_ control: SettingsFootControl, context: Context) {
        control.isPicked = isPicked
        control.press = press
        control.focused = focused
        control.hovered = hovered
    }
}

/// Settings' row at the foot as AppKit knows it: a stop in the window's key loop after the board's list, as a list is,
/// whether or not the Mac's Keyboard navigation is on, ringed by the system's focus ring in the selection's shape. A
/// click, Space or Return opens Settings; while it shows, Return is the sidebar's, into the page (`SideFocus`). The
/// arrows go nowhere from it, as from either end of the board's list. VoiceOver reads it as a button, selected while
/// Settings shows.
final class SettingsFootControl: NSView {
    var isPicked = false
    var press: () -> Void = {}
    var focused: (Bool) -> Void = { _ in }
    var hovered: (Bool) -> Void = { _ in }

    /// Its word, drawn and read.
    static let words = "Settings"

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        focused(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        focused(false)
        return true
    }

    /// A click in a window not key picks it there and then, as it does a row of the board's list.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        press()
    }

    /// Its own keys, bare: Space, Return and Enter press it, and the arrows go nowhere. Any other as AppKit binds it.
    override func keyDown(with event: NSEvent) {
        let isBare = event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift])

        if isBare, Self.presses.contains(event.keyCode) {
            press()
        } else if !isBare || !Self.arrows.contains(event.keyCode) {
            interpretKeyEvents([event])
        }
    }

    /// Tab and Shift-Tab, to the next stop in the window's key loop and back, as nothing above it in the responder
    /// chain takes them.
    override func insertTab(_ sender: Any?) {
        window?.selectNextKeyView(self)
    }

    override func insertBacktab(_ sender: Any?) {
        window?.selectPreviousKeyView(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        hovered(false)
    }

    override var focusRingMaskBounds: NSRect {
        selection.bounds
    }

    override func drawFocusRingMask() {
        selection.fill()
    }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        noteFocusRingMaskChanged()
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { Self.words }
    override func isAccessibilitySelected() -> Bool { isPicked }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    /// The selection's shape, in from the sidebar's edges.
    private var selection: NSBezierPath {
        NSBezierPath(
            roundedRect: bounds.insetBy(dx: WindowStyle.selectionInset, dy: 0), xRadius: WindowStyle.rowRadius,
            yRadius: WindowStyle.rowRadius
        )
    }

    /// Space, Return and Enter.
    private static let presses: Set<UInt16> = [49, SideFocus.return, SideFocus.enter]
    /// ←, →, ↓ and ↑.
    private static let arrows: Set<UInt16> = [123, 124, 125, 126]
}
