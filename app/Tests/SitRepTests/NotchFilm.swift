import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import Testing

/// The notch filmed at the screen's left edge on the README's desktop (`app/screens`): the real run driving the real
/// surface frame by frame on a clock of the film's own, the pointer moved as a hand moves it, each frame written as a
/// PNG at 2×, with how long it shows, for `img2webp` to make the film of. Only the wallpaper and the pointer, drawn as
/// macOS's arrow, are not the app's. The film runs at the display's 60 frames a second while the notch moves, and at 30
/// while it rests, when only its light breathes, or the working rows' arcs turn and their verbs shimmer.
@MainActor
final class NotchFilm {
    private static let frameMS = 1000.0 / 60

    private let run: NotchRun
    private let surface: NotchSurface
    private let setting: NotchRun.Setting
    private let mirror: CGAffineTransform
    private let shot: EdgeShot
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
        self.run = run
        self.surface = surface
        self.setting = setting
        self.mirror = mirror
        self.folder = folder
        start = run.time
        shot = try EdgeShot(surface, cut: cut)
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

    /// The frame as the screen shows it, the pointer over all.
    private func shoot(_ pointer: CGPoint) throws {
        let canvas = try shot.shoot(turned: Running.at(time / 1000)) { drawArrow(at: pointer, $0) }
        let name = String(format: "frame-%04d.png", shots.count)

        try canvas.png().write(to: folder.appending(path: name))
        shots.append((name, time))
    }

    /// The arrow with its tip at the pointer, on the stage: black, edged in white, its shadow under it, as the window
    /// server draws macOS's.
    private func drawArrow(at pointer: CGPoint, _ context: CGContext) {
        var placed = CGAffineTransform(translationX: pointer.x, y: pointer.y)
        let arrow = Self.arrow.copy(using: &placed) ?? Self.arrow

        context.saveGState()
        context.setLineJoin(.round)
        context.saveGState()
        // the shadow's offset is the device's, y up: it falls below the arrow
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: ReadmeDesktop.colour(0, alpha: 0.45))
        context.addPath(arrow)
        context.setStrokeColor(ReadmeDesktop.colour(0xFFFFFF))
        context.setLineWidth(3)
        context.strokePath()
        context.restoreGState()
        context.addPath(arrow)
        context.setFillColor(ReadmeDesktop.colour(0))
        context.fillPath()
        context.restoreGState()
    }

    /// macOS's arrow, its tip at the origin, y down: drawn here, as offscreen `NSCursor.arrow` has no image.
    private static let arrow: CGPath = {
        let path = CGMutablePath()

        path.addLines(between: [
            CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 16.5), CGPoint(x: 4, y: 12.7), CGPoint(x: 6.6, y: 18.6),
            CGPoint(x: 9.2, y: 17.5), CGPoint(x: 6.7, y: 11.8), CGPoint(x: 12, y: 11.8),
        ])
        path.closeSubpath()
        return path
    }()
}
