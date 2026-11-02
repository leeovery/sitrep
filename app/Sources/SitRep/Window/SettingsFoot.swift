import AppKit
import SwiftUI

/// Settings at the sidebar's foot, fixed under the list (spec 2.5): a rule, 8 of space, its row of 32, and 10 to the
/// glass's bottom, every part of it SitRep's own. It opens the Settings window, and is never picked: under the pointer
/// its row shows a session row's quiet fill, shaped as the list's selection. Its row is a stop of its own in the
/// window's key loop (`SettingsFootControl`). Drawn as a still, it lays out as it does on screen.
struct SettingsFooter: View {
    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            SidebarRule()
            row.padding(.top, WindowStyle.footerTop).padding(.bottom, WindowStyle.footerBottom)
        }
    }

    @ViewBuilder private var row: some View {
        let drawn = SettingsFootRow(fill: fill)

        if isStill {
            drawn
        } else {
            drawn.allowsHitTesting(false).background {
                FootControl(press: act.openSettings, hovered: { isHovered = $0 })
            }
        }
    }

    /// A sidebar row's quiet fill under the pointer.
    private var fill: Color? {
        WindowStyle.sidebarFill(
            Highlight.of(isPicked: false, isPressed: false, isHovered: isHovered || isHoveredStill), isStill: isStill
        )
    }
}

/// Settings' row as drawn: the gear, in the accent, and its word, on `fill`, shaped as the selection.
private struct SettingsFootRow: View {
    let fill: Color?

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(Color.accentColor)
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
        .accessibilityHidden(true)
    }
}

/// The row's control, behind what it draws.
private struct FootControl: NSViewRepresentable {
    let press: () -> Void
    let hovered: (Bool) -> Void

    func makeNSView(context: Context) -> SettingsFootControl {
        let control = SettingsFootControl()

        updateNSView(control, context: context)
        return control
    }

    func updateNSView(_ control: SettingsFootControl, context: Context) {
        control.press = press
        control.hovered = hovered
    }
}

/// Settings' row at the foot as AppKit knows it: a stop in the window's key loop after the board's list, as a list is,
/// whether or not the Mac's Keyboard navigation is on, showing focus by the system's focus ring in a row's shape. A
/// click, Space or Return opens the Settings window; the arrows go nowhere from it, as from either end of the board's
/// list. VoiceOver reads it as a button, "Settings".
///
/// What it tells SwiftUI of the pointer it tells after AppKit's change, never inside one of SwiftUI's updates, which can
/// take the control out of its window.
final class SettingsFootControl: NSView {
    var press: () -> Void = {}
    var hovered: (Bool) -> Void = { _ in }

    /// Its word, drawn and read.
    static let words = "Settings"

    override init(frame: NSRect) {
        super.init(frame: frame)
        focusRingType = .default
        // Once: `inVisibleRect` follows its bounds, and an area added again with the pointer inside hears no entry.
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    /// A click in a window not key opens Settings there and then, as it picks a row of the board's list.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// A click opens Settings; a Control-click is the Mac's right-click, which opens nothing.
    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else {
            return super.rightMouseDown(with: event)
        }
        press()
    }

    /// Its own keys: Space, Return and Enter press it, bare, and do nothing with a modifier held, as Return with one
    /// does on the board's list; the arrows go nowhere. Any other as AppKit binds it.
    override func keyDown(with event: NSEvent) {
        guard Self.presses.contains(event.keyCode) || Self.arrows.contains(event.keyCode) else {
            return interpretKeyEvents([event])
        }
        if Self.presses.contains(event.keyCode), event.modifierFlags.isDisjoint(with: Self.modifiers) {
            press()
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

    override func mouseEntered(with event: NSEvent) {
        tellHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        tellHover(false)
    }

    /// Out of its window, or its window out of sight, closed, minimised or ordered out, which sends no exit: the
    /// pointer is over it no longer.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        guard let window else {
            return tellHover(false)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowChangedOcclusion), name: NSWindow.didChangeOcclusionStateNotification,
            object: window
        )
    }

    @objc private func windowChangedOcclusion(_ notification: Notification) {
        if window?.occlusionState.contains(.visible) != true {
            tellHover(false)
        }
    }

    override var focusRingMaskBounds: NSRect {
        rowShape.bounds
    }

    override func drawFocusRingMask() {
        rowShape.fill()
    }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        noteFocusRingMaskChanged()
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { Self.words }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    private func tellHover(_ isOver: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hovered(isOver)
        }
    }

    /// A row's shape, the selection's, in from the sidebar's edges, its corners continuous as the fill's.
    private var rowShape: NSBezierPath {
        let shape = RoundedRectangle(cornerRadius: WindowStyle.rowRadius, style: .continuous)

        return NSBezierPath(cgPath: shape.path(in: bounds.insetBy(dx: WindowStyle.selectionInset, dy: 0)).cgPath)
    }

    private static let presses: Set<UInt16> = [space, SideFocus.return, SideFocus.enter]
    private static let arrows: Set<UInt16> = [leftArrow, rightArrow, downArrow, upArrow]
    private static let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    private static let space: UInt16 = 49
    private static let leftArrow: UInt16 = 123
    private static let rightArrow: UInt16 = 124
    private static let downArrow: UInt16 = 125
    private static let upArrow: UInt16 = 126
}
