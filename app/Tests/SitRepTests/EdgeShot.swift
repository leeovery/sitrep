import AppKit
@testable import SitRep
import Testing

/// An edge's surface shot on the README's desktop (`app/screens`), at the screen's left edge: the wallpaper, the
/// display's black bezel beside the edge, and the surface's drawing over them as Core Animation's endless turns stand
/// at a moment, each shot a picture at 2×. Only the wallpaper and the bezel are not the app's.
@MainActor
final class EdgeShot {
    /// The display's black bezel shown beside the screen's edge, which the edge's black flares into.
    static let bezel = 6.0

    /// The shot's frame on the screen, the bezel at its left.
    private let cut: CGRect
    /// How far below the screen's top the surface's window starts.
    private let hung: Double
    private let backdrop: CGImage
    /// The surface's drawing, under a flipped root, as `Drawn` draws a layer.
    private let root = CALayer()

    /// The surface, shot over `cut` on the screen, its window starting `hung` below the screen's top.
    init(_ surface: NSView, cut: CGRect, hung: Double = 0) throws {
        let framed = CGRect(x: -Self.bezel, y: cut.minY, width: cut.maxX + Self.bezel, height: cut.height)

        self.cut = framed
        self.hung = hung
        backdrop = try Self.backdrop(framed)

        let drawing = try #require(surface.subviews.first?.layer)

        root.isGeometryFlipped = true
        root.frame = surface.bounds
        root.addSublayer(drawing)
    }

    /// The shot as the screen shows it: the desktop, the surface over it with each endless turn at the share of its
    /// period `turned` gives it and its glows lit, and what `over` draws over all, in the screen's points. The drawing's layers are drawn
    /// out of their view, under the flipped root, so the flip AppKit gave them for the view comes off first.
    func shoot(turned: (CABasicAnimation) -> Double, over: (CGContext) -> Void = { _ in }) throws -> Canvas {
        let canvas = try Canvas(cut.size), context = canvas.context
        let restores = [Running.set(root, turned: turned), Glows.set(root)]

        defer { restores.forEach { $0() } }
        canvas.draw(backdrop, in: CGRect(origin: .zero, size: cut.size))
        root.sublayers?.forEach { $0.isGeometryFlipped = false }
        Self.display(root)
        context.saveGState()
        context.translateBy(x: -cut.minX, y: -cut.minY)
        context.saveGState()
        context.translateBy(x: 0, y: hung)
        root.render(in: context)
        context.restoreGState()
        over(context)
        context.restoreGState()
        return canvas
    }

    /// Every layer drawn at 2×, its content drawn again where it asks to be.
    private static func display(_ layer: CALayer) {
        layer.contentsScale = Canvas.scale
        layer.displayIfNeeded()
        layer.sublayers?.forEach(display)
    }

    /// The wallpaper under the shot's frame, the bezel beside the screen's edge.
    private static func backdrop(_ cut: CGRect) throws -> CGImage {
        let canvas = try Canvas(cut.size)

        try ReadmeDesktop.drawWallpaper(cut, in: canvas.context)
        canvas.context.setFillColor(EdgeStyle.black)
        canvas.context.fill(CGRect(x: 0, y: 0, width: -cut.minX, height: cut.height))
        return try canvas.image()
    }
}

/// Core Animation's endless turns and sweeps, the working arcs' and the shimmer's, which `render(in:)` never draws:
/// set on their layers as each stands at a share of its period, and set back once drawn.
@MainActor
enum Running {
    /// Each as it stands at a time, from its own phase.
    static func at(_ seconds: Double) -> (CABasicAnimation) -> Double {
        { turn in ((seconds + turn.timeOffset) / turn.duration).truncatingRemainder(dividingBy: 1) }
    }

    static func set(_ layer: CALayer, turned: (CABasicAnimation) -> Double) -> () -> Void {
        var restores: [() -> Void] = []

        still {
            visit(layer) { layer in
                for key in layer.animationKeys() ?? [] {
                    guard let turn = layer.animation(forKey: key) as? CABasicAnimation, turn.repeatCount == .infinity,
                          turn.duration > 0, let path = turn.keyPath,
                          let from = (turn.fromValue as? NSNumber)?.doubleValue,
                          let to = (turn.toValue as? NSNumber)?.doubleValue
                    else {
                        continue
                    }

                    let share = turned(turn), was = layer.value(forKeyPath: path)

                    layer.setValue(from + (to - from) * share, forKeyPath: path)
                    restores.append { layer.setValue(was, forKeyPath: path) }
                }
            }
        }
        return { still { restores.forEach { $0() } } }
    }

    static func visit(_ layer: CALayer, _ each: (CALayer) -> Void) {
        each(layer)
        layer.sublayers?.forEach { visit($0, each) }
        layer.mask.map { visit($0, each) }
    }
}

/// The glows Core Animation casts from a shadow path round a layer that draws nothing, as the strip's marks' are,
/// which `render(in:)` never draws, as it shadows only what a layer draws: the shadow moved for the shot onto a shape
/// of the path, filled in the shadow's colour, laid in the layer, and set back once drawn. The fill shows only where
/// nothing masks it; the strip's marks mask theirs, so the glow shows outside the ring alone.
@MainActor
enum Glows {
    static func set(_ layer: CALayer) -> () -> Void {
        var restores: [() -> Void] = []

        still {
            Running.visit(layer) { layer in
                guard type(of: layer) == CALayer.self, layer.contents == nil, layer.backgroundColor == nil,
                      let path = layer.shadowPath, layer.shadowOpacity > 0
                else {
                    return
                }

                let shape = CAShapeLayer(), opacity = layer.shadowOpacity

                shape.frame = layer.bounds
                shape.path = path
                shape.fillColor = layer.shadowColor
                shape.shadowColor = layer.shadowColor
                shape.shadowOpacity = opacity
                shape.shadowRadius = layer.shadowRadius
                shape.shadowOffset = layer.shadowOffset
                layer.shadowOpacity = 0
                layer.addSublayer(shape)
                restores.append {
                    shape.removeFromSuperlayer()
                    layer.shadowOpacity = opacity
                }
            }
        }
        return { still { restores.forEach { $0() } } }
    }
}
