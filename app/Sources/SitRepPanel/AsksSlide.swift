/// The asks panel's asks as they slide (DESIGN, "Paging"), on the run's clock: how far the ask shown stands slid from
/// its place, along the way the scroll goes, so toward the next ask as it grows; and the ask beside it, sliding in or
/// out on that side. Fingers on a trackpad carry it one point for one toward an ask beside, and only a shrinking share
/// of their travel past the first or the last ask (`banded`); on their lift it completes past a third of the way or on
/// a flick toward the ask beside, else springs back. A step, a dot's or a wheel's or a completed swipe's, slides the
/// ask it leaves out of the way and the other in from where they stand. It settles critically damped, taking up the
/// fingers' speed, never past its place; under Reduce motion it never leaves it.
public struct AsksSlide: Sendable {
    /// The fingers' travel at a time on the run's clock, from where the slide stood as they took hold.
    private struct Mark {
        let time: Double
        let travel: Double
    }

    /// Fingers on the trackpad, from where the slide stood as they took hold, and the travel they have come to since.
    private struct Drag {
        let from: Double
        var trail: [Mark] = []

        var travel: Double { trail.last?.travel ?? from }

        mutating func mark(_ travel: Double, at time: Double) {
            trail = (trail + [Mark(time: time, travel: travel)]).suffix(AsksSlide.marks)
        }

        /// Their speed, pt/ms, over the last `speedWindow` before their last mark: none where they rested longer.
        var speed: Double {
            guard let last = trail.last, let first = trail.first else {
                return 0
            }

            let base = trail.last { $0.time <= last.time - AsksSlide.speedWindow } ?? first

            return last.time > base.time ? (last.travel - base.travel) / (last.time - base.time) : 0
        }
    }

    private var spring = Spring(0)
    private var drag: Drag?
    private var clock: Double?
    /// The ask beside the one shown, by its page, on the side it is slid toward; nil at rest, or past the first or
    /// the last ask.
    public private(set) var beside: Int?

    public init() {}

    /// How far, pt, the ask shown stands slid along from its place: toward the next ask as it grows.
    public var offset: Double { spring.x }

    /// Whether it moves: under the fingers, or settling.
    public var isMoving: Bool { isFollowing || !spring.isAtRest }

    /// Whether fingers on the trackpad carry it.
    public var isFollowing: Bool { drag != nil }

    /// How far, pt, one ask slides to the next: the asks panel's width.
    public static let width = AsksLayout.width
    /// How far, pt, toward the ask beside a lift completes its slide past: a third of the way.
    public static let third = width / 3
    /// How fast, pt/ms, a lift's flick toward the ask beside completes its slide, however short.
    public static let flick = 0.5
    /// Its settle: critically damped, as SwiftUI's spring of response 0.3 seconds and damping 1 is, so about 95% of
    /// the way in this long, ms, and within `still` of its place in under half a second from a whole ask away.
    public static let settle = 4.7 * 300 / (2 * Double.pi)
    /// How near its place, pt, and how slow, pt/ms, a settle comes to rest: under half a Retina pixel, and as slow.
    static let still = 0.25, stillSpeed = 0.005
    /// Over how long, ms, a lift's speed is judged, and how many of the fingers' marks are kept for it.
    static let speedWindow = 100.0, marks = 12
    /// How stiff the band is past the first or the last ask: a Mac scroll view's.
    static let band = 0.55

    /// Brought on to this time on the run's clock: settling, the spring moves on; come to rest within `still`, it
    /// snaps to its place, nothing beside it.
    public mutating func run(to time: Double) {
        defer { clock = max(clock ?? time, time) }
        guard drag == nil, let clock, time > clock else {
            return
        }

        spring.step(time - clock)
        if abs(spring.x) < Self.still, abs(spring.v) < Self.stillSpeed {
            rest()
        }
    }

