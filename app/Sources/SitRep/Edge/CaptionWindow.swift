import AppKit
import SitRepCore
import SitRepPanel

/// The caption a jump from a row leaves, at the top of the notch's screen, centred, under the menu bar: the
/// prototypes' dark pill, shown when `JumpCaption` says and coming and going as its `look` has it, played by Core
/// Animation in the render server. A jump from anywhere that runs on with no answer says so in it too (`heard`). It
/// takes no clicks, never shows over a full-screen app, and VoiceOver announces each caption as it shows.
@MainActor
final class CaptionWindow {
    /// The visible frame of the notch's screen.
    var over = CGRect.zero
    /// Whether it may show: only while the notch does, never while a full-screen app has the notch's display. Kept
    /// from showing, a caption showing or waiting to goes.
    var mayShow = false {
        didSet {
            if !mayShow {
                pending = nil
                pill.removeAllAnimations()
                window.isShown = false
                says = nil
                holds = false
            }
        }
    }

    private var pending: JumpCaption?
    /// What the pill says while it shows, nil while it shows nothing: internal only for the tests.
    private(set) var says: String?
    /// Whether what it says holds until the jump ends, as "Still jumping…" does.
    private var holds = false
    private let pill = CALayer()
    /// Its window: internal only for the tests, which read which way the pill drifts in it.
    let window: EdgeWindow

    init() {
        let root = CALayer()

        pill.backgroundColor = Self.fill
        pill.shadowColor = EdgeStyle.black
        pill.shadowOpacity = 0.18
        pill.shadowRadius = 12
        pill.shadowOffset = CGSize(width: 0, height: 8)
        pill.opacity = 0
        root.addSublayer(pill)
        window = EdgeWindow.onScreen(frame: .zero, view: StageHost(hosting: root))
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

    /// A jump's news, whichever surface asked for it, after that surface's own `answered`: "Still jumping…", or
    /// "Still opening…", once it has run on with no answer, held until it ends; the limit's words once it gives up
    /// at its limit. Any other end lets a held caption go, unless a row's "Jumped to…" has taken its place; a jump
    /// stopped by a later one leaves what shows, as the later one runs on.
    func heard(_ news: JumpNews) {
        guard mayShow else {
            return
        }

        switch news {
        case .still:
            show(JumpCaption.still, holding: true)
        case .stillOpening:
            show(JumpCaption.stillOpening, holding: true)
        case .ended(.unanswered):
            pending = nil
            show(JumpCaption.tooBusy)
        case .ended(.stopped), .ended(.openable):
            break
        case .ended(.jumped), .ended(.jumpedSaying), .ended(.opened), .ended(.openedSaying), .ended(.opening),
             .ended(.refused), .ended(.unopened):
            letGo()
        }
    }

    /// The jump answered how it landed, where it did: "Jumped to…", "Opened a window for…", or, for one asked for a
    /// moment ago, "A window for… is opening". A jump refused leaves no caption; one with a window still to open, none
    /// yet.
    func answered(_ answer: JumpAnswer, at time: Double) {
        switch answer {
        case .jumped, .jumpedSaying:
            pending?.landed(.jumped, at: time)
        case .opened, .openedSaying:
            pending?.landed(.opened, at: time)
        case .opening:
            pending?.landed(.opening, at: time)
        case .openable:
            return
        case .refused, .unopened, .unanswered, .stopped:
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

    /// The caption, this many ms from now, played whole, or held once in until the jump ends. One taking the place of a
    /// caption showing comes in from the pill's opacity as it is, so it never jumps.
    private func show(_ caption: String, after delay: Double = 0, holding: Bool = false) {
        let text = TextLine.text(caption, Self.font, EdgeStyle.ink, kern: EdgeStyle.tightKern(Self.font))
        let size = CGSize(width: TextLine.width(text).rounded(.up) + 2 * Self.pad.x, height: Self.line + 2 * Self.pad.y)
        let room = Self.room, visible = over
        let part = JumpCaption.part(holding: holding, from: opacity)

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
        says = caption
        holds = holding
        window.isShown = true
        play(part, after: delay / 1000)
        NSAccessibility.post(
            element: window, notification: .announcementRequested,
            userInfo: [.announcement: caption, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }

    /// A held caption goes, rising as it fades, as a caption ends.
    private func letGo() {
        guard holds else {
            return
        }

        holds = false
        play(JumpCaption.going(from: opacity), after: 0)
    }

    /// How opaque the pill shows now, mid-animation or not; clear while it shows nothing.
    private var opacity: Double {
        says == nil ? 0 : Double(pill.presentation()?.opacity ?? pill.opacity)
    }

    /// The fade and the drift over a part of the look, sampled from `JumpCaption.look`, the pill left as the part ends:
    /// clear once a caption has gone, the window hidden then; whole while one holds. A part with no length, a caption
    /// held over one already whole, or one going that is already clear, plays nothing.
    private func play(_ part: ClosedRange<Double>, after delay: CFTimeInterval) {
        guard part.upperBound > part.lowerBound else {
            still {
                pill.removeAnimation(forKey: Self.key)
                pill.opacity = Float(JumpCaption.look(part.lowerBound).alpha)
            }
            return ended()
        }

        let steps = max(1, Int((part.upperBound - part.lowerBound) / Self.sampled))
        let looks = (0 ... steps).map {
            JumpCaption.look(part.lowerBound + Double($0) * (part.upperBound - part.lowerBound) / Double(steps))
        }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        let drift = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let group = CAAnimationGroup()

        fade.values = looks.map(\.alpha)
        drift.values = looks.map { Self.drift($0.lift) }
        group.animations = [fade, drift]
        group.duration = (part.upperBound - part.lowerBound) / 1000
        group.beginTime = pill.convertTime(CACurrentMediaTime(), from: nil) + delay
        group.fillMode = .both
        still { pill.opacity = Float(looks.last?.alpha ?? 0) }
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated { self?.ended() }
        }
        pill.add(group, forKey: Self.key)
        CATransaction.commit()
    }

    private func ended() {
        if pill.animation(forKey: Self.key) == nil, !holds {
            window.isShown = false
            says = nil
        }
    }

    /// The pill's drift for a lift above its place: up its window, which hosts it top-down; internal only for the
    /// tests, which read its direction.
    static func drift(_ lift: Double) -> Double { -lift }

    private static let key = "caption"
    /// How finely the look is sampled, ms.
    private static let sampled = 10.0
    private static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let line = 18.0, pad = (x: 14.0, y: 7.0)
    /// Under the visible frame's top, and the room round the pill for its shadow.
    private static let top = 22.0, room = 32.0
    private static let fill = CGColor(srgbRed: 16 / 255, green: 16 / 255, blue: 20 / 255, alpha: 0.84)
}
