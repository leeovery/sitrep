import AppKit
import SitRepWindow
import SwiftUI

/// Settings at the sidebar's foot, fixed under the list (spec 2.5): a rule, 8 of space, its row of 32, and 10 to the
/// glass's bottom, every part of it SitRep's own. Picked, its row takes the selection, drawn as a heading's is; under
/// the pointer and not picked, a session row's quiet fill. Its row is a stop of its own in the window's key loop
/// (`SettingsFootControl`). Drawn as a still, it lays out as it does on screen.
struct SettingsFooter: View {
    let pick: Pick?

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @Environment(\.controlActiveState) private var activeState
    @State private var isFocused = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(WindowStyle.separator)
                .frame(height: WindowStyle.footerRule)
                .padding(.horizontal, WindowStyle.selectionInset)
            row.padding(.top, WindowStyle.footerTop).padding(.bottom, WindowStyle.footerBottom)
        }
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

    /// The selection while picked, which SitRep draws here as no list does; else a sidebar row's.
    private func fill(isPicked: Bool) -> Color? {
        if isPicked {
            return WindowStyle.selection(isEmphasized: isEmphasized, isStill: isStill)
        }
        return WindowStyle.sidebarFill(
            Highlight.of(isPicked: false, isPressed: false, isHovered: isHovered || isHoveredStill), isStill: isStill
        )
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
/// whether or not the Mac's Keyboard navigation is on. Picked, it shows focus as a list's row does, by its selection
/// in the accent, with no ring; not picked, by the system's focus ring in the selection's shape. A click, Space or
/// Return opens Settings; while it shows, Return is the sidebar's, into the page (`SideFocus`). The arrows go nowhere
/// from it, as from either end of the board's list. VoiceOver reads it as one of the sidebar's choices, a radio
/// button, selected while Settings shows, as a list's row reads selected.
///
/// What it tells SwiftUI of its focus and of the pointer it tells after AppKit's change, never inside one of SwiftUI's
/// updates, which can move focus or take the control out of its window.
final class SettingsFootControl: NSView {
    var isPicked = false {
        didSet {
            guard isPicked != oldValue else {
                return
            }
            focusRingType = isPicked ? .none : .default
            noteFocusRingMaskChanged()
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }
    var press: () -> Void = {}
    var focused: (Bool) -> Void = { _ in }
    var hovered: (Bool) -> Void = { _ in }

    /// Its word, drawn and read.
    static let words = "Settings"

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Once: `inVisibleRect` follows its bounds, and an area added again with the pointer inside hears no entry.
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let becomes = super.becomeFirstResponder()

        tellFocus()
        return becomes
    }

    override func resignFirstResponder() -> Bool {
        let resigns = super.resignFirstResponder()

        tellFocus()
        return resigns
    }

    /// A click in a window not key picks it there and then, as it does a row of the board's list.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// A click picks it and gives it focus; a Control-click is the Mac's right-click, which picks nothing.
    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else {
            return super.rightMouseDown(with: event)
        }
        window?.makeFirstResponder(self)
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
    override func accessibilityRole() -> NSAccessibility.Role? { .radioButton }
    override func accessibilityLabel() -> String? { Self.words }
    override func accessibilityValue() -> Any? { NSNumber(value: isPicked) }
    override func isAccessibilitySelected() -> Bool { isPicked }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    private func tellFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            focused(window?.firstResponder === self)
        }
    }

    private func tellHover(_ isOver: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hovered(isOver)
        }
    }

    /// The selection's shape, in from the sidebar's edges, its corners continuous as the fill's.
    private var selection: NSBezierPath {
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
