import CoreGraphics
import SwiftUI

/// A path as a shape: it fills where it is, whatever the frame.
struct Outline: Shape {
    let path: Path

    func path(in _: CGRect) -> Path { path }
}

/// How thick Liquid Glass looks, which it takes from its shape's size alone: a shape whose bounds are under about 64pt
/// at their narrower is thin glass, one past about 72pt thick, with nothing between, and a shape rebuilt each frame
/// crossing from one to the other changes at once, in an animation or not (both measured on macOS 26).
enum GlassThickness {
    /// The path as thick glass whatever its own size: with a point of it far off the top of the view, outside its
    /// frame and its window, so its bounds are as wide as the view and over 100pt tall.
    static func thick(_ path: CGPath, width: Double) -> Path {
        let made = CGMutablePath()
        made.addPath(path)
        made.addRect(CGRect(x: width - 1, y: -100, width: 1, height: 1))
        return Path(made)
    }
}
