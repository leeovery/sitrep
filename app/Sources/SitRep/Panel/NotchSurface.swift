import AppKit
import SitRepPanel

/// One way of drawing the notch a frame at a time: in black, or in glass.
@MainActor
protocol NotchDrawing: NSView {
    /// The shape and the content as the frame has them, the row under the pointer lit.
    func show(_ frame: Frame, hover: Int?)
    /// The light as the frame places it, in these colours, round the lip's outline.
    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight)
}

/// The notch's window content, drawn in the material chosen.
@MainActor
final class NotchSurface: PanelSurface<any NotchDrawing> {
    private var last: (frame: Frame, hover: Int?)?
    private var lastLight: (placed: Frame.Light, outline: CGPath, colours: LiveLight)?

    init(items: [Item], content: Content) {
        super.init(make: { Self.drawing($0, items: items, content: content) }, view: { $0 })
    }

    func show(_ frame: Frame, hover: Int?) {
        last = (frame, hover)
        drawing.show(frame, hover: hover)
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        lastLight = (placed, outline, colours)
        drawing.showLight(placed, outline: outline, colours: colours)
    }

    override func replay() {
        if let last {
            drawing.show(last.frame, hover: last.hover)
        }
        if let lastLight {
            drawing.showLight(lastLight.placed, outline: lastLight.outline, colours: lastLight.colours)
        }
    }

    private static func drawing(_ material: PanelMaterial, items: [Item], content: Content) -> any NotchDrawing {
        if #available(macOS 26, *), material == .glass {
            return NotchGlassView(items: items, content: content)
        }
        return PanelView(items: items, content: content)
    }
}
