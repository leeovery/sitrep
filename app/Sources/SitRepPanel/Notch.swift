import CoreGraphics
import Foundation

/// A notch's feel, Meniscus or Card: the view feeds it a frame at a time and draws what each gives back.
public protocol Notch: AnyObject {
    var phase: Phase { get }
    /// The panel's list, in the order each frame paints it.
    var items: [Item] { get }
    /// How far from the edge a pointer by the notch counts as near it, for `Frame.wakes`.
    var field: Double { get }
    /// The notch's home along the edge, its centre: the stage's, kept inside the band.
    var notchY: Double { get }

    func frame(_ input: Input) -> Frame
    /// A new ask: the notch swells and the light flashes. Something needs Lee from here.
    func newAsk()
    /// Something needs Lee with nothing new, as on the first board: the notch goes to its size and the light comes
    /// on, with no swell and no flash.
    func needsLeeQuietly()
    /// A click on one of `items`: one that jumps presses in and spins until the jump answers (`jumpAnswered`), for
    /// `Tuning.jumpFor` at most, and then the panel drains. Only an open or opening panel takes it, one jump at a
    /// time: whether it did.
    @discardableResult func clickRow(_ index: Int) -> Bool
    /// The jump answered: a row still pressed in drains the panel now.
    func jumpAnswered()
    /// A click anywhere off the panel and the notch closes it at once.
    func clickElsewhere()
    /// A drag carries the notch, as the prototypes' does: the panel closes and the notch lifts off the edge.
    func carry()
    /// The drag has the notch's home this far down the stage: the notch follows it on a 50ms spring, inside the band.
    func carried(to y: Double)
    /// The drag let the notch go: it sets down, and doesn't open under the pointer until it leaves. Let go across the
    /// screen's middle, it drains into this edge and grows out of the other, the frame saying when (`swapsEdge`).
    func drop(across: Bool)
    /// Whether a press may carry the notch: not from a drop across the screen's middle until it is home on the other
    /// edge, as the prototypes take no press while it moves.
    var mayCarry: Bool { get }
    /// The notch at rest, its home this far down the stage, inside the band: a drag's ghost on the other edge.
    func restingOutline(at y: Double) -> CGPath
}

extension Notch {
    /// Its time run on while nothing showed it, from the last frame's time to now: a frame each 50ms, the pointer
    /// away, until nothing moves, so it shows as it would have come to rest and plays nothing late. The first frame
    /// takes what came meanwhile, a new ask's swell among it. Its last frame.
    public func runOn(from time: Double, to now: Double, _ input: (Double) -> Input) -> Frame {
        var time = time, last: Frame

        repeat {
            time = min(now, time + 50)
            last = frame(input(time))
        } while time < now && last.isMoving

        return last
    }
}

/// What the two notches share, as their prototypes share it: the sim clock and its timers, the pointer's trail, what
/// the pointer is over, the rows landing and fading, and reduced motion.
protocol NotchModel: Notch, SimModel where TimerName: ClickTimers {
    associatedtype SpringSet

    /// Every spring the notch is made of, by its prototype's names (its `S`).
    var S: SpringSet { get set }
    var isLive: Bool { get }
    var content: Content { get }
    /// The row a click is jumping to, pressed in until the panel has drained.
    var jumping: String? { get set }
    /// The notch's hit area and the panel's content as last drawn, which the pointer is hit-tested against.
    var lastHit: CGRect? { get }
    var lastPanel: Frame.Panel? { get }
    var reveal: Reveal { get }
    /// The head lands this long after the rows are let in.
    var rowsAt: Double { get }
    var reducesMotion: Bool { get }
    /// Under reduced motion, the outline cross-fading out, and since when.
    var fade: (outline: CGPath, t0: Double)? { get set }
    /// The outline as last drawn, which a cross-fade fades out.
    var lastOutline: CGPath? { get }

    /// The panel goes in, as a click elsewhere or a jump sends it.
    func close()
}

/// The timers a click runs, which both notches name alike: the grace a leave starts, and the jump's wait.
protocol ClickTimers {
    static var grace: Self { get }
    static var jump: Self { get }
}

/// A click, as both prototypes take it.
extension NotchModel {
    @discardableResult
    public func clickRow(_ index: Int) -> Bool {
        guard isLive, jumping == nil, let id = jumpingRow(index) else {
            return false
        }

        cancel(.grace)
        jumping = id
        later(.jump, Tuning.jumpFor) { $0.close() }
        return true
    }

    public func jumpAnswered() {
        if timers.has(.jump) {
            cancel(.jump)
            close()
        }
    }

    public func clickElsewhere() {
        if isLive {
            close()
        }
    }
}

/// Reduced motion, as both prototypes have it: nothing springs, a move takes 140ms at most, and a change of shape
/// cross-fades.
extension NotchModel {
    /// A spring to a target in a duration, critically damped; under reduced motion never longer than 140ms.
    func to(_ key: WritableKeyPath<SpringSet, Spring>, _ target: Double, _ dur: Double) {
        S[keyPath: key].to(target, reducesMotion ? min(dur, 140) : dur)
    }

