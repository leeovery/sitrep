import AppKit
import SitRepPanel

/// The caption a jump leaves, at the top of the notch's screen, centred, under the menu bar: the prototypes' dark pill,
/// coming and going as `JumpCaption.look` has it, played by Core Animation in the render server. It takes no clicks.
@MainActor
final class CaptionWindow {
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

    /// The caption over this visible frame, this many ms from now.
    func show(_ caption: String, over visible: CGRect, after delay: Double) {
        let text = TextLine.text(caption, Self.font, EdgeStyle.ink, kern: EdgeStyle.tightKern(Self.font))
        let size = CGSize(width: TextLine.width(text).rounded(.up) + 2 * Self.pad.x, height: Self.line + 2 * Self.pad.y)
        let room = Self.room

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
