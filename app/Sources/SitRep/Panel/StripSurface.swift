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

/// The strip's window content, drawn in the material chosen.
@MainActor
final class StripSurface: PanelSurface<any StripDrawing> {
    private var placed: (menu: Double, height: Double) = (0, 0)
    private var last: (frame: StripFrame, hoverRow: String?)?

    init() {
        super.init(make: Self.drawing, view: { $0 })
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
