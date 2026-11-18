import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import Testing

/// The notch filmed at the screen's left edge on the README's desktop (`app/screens`): the real run driving the real
/// surface frame by frame on a clock of the film's own, the pointer moved as a hand moves it, each frame written as a
/// PNG at 2×, with how long it shows, for `img2webp` to make the film of. Only the wallpaper and the pointer, macOS's
/// own arrow, are not the app's. The film runs at the display's 60 frames a second while the notch moves, and at 30
/// while it rests, when only its light breathes, or the working rows' arcs turn and their verbs shimmer.
@MainActor
final class NotchFilm {
    private static let frameMS = 1000.0 / 60
    /// The display's black bezel shown beside the screen's edge, which the notch flares into.
    private static let bezel = 6.0

    private let run: NotchRun
    private let surface: NotchSurface
    private let setting: NotchRun.Setting
    private let mirror: CGAffineTransform
    /// The film's frame on the stage, the bezel at its left.
    private let cut: CGRect
    private let backdrop: CGImage
    /// The surface's drawing, under a flipped root, as `Drawn` draws a layer.
    private let root = CALayer()
    private let arrow = NSCursor.arrow
    private let folder: URL
    /// The run's time when the film starts.
    private let start: Double
    /// The film's own time, ms from its start.
    private var time = 0.0
    private var shots: [(name: String, at: Double)] = []

    /// The run, warmed up and drawn, filmed over `cut` on the stage into `folder`.
    init(
        _ run: NotchRun, surface: NotchSurface, setting: NotchRun.Setting, mirror: CGAffineTransform, cut: CGRect,
        into folder: URL
    ) throws {
        let framed = CGRect(x: -Self.bezel, y: cut.minY, width: cut.maxX + Self.bezel, height: cut.height)

        self.run = run
        self.surface = surface
        self.setting = setting
        self.mirror = mirror
        self.cut = framed
        self.folder = folder
        start = run.time
        backdrop = try Self.backdrop(framed)

        let drawing = try #require(surface.subviews.first?.layer)

        root.isGeometryFlipped = true
        root.frame = surface.bounds
        root.addSublayer(drawing)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// The notch left as it is for `ms`, the pointer where it is, shot at every other frame.
    func rest(_ ms: Double, pointer: CGPoint) throws {
        for step in 0 ..< Int((ms / Self.frameMS).rounded()) {
            try frame(pointer, shoots: step.isMultiple(of: 2))
        }
    }

    /// The pointer moved from one point to another over `ms`, eased in and out, as a hand moves.
    func glide(from: CGPoint, to: CGPoint, over ms: Double) throws {
        let begun = time

        while time < begun + ms {
            let share = min(1, (time + Self.frameMS - begun) / ms), eased = share * share * (3 - 2 * share)

            try frame(CGPoint(x: from.x + (to.x - from.x) * eased, y: from.y + (to.y - from.y) * eased), shoots: true)
        }
    }

    /// The pointer held where it is until the notch is still in `phase`.
    func settle(_ phase: Phase, pointer: CGPoint) throws {
        let end = time + 5000

        repeat {
            try frame(pointer, shoots: true)
        } while (run.phase != phase || run.frame.isMoving) && time < end
        #expect(run.phase == phase)
    }

    /// Each frame's file and how long it shows, a line each, the last until the film's end, for `img2webp`.
    func finish() throws {
        let ends = shots.dropFirst().map(\.at) + [time]
        let lines = zip(shots, ends).map { shot, end in "\(shot.name) \(Int(end.rounded()) - Int(shot.at.rounded()))" }

        try (lines.joined(separator: "\n") + "\n").write(
            to: folder.appending(path: "frames.txt"), atomically: true, encoding: .utf8
        )
    }

    /// One frame of the display's: the run moved on with the pointer here, drawn, and shot where `shoots` says.
    private func frame(_ pointer: CGPoint, shoots: Bool) throws {
        time += Self.frameMS
        run.step(NotchRun.Moment(time: start + time, pointer: pointer, pointerAt: start + time, setting: setting))
        surface.draw(run, in: setting, mirror: mirror)
        if shoots {
            try shoot(pointer)
        }
    }

    /// The frame as the screen shows it: the desktop, the notch over it as Core Animation's running animations stand at
    /// this time, and the pointer over all. The drawing's layers are drawn out of their view, under the flipped root,
    /// so the flip AppKit gave them for the view comes off first.
    private func shoot(_ pointer: CGPoint) throws {
        let canvas = try Canvas(cut.size), context = canvas.context
        let restore = Running.set(root, at: time / 1000)

        defer { restore() }
        canvas.draw(backdrop, in: CGRect(origin: .zero, size: cut.size))
        root.sublayers?.forEach { $0.isGeometryFlipped = false }
        Self.display(root)
        context.saveGState()
        context.translateBy(x: -cut.minX, y: -cut.minY)
        root.render(in: context)
        drawArrow(at: pointer, context)
        context.restoreGState()

        let name = String(format: "frame-%04d.png", shots.count)

        try canvas.png().write(to: folder.appending(path: name))
        shots.append((name, time))
    }

    /// The arrow with its tip at the pointer, on the stage, its shadow under it as the window server draws one.
    private func drawArrow(at pointer: CGPoint, _ context: CGContext) {
        let image = arrow.image
        let rect = CGRect(origin: CGPoint(x: pointer.x - arrow.hotSpot.x, y: pointer.y - arrow.hotSpot.y), size: image.size)

        context.saveGState()
        // the shadow's offset is the device's, y up: it falls below the arrow
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 6, color: ReadmeDesktop.colour(0, alpha: 0.4))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    /// Every layer drawn at 2×, its content drawn again where it asks to be.
    private static func display(_ layer: CALayer) {
        layer.contentsScale = Canvas.scale
        layer.displayIfNeeded()
        layer.sublayers?.forEach(display)
    }

    /// The wallpaper under the film's frame, the bezel beside the screen's edge.
    private static func backdrop(_ cut: CGRect) throws -> CGImage {
        let canvas = try Canvas(cut.size)

        try ReadmeDesktop.drawWallpaper(cut, in: canvas.context)
        canvas.context.setFillColor(EdgeStyle.black)
        canvas.context.fill(CGRect(x: 0, y: 0, width: -cut.minX, height: cut.height))
        return try canvas.image()
    }
}

/// Core Animation's endless turns and sweeps, the working arcs' and the shimmer's, which `render(in:)` never draws:
/// set on their layers as each stands at a time, from its own phase, and set back once drawn.
@MainActor
enum Running {
    static func set(_ layer: CALayer, at seconds: Double) -> () -> Void {
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

                    let share = ((seconds + turn.timeOffset) / turn.duration).truncatingRemainder(dividingBy: 1)
                    let was = layer.value(forKeyPath: path)

                    layer.setValue(from + (to - from) * share, forKeyPath: path)
                    restores.append { layer.setValue(was, forKeyPath: path) }
                }
            }
        }
        return { still { restores.forEach { $0() } } }
    }

    private static func visit(_ layer: CALayer, _ each: (CALayer) -> Void) {
        each(layer)
        layer.sublayers?.forEach { visit($0, each) }
        layer.mask.map { visit($0, each) }
    }
}
