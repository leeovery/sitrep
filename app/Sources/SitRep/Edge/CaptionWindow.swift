import AppKit
import SitRepPanel

/// The caption a jump from a row leaves, at the top of the notch's screen, centred, under the menu bar: the
/// prototypes' dark pill, shown when `JumpCaption` says and coming and going as its `look` has it, played by Core
/// Animation in the render server. It takes no clicks, and never shows over a full-screen app.
@MainActor
final class CaptionWindow {
    /// The visible frame of the notch's screen.
    var over = CGRect.zero
    /// Whether it may show: not while a full-screen app has the notch's display. Kept from showing, a caption showing
    /// or waiting to goes.
    var mayShow = true {
        didSet {
            if !mayShow {
                pending = nil
                pill.removeAllAnimations()
                window.orderOut(nil)
            }
        }
    }

    private var pending: JumpCaption?
    private let pill = CALayer()
    private let view = NSView()
    private let window: EdgeWindow

    init() {
        let root = CALayer()

        root.isGeometryFlipped = true
        pill.backgroundColor = Self.fill
        pill.shadowColor = EdgeStyle.black
        pill.shadowOpacity = 0.18
        pill.shadowRadius = 12
        pill.shadowOffset = CGSize(width: 0, height: 8)
        pill.opacity = 0
        root.addSublayer(pill)
        view.layer = root
        view.wantsLayer = true
        window = EdgeWindow(frame: .zero, view: view)
    }

    /// A row's jump began, to a session on this project.
    func jumping(to project: String) {
        pending = mayShow ? JumpCaption(to: project) : nil
    }

    /// The panel began to drain, at this time on the display's clock.
    func drained(at time: Double) {
        pending?.drained(at: time)
        showWhenDue(at: time)
    }

    /// The jump answered: whether it jumped. A jump refused leaves no caption.
    func answered(jumped: Bool, at time: Double) {
        if jumped {
            pending?.jumped(at: time)
        } else {
            pending = nil
        }
        showWhenDue(at: time)
    }

    /// Once it knows when, it shows then, and a caption whose moment has passed never does.
    private func showWhenDue(at now: Double) {
        guard let pending, pending.showsAt != nil else {
            return
        }

        self.pending = nil
        if let delay = pending.showsIn(at: now) {
            show(pending.text, after: delay)
        }
    }

    /// The caption, this many ms from now.
    private func show(_ caption: String, after delay: Double) {
        let text = TextLine.text(caption, Self.font, EdgeStyle.ink, kern: EdgeStyle.tightKern(Self.font))
        let size = CGSize(width: TextLine.width(text).rounded(.up) + 2 * Self.pad.x, height: Self.line + 2 * Self.pad.y)
        let room = Self.room, visible = over

        window.setFrame(CGRect(
            x: visible.midX - size.width / 2 - room, y: visible.maxY - Self.top - size.height - room,
            width: size.width + 2 * room, height: size.height + 2 * room
        ), display: false)
        still {
            pill.removeAllAnimations()
            pill.sublayers?.forEach { $0.removeFromSuperlayer() }
            pill.frame = CGRect(origin: CGPoint(x: room, y: room), size: size)
            pill.cornerRadius = size.height / 2
            pill.addSublayer(TextLine(
                text, in: CGRect(x: Self.pad.x, y: Self.pad.y, width: size.width - 2 * Self.pad.x, height: Self.line)
            ))
            rescale(pill, to: window.backingScaleFactor)
        }
        window.orderFrontRegardless()
        play(after: delay / 1000)
    }

    /// The fade and the drift, sampled from `JumpCaption.look`; the window goes once it is over.
    private func play(after delay: CFTimeInterval) {
        let steps = Int(JumpCaption.length / Self.sampled)
        let looks = (0 ... steps).map { JumpCaption.look(Double($0) * Self.sampled) }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        let drift = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let group = CAAnimationGroup()

        fade.values = looks.map(\.alpha)
        drift.values = looks.map { -$0.lift }
        group.animations = [fade, drift]
        group.duration = JumpCaption.length / 1000
        group.beginTime = pill.convertTime(CACurrentMediaTime(), from: nil) + delay
        group.fillMode = .both
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated { self?.ended() }
        }
        pill.add(group, forKey: Self.key)
        CATransaction.commit()
    }

    private func ended() {
        if pill.animation(forKey: Self.key) == nil {
            window.orderOut(nil)
        }
    }

    private static let key = "caption"
    /// How finely the look is sampled, ms.
    private static let sampled = 10.0
    private static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let line = 18.0, pad = (x: 14.0, y: 7.0)
    /// Under the visible frame's top, and the room round the pill for its shadow.
    private static let top = 22.0, room = 32.0
    private static let fill = CGColor(srgbRed: 16 / 255, green: 16 / 255, blue: 20 / 255, alpha: 0.84)
}
