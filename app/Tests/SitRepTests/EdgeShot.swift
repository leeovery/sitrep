import AppKit
@testable import SitRep
import Testing

/// An edge's surface shot on the README's desktop (`app/screens`), at the screen's left edge, or its right: the
/// wallpaper, the display's black bezel beside the edge, and the surface's drawing over them as Core Animation's
/// endless turns stand at a moment, each shot a picture at 2×. Only the wallpaper, the bezel and the glows' stand-ins
/// (`Glows`) are not the app's.
@MainActor
final class EdgeShot {
    /// The display's black bezel shown beside the screen's edge, which the edge's black flares into.
    private static let bezel = 6.0

    /// The shot's frame in the surface, the bezel past its edge.
    private let cut: CGRect
    /// How far below the screen's top the surface's window starts.
    private let hung: Double
    private let backdrop: CGImage
    /// The surface's drawing, under a flipped root, as `Drawn` draws a layer.
    private let root = CALayer()

    /// The surface, shot over `cut` in its own points, its window starting `hung` below the screen's top: against the
    /// screen's left edge, from it; or `onRight`, against its right edge, out to it.
    init(_ surface: NSView, cut: CGRect, hung: Double = 0, onRight: Bool = false) throws {
        let framed = onRight
            ? CGRect(x: cut.minX, y: cut.minY, width: surface.bounds.width - cut.minX + Self.bezel, height: cut.height)
            : CGRect(x: -Self.bezel, y: cut.minY, width: cut.maxX + Self.bezel, height: cut.height)

        self.cut = framed
        self.hung = hung
        backdrop = try onRight
            ? Self.backdrop(rightOf: framed, from: ReadmeDesktop.screen.width - surface.bounds.width)
            : Self.backdrop(framed)

        let drawing = try #require(surface.subviews.first?.layer)

        root.isGeometryFlipped = true
        root.frame = surface.bounds
        root.addSublayer(drawing)
    }

    /// The shot as the screen shows it: the desktop, the surface over it with each endless turn at the share of its
    /// period `turned` gives it and its glows lit, and what `over` draws over all, in the screen's points. The
    /// drawing's layers are drawn out of their view, under the flipped root, so the flip AppKit gave them for the view
    /// comes off first.
    func shoot(turned: (CABasicAnimation) -> Double, over: (CGContext) -> Void = { _ in }) throws -> Canvas {
        let canvas = try Canvas(cut.size), context = canvas.context
        let restores = [try Glows.set(root), Running.set(root, turned: turned), Shadows.set(root)]

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

    /// The wallpaper under the shot's frame against the screen's right edge, the surface standing this far from the
    /// screen's left, and the bezel past the edge.
    private static func backdrop(rightOf cut: CGRect, from left: Double) throws -> CGImage {
        let canvas = try Canvas(cut.size)

        try ReadmeDesktop.drawWallpaper(cut.offsetBy(dx: left, dy: 0), in: canvas.context)
        canvas.context.setFillColor(EdgeStyle.black)
        canvas.context.fill(CGRect(x: cut.width - bezel, y: 0, width: bezel, height: cut.height))
        return try canvas.image()
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
    /// Each as it stands this far into a film, turned from its start. An arc's own phase is left out: it is the wall
    /// clock's when the arc began turning (`Arc.phase`), which would draw it elsewhere at every run, and every arc
    /// shares it, so they turn in step all the same.
    static func at(_ seconds: Double) -> (CABasicAnimation) -> Double {
        { turn in (seconds / turn.duration).truncatingRemainder(dividingBy: 1) }
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

/// The shadows cast down the screen, an asks panel's, which `render(in:)` casts up instead, offsetting each in the
/// context's own space, y up, where the screen offsets it in the flipped layers': each offset turned over for the shot,
/// and set back once drawn.
@MainActor
enum Shadows {
    static func set(_ root: CALayer) -> () -> Void {
        var restores: [() -> Void] = []

        still {
            Running.visit(root) { layer in
                let offset = layer.shadowOffset

                guard layer.shadowOpacity > 0, offset.height != 0 else {
                    return
                }

                layer.shadowOffset = CGSize(width: offset.width, height: -offset.height)
                restores.append { layer.shadowOffset = offset }
            }
        }
        return { still { restores.forEach { $0() } } }
    }
}

/// The glows Core Animation casts from a shadow path round a layer that draws nothing, as the strip's marks' are,
/// which `render(in:)` never draws, as it shadows only what a layer draws: the shadow moved for the shot onto a shape
/// of the path, filled in the shadow's colour, laid in the layer, and set back once drawn. Right only for a mark at
/// rest: its path the ring's own circle, wholly inside the hole its glow's mask cuts, so the fill is masked away and
/// the glow shows outside the ring alone. A mark arriving spreads its path past the ring, where the fill would show as
/// a band, so any other glow stops the shot.
@MainActor
enum Glows {
    static func set(_ root: CALayer) throws -> () -> Void {
        var glowing: [CALayer] = []

        Running.visit(root) { layer in
            if type(of: layer) == CALayer.self, layer.contents == nil, layer.backgroundColor == nil,
               layer.shadowPath != nil, layer.shadowOpacity > 0 {
                glowing.append(layer)
            }
        }
        for layer in glowing {
            try #require(
                layer.superlayer?.mask != nil && layer.shadowPath == CGPath(ellipseIn: layer.bounds, transform: nil),
                "a glow the shot can't stand in for: not a mark's at rest"
            )
        }

        var restores: [() -> Void] = []

        still {
            for layer in glowing {
                let shape = CAShapeLayer(), opacity = layer.shadowOpacity

                shape.frame = layer.bounds
                shape.path = layer.shadowPath
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
