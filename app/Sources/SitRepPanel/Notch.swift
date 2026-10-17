import CoreGraphics
import Foundation

/// A notch's feel, Meniscus or Card: the view feeds it a frame at a time and draws what each gives back.
public protocol Notch: AnyObject {
    var phase: Phase { get }
    /// The panel's list, in the order each frame paints it.
    var items: [Item] { get }
    /// How far from the edge a pointer by the notch counts as near it, for `Frame.wantsFrames`.
    var field: Double { get }

    func frame(_ input: Input) -> Frame
    /// A new ask: the notch swells and the light flashes. Something needs Lee from here.
    func newAsk()
    /// A click on one of `items`: one that jumps closes the panel, as a jump does.
    func clickRow(_ index: Int)
    /// A click anywhere off the panel and the notch closes it at once.
    func clickElsewhere()
}

/// What the two notches share, as their prototypes share it: the sim clock and its timers, the pointer's trail, what
/// the pointer is over, and the rows landing and fading.
protocol NotchModel: Notch {
    associatedtype TimerName: RawRepresentable & Equatable where TimerName.RawValue == String

    /// The sim clock, ms.
    var t: Double { get }
    /// The view's clock at the latest frame, ms: the pointer's trail runs on it.
    var now: Double { get }
    var timers: SimTimers<Self, TimerName> { get set }
    /// The pointer this frame.
    var sp: Vec? { get }
    var trail: Trail { get }
    /// The notch's home along the edge, its centre.
    var lipY: Double { get }
    var isLive: Bool { get }
    /// The notch's hit area and the panel's content as last drawn, which the pointer is hit-tested against.
    var lastHit: CGRect? { get }
    var lastPanel: Frame.Panel? { get }
    var reveal: Reveal { get }
    /// The head lands this long after the rows are let in.
    var rowsAt: Double { get }
    var reducesMotion: Bool { get }
}

extension NotchModel {
    func later(_ name: TimerName, _ ms: Double, _ fn: @escaping (Self) -> Void) {
        timers.set(name, at: t + ms, fn)
    }

    func cancel(_ names: TimerName...) {
        timers.cancel(names)
    }

    func cancelPrefix(_ prefix: String) {
        timers.cancel(prefix: prefix)
    }

    /// Runs the timers due, soonest first: one an earlier one cancelled or set again doesn't run.
    func runTimers() {
        for timer in timers.due(by: t) where timers.take(timer) {
            timer.fn(self)
        }
    }

    /// The pointer has moved in the last 60ms: its trail still gives it a speed.
    var trailIsFresh: Bool { trail.isFresh(at: now) }

    func trailVelocity() -> Vec { trail.velocity(at: now) }

    /// The pointer's speed toward the edge (below 0: away from it).
    func approachSpeed() -> Double { -trailVelocity().x }

    /// The pointer's speed in any direction.
    func pointerSpeed() -> Double { trailVelocity().length }

    /// The notch's hit area lies over the panel's content, which counts only while the panel is live.
    func hoverOf(_ p: Vec?) -> Hover? {
        guard let p else {
            return nil
        }

        if let lastHit, inRect(p, lastHit) {
            return .lip
        }
        if isLive, let lastPanel, lastPanel.contains(CGPoint(p)) {
            return .panel
        }
        return nil
    }

    /// The pointer's real whereabouts, against the notch and the panel as last drawn.
    func pointerInside() -> Bool { hoverOf(sp) != nil }

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

    /// The head and each item as they land or fade.
    func renderRows() -> (head: Frame.Paint, items: [Frame.Paint]) {
        (paint(revealAlpha(0)), revealOrder.map { paint(revealAlpha($0)) })
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

/// The rows landing as the panel opens, or fading as it closes, since a time on the sim clock.
enum Reveal {
    case none, rowsIn(Double), rowsOut(Double)
}
