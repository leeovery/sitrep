import AppKit
import SitRepPanel

/// One way of drawing the strip a frame at a time: in black, or in glass.
@MainActor
protocol StripDrawing: NSView {
    /// The window starts under the menu bar: the stage moves up by it.
    func place(menu: Double, height: Double)
    /// The strip as the frame has it, the count's row under the pointer lit.
    func show(_ frame: StripFrame, hoverRow: String?)
}

/// The strip's window content, drawn in the material chosen. A click on the strip is its prototype's: a press, which
/// moved along the edge drags the strip, and a click when it lets go; and the wheel scrolls a count's rows.
@MainActor
final class StripSurface: PanelSurface<any StripDrawing> {
    /// A press, its letting go, and the wheel turning by points, in screen coordinates.
    var onPress: (CGPoint) -> Void = { _ in }
    var onRelease: (CGPoint) -> Void = { _ in }
    var onScroll: (CGPoint, Double) -> Void = { _, _ in }

    private var placed: (menu: Double, height: Double) = (0, 0)
    private var last: (frame: StripFrame, hoverRow: String?)?

    init() {
        super.init(make: Self.drawing, view: { $0 })
    }

    override func mouseDown(with event: NSEvent) {
        screenPoint(event).map(onPress)
    }

    override func mouseUp(with event: NSEvent) {
        screenPoint(event).map(onRelease)
    }

    /// The rows move with the fingers, as a scroll view's do; a mouse's wheel turns them a line, 10 points, a notch.
    override func scrollWheel(with event: NSEvent) {
        let points = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : 10 * event.scrollingDeltaY
        if let point = screenPoint(event) {
            onScroll(point, -points)
        }
    }

    private func screenPoint(_ event: NSEvent) -> CGPoint? {
        window?.convertPoint(toScreen: event.locationInWindow)
    }

    func place(menu: Double, height: Double) {
        placed = (menu, height)
        drawing.place(menu: menu, height: height)
    }

    func show(_ frame: StripFrame, hoverRow: String?) {
        last = (frame, hoverRow)
        drawing.show(frame, hoverRow: hoverRow)
    }

    override func replay() {
        drawing.place(menu: placed.menu, height: placed.height)
        if let last {
            drawing.show(last.frame, hoverRow: last.hoverRow)
        }
    }

    private static func drawing(_ material: PanelMaterial) -> any StripDrawing {
        if #available(macOS 26, *), material == .glass {
            return StripGlassView()
        }
        return StripView()
    }
}