    /// The fingers have travelled this far along since their gesture took hold, the ask shown at `page` of `pages`:
    /// it follows them from where it stood as they took hold, toward the ask beside on that side, never further than
    /// one ask; past the first or the last only a shrinking share of them. Still under Reduce motion.
    public mutating func follow(_ travel: Double, at time: Double, page: Int, of pages: Int, reducesMotion: Bool) {
        var drag = drag ?? Drag(from: Self.unbanded(spring.x, page: page, of: pages))

        drag.mark(drag.from + travel, at: time)
        self.drag = drag

        let slid = reducesMotion ? 0 : Self.banded(drag.travel, page: page, of: pages)

        spring.snap(slid)
        beside = Self.neighbour(of: page, toward: slid, of: pages)
    }

    /// The fingers lifted at this time, the ask shown at `page` of `pages`: the step its slide completes to, 1 to the
    /// next ask or -1 to the previous, past a third of the way to the ask beside or on a flick toward it, for
    /// `slide(from:to:)` to take it there with the fingers' speed; else nil, and it springs back, as on a flick the
    /// other way, or past the first or the last ask.
    public mutating func lift(at time: Double, page: Int, of pages: Int, reducesMotion: Bool) -> Int? {
        guard var drag else {
            return nil
        }

        drag.mark(drag.travel, at: time)
        self.drag = nil

        let slid = Self.banded(drag.travel, page: page, of: pages), way = slid < 0 ? -1 : 1
        let toward = drag.speed * Double(way)

        guard Self.neighbour(of: page, toward: slid, of: pages) != nil else {
            settle(reducesMotion: reducesMotion)
            return nil
        }
        if !reducesMotion {
            spring.v = drag.speed
        }
        if toward > Self.flick || (toward >= -Self.flick && abs(slid) > Self.third) {
            return way
        }

        settle(reducesMotion: reducesMotion)
        return nil
    }

    /// The fingers' gesture cancelled: back to its place.
    public mutating func cancel(reducesMotion: Bool) {
        drag = nil
        settle(reducesMotion: reducesMotion)
    }

    /// Shown from the ask at `from` to the one at `to`: the ask it showed slides out of the way and the other in from
    /// beside it, from where they stand; at once under Reduce motion.
    public mutating func slide(from: Int, to: Int, reducesMotion: Bool) {
        guard from != to else {
            return
        }

        drag = nil
        spring.x -= Double((to - from).signum()) * Self.width
        beside = from
        settle(reducesMotion: reducesMotion)
    }

    /// At rest in its place, nothing beside it.
    public mutating func rest() {
        drag = nil
        spring.snap(0)
        beside = nil
    }

    /// Settling to its place from where it stands, its speed held to what takes it there without passing it.
    private mutating func settle(reducesMotion: Bool) {
        guard !reducesMotion else {
            return rest()
        }

        spring.to(0, Self.settle)
        if spring.v * spring.x < 0 {
            let most = spring.omega * abs(spring.x)

            spring.v = clamp(spring.v, -most, most)
        }
    }

    /// The page beside `page` on the side `slid` goes, while there is one.
    private static func neighbour(of page: Int, toward slid: Double, of pages: Int) -> Int? {
        let beside = page + (slid < 0 ? -1 : 1)

        return slid != 0 && (0 ..< pages).contains(beside) ? beside : nil
    }

    /// How far it slides for the fingers' travel, the ask shown at `page` of `pages`: as far, up to one ask, toward an
    /// ask beside; past the first or the last, a share of it that shrinks as they go, as a Mac scroll view's edge
    /// stretches.
    static func banded(_ travel: Double, page: Int, of pages: Int) -> Double {
        guard neighbour(of: page, toward: travel, of: pages) == nil else {
            return clamp(travel, -width, width)
        }

        let stretched = (1 - 1 / (abs(travel) * band / width + 1)) * width

        return travel < 0 ? -stretched : stretched
    }

    /// The fingers' travel that slides it this far (`banded`), for fingers taking hold of it as it settles.
    static func unbanded(_ slid: Double, page: Int, of pages: Int) -> Double {
        guard neighbour(of: page, toward: slid, of: pages) == nil else {
            return slid
        }

        let travel = width / band * (1 / (1 - min(abs(slid), width - 1) / width) - 1)

        return slid < 0 ? -travel : travel
    }
}