    /// The same on an underdamped spring; under reduced motion, critically damped in 120ms.
    func springTo(_ key: WritableKeyPath<SpringSet, Spring>, _ target: Double, _ p: SpringParams) {
        if reducesMotion {
            to(key, target, 120)
        } else {
            S[keyPath: key].springTo(target, p)
        }
    }

    /// Straight to a shape, under reduced motion: its springs there at once, and the outline last drawn fading out as
    /// the new one fades in, unless a cross-fade began this moment.
    func crossfade(to targets: [(WritableKeyPath<SpringSet, Spring>, Double)]) {
        if fade.map({ t - $0.t0 > 1 }) ?? true {
            fade = (lastOutline ?? CGMutablePath(), t)
        }
        for (key, target) in targets {
            S[keyPath: key].snap(target)
            S[keyPath: key].to(target, 120)
        }
    }

    /// The cross-fade this frame: the new outline fading in over 100ms, the old one out over 160, and then done.
    func fadeOutlines() -> (alpha: Double, fading: Frame.Fading?) {
        if let fade, t - fade.t0 >= 160 {
            self.fade = nil
        }
        return (
            fade.map { clamp((t - $0.t0) / 100, 0, 1) } ?? 1,
            fade.map { Frame.Fading(outline: $0.outline, alpha: 1 - clamp((t - $0.t0) / 160, 0, 1)) }
        )
    }
}

extension NotchModel {
    /// The pointer's speed toward the edge (below 0: away from it).
    func approachSpeed() -> Double { -trailVelocity().x }

    /// The notch's hit area lies over the panel's content, which counts only while the panel is live.
    func hoverOf(_ p: Vec?) -> Hover? {
        guard let p else {
            return nil
        }

        if let lastHit, inRect(p, lastHit) {
            return .notch
        }
        if isLive, let lastPanel, lastPanel.contains(CGPoint(p)) {
            return .panel
        }
        return nil
    }

    /// The pointer's real whereabouts, against the notch and the panel as last drawn.
    func pointerInside() -> Bool { hoverOf(sp) != nil }

    /// The row a click on this item jumps from: a session's row a window holds, and not folding away.
    func jumpingRow(_ index: Int) -> String? {
        content.entries.indices.contains(index) && content.entries[index].jumps ? items[index].session?.id : nil
    }

    /// Each item's place in the order the rows land, after the head's 0: a divider lands with the row after it.
    var revealOrder: [Int] {
        var k = 0
        return items.map { item in
            if item != .divider {
                k += 1
            }
            return item == .divider ? k + 1 : k
        }
    }

    /// Rows land from the top, 25ms apart: the head `rowsAt` after they are let in, then each row; each fades and
    /// rises in 90ms, or under reduced motion all fade in together over 120ms. Closing, they fade in 60ms.
    func revealAlpha(_ i: Int) -> Double {
        switch reveal {
        case let .rowsIn(t0):
            reducesMotion
                ? clamp((t - t0) / 120, 0, 1)
                : easeOut(clamp((t - t0 - rowsAt - 25 * Double(i)) / 90, 0, 1))
        case let .rowsOut(t0):
            1 - clamp((t - t0) / 60, 0, 1)
        case .none:
            0
        }
    }

    func paint(_ a: Double) -> Frame.Paint {
        guard case .rowsIn = reveal, !reducesMotion, a < 1 else {
            return Frame.Paint(alpha: a, rise: 0)
        }

        return Frame.Paint(alpha: a, rise: (1 - a) * 4)
    }

    /// The head and each item as they land or fade, an item also as it fades in or folds away (`Folds`).
    func renderRows() -> (head: Frame.Paint, items: [Frame.Paint]) {
        (paint(revealAlpha(0)), zip(revealOrder, content.entries).map { paint(revealAlpha($0) * $1.alpha) })
    }

    /// Rows landing or fading while the panel is out.
    var isRevealing: Bool {
        guard phase != .closed else {
            return false
        }

        switch reveal {
        case .rowsIn:
            return revealAlpha(revealOrder.max() ?? 0) < 1
        case .rowsOut:
            return revealAlpha(0) > 0
        case .none:
            return false
        }
    }
}

/// Where the panel is.
public enum Phase: Sendable {
    case closed, opening, open, closing
}

/// The notch family, through the two drawn notches: 7 deep × 76 long, and 15 × 124. Each end is an S-curve of length
/// e = r + f, and r and f split it as the panel does (24 : 18).
struct NotchShape: Equatable {
    var w, h, r, f: Double

    /// The prototype's `lipShape(w)`.
    init(_ w: Double) {
        let e = 29 + (w - 7) * 19 / 8
        self.w = w
        h = 76 + (w - 7) * 6
        r = e * 4 / 7
        f = e * 3 / 7
    }

    static let rest = NotchShape(7), needs = NotchShape(15)
}

/// The rows landing as the panel opens, or fading as it closes, since a time on the sim clock.
enum Reveal {
    case none, rowsIn(Double), rowsOut(Double)
}
