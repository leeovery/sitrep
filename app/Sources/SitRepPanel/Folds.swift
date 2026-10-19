/// The panel's list as it folds, the prototypes' `syncList` and `stepItems`: while the panel is out, an item new to it
/// unfolds from nothing and fades in, one gone from it folds away where it was, fading as it folds, and one coming
/// back unfolds again; while the panel is in, a change shows at once. Times are the view's clock, ms.
public struct Folds: Equatable, Sendable {
    private var folds: [Fold] = []

    public init() {}

    /// The list as it stands now, in its order, with any item folding away kept where it was.
    public mutating func take(_ items: [Item], at time: Double, animating: Bool, reducesMotion: Bool) {
        guard animating else {
            folds = items.map { Fold(item: $0) }
            return
        }

        let duration = reducesMotion ? Self.reducedFor : Self.foldFor
        let was = Dictionary(folds.map { ($0.item.key, $0) }) { first, _ in first }
        let live = Set(items.map(\.key))

        folds = items.merging(folds.map(\.item), by: \.key).map { item in
            guard var fold = was[item.key] else {
                return Fold(born: item, at: time, duration, fades: !reducesMotion)
            }

            fold.item = item
            fold.fold(to: live.contains(item.key) ? 1 : 0, at: time, duration)
            return fold
        }
    }

    /// The list at this time, each item at its folded height and fade. An item folded all the way away is gone from
    /// here on.
    public mutating func content(at time: Double) -> Content {
        folds.removeAll { $0.isGoing && !$0.isFolding(at: time) }
        return Content(headHeight: Content.headHeight, entries: folds.map { $0.entry(at: time) })
    }

    /// Whether anything still folds or fades in at this time: frames must keep coming until it is done.
    public func isMoving(at time: Double) -> Bool {
        folds.contains { $0.isFolding(at: time) || $0.fadeIn(at: time) < 1 }
    }

    static let foldFor = 260.0, reducedFor = 120.0, fadeInFor = 220.0

    /// One item and its fold, from 0, folded away, to 1, its full height.
    private struct Fold: Equatable, Sendable {
        var item: Item
        var from = 1.0, to = 1.0
        /// When the fold toward `to` began, and how long it takes.
        var t0: Double?
        var duration = 0.0
        /// When it came, which it fades in from; nil when it came with the list.
        var born: Double?

        init(item: Item) {
            self.item = item
        }

        init(born item: Item, at time: Double, _ duration: Double, fades: Bool) {
            self.item = item
            from = 0
            t0 = time
            self.duration = duration
            born = fades ? time : nil
        }

        /// Folding away: gone from the board, it takes no click.
        var isGoing: Bool { to == 0 }

        func fold(at time: Double) -> Double {
            guard let t0 else {
                return to
            }

            return lerp(from, to, easeInOut(clamp((time - t0) / duration, 0, 1)))
        }

        mutating func fold(to target: Double, at time: Double, _ duration: Double) {
            guard target != to else {
                return
            }

            from = fold(at: time)
            to = target
            t0 = time
            self.duration = duration
        }

        func isFolding(at time: Double) -> Bool {
            t0.map { time - $0 < duration } ?? false
        }

        func fadeIn(at time: Double) -> Double {
            born.map { easeOut(clamp((time - $0) / Folds.fadeInFor, 0, 1)) } ?? 1
        }

        func entry(at time: Double) -> Content.Entry {
            let share = fold(at: time)

            return Content.Entry(
                item, height: item.height * share, alpha: fadeIn(at: time) * (isGoing ? share : 1), isGoing: isGoing
            )
        }
    }
}
