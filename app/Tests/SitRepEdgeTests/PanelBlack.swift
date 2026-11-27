import CoreGraphics
import SitRepPanel
import Testing

/// Points by the screen's edge at the ends of the panel's black as a frame draws it (`Frame.shape`): in the Meniscus,
/// its flares reach further along the edge than its rows' clip.
enum PanelBlack {
    /// How far from the screen's edge the points stand.
    static let depth = 3.0

    /// A point by the screen's edge this far inside the black's top or bottom end, or, at a negative `inset`, that far
    /// outside it.
    static func end(top: Bool, of frame: Frame, inset: Double) throws -> CGPoint {
        let box = frame.shape.boundingBoxOfPath
        let ys = Array(stride(from: box.minY, through: box.maxY, by: 0.25))
        let edge = try #require((top ? ys : ys.reversed()).first { frame.shape.contains(CGPoint(x: depth, y: $0)) })

        return CGPoint(x: depth, y: edge + (top ? inset : -inset))
    }
}
