import Foundation
import SitRepPanel
import SwiftUI

/// What a pointer over a picture does: the notch's and the strip's move, unless motion is reduced, and Nothing has
/// nothing to move; a tile not chosen lifts its hairline, always.
enum PictureHover {
    static func moves(_ show: EdgeSettings.Show, reducesMotion: Bool) -> Bool {
        show != .nothing && !reducesMotion
    }

    /// The white of a tile's hairline, `#FFFFFF26`, lifted to `#FFFFFF4D` under the pointer.
    static func hairline(isOver: Bool) -> Double {
        isOver ? 0.3 : 0.15
    }
}

/// The notch's tongue: the springs it reaches and goes home on, and its outline by reach.
extension NotchPicture {
    /// Out on the meniscus's attract spring, in about 0.3 s; home on its relax spring, in about 0.6 s, overshooting.
    static let out = Spring(response: 0.20, dampingRatio: 0.75)
    static let home = Spring(response: 0.45, dampingRatio: 0.55)

    /// The crest's straight run at rest, down the notch's outer edge, which the tongue reaches out of.
    static let crestX: CGFloat = 9
    static let crest: ClosedRange<CGFloat> = 37.9 ... 49.1

    /// The least height each flank keeps between the crest's end and the cap, however far the tip is moved.
    static let leastFlank: CGFloat = 2

    /// The filmstrip's tongue part way, its 0.1 s frame, the tip about 3.3 past the crest: half the full reach.
    static let partWay: [CGPoint] = [
        CGPoint(x: 9.8, y: 40.3), CGPoint(x: 11.4, y: 42), CGPoint(x: 12, y: 42.9),
        CGPoint(x: 12.4, y: 43.5), CGPoint(x: 12.4, y: 44.1), CGPoint(x: 12, y: 44.7),
        CGPoint(x: 11.4, y: 45.6), CGPoint(x: 9.8, y: 47.1),
    ]
    /// The filmstrip's tongue at full reach, its 0.3 s frame.
    static let fullReach: [CGPoint] = [
        CGPoint(x: 10.2, y: 40.5), CGPoint(x: 13.9, y: 42.4), CGPoint(x: 15, y: 43.2),
        CGPoint(x: 15.7, y: 43.7), CGPoint(x: 15.7, y: 44.5), CGPoint(x: 15, y: 45),
        CGPoint(x: 13.9, y: 45.8), CGPoint(x: 10.2, y: 47.2),
    ]

    /// The tongue's stages by reach: home, flat on the crest; part way; full.
    private static let stages: [(reach: CGFloat, tongue: [CGPoint])] = [
        (0, partWay.map { CGPoint(x: crestX, y: $0.y) }), (0.5, partWay), (1, fullReach),
    ]

    /// The tongue, the points between the crest's ends: each of its three curves' two controls and its end, down the
    /// upper flank, round the tip's cap and back up the lower flank. At a reach, from stage to stage, and past home or full as a spring overshoots; its tip at `tip`, the
    /// stage's own where nil.
    static func tongue(reach: CGFloat, tip: CGFloat? = nil) -> [CGPoint] {
        let (from, to) = reach < stages[1].reach ? (stages[0], stages[1]) : (stages[1], stages[2])
        let amount = (reach - from.reach) / (to.reach - from.reach)
        let tongue = zip(from.tongue, to.tongue).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * amount, y: a.y + (b.y - a.y) * amount)
        }

        return tip.map { placed(tongue, tip: $0) } ?? tongue
    }

    /// The tongue with its tip at a height, held inside the crest so each flank keeps `leastFlank`: the cap moved whole,
    /// each flank stretched between the crest's end and the cap, so it stays as concave as drawn.
    private static func placed(_ tongue: [CGPoint], tip: CGFloat) -> [CGPoint] {
        let (capTop, capBottom) = (tongue[2].y, tongue[5].y)
        let drawn = (capTop + capBottom) / 2
        let held = (crest.lowerBound + leastFlank + drawn - capTop) ... (crest.upperBound - leastFlank - (capBottom - drawn))
        let shift = min(max(tip, held.lowerBound), held.upperBound) - drawn
        let upper = (capTop + shift - crest.lowerBound) / (capTop - crest.lowerBound)
        let lower = (crest.upperBound - capBottom - shift) / (crest.upperBound - capBottom)

        return tongue.enumerated().map { index, point in
            switch index {
            case 0 ..< 2: CGPoint(x: point.x, y: crest.lowerBound + (point.y - crest.lowerBound) * upper)
            case 2 ..< 6: CGPoint(x: point.x, y: point.y + shift)
            default: CGPoint(x: point.x, y: crest.upperBound - (crest.upperBound - point.y) * lower)
            }
        }
    }
}

/// The strip's rings turning under the pointer, from when it came over the picture: each ring dims to its track and
/// its colour turns round it as a working arc does, a turn in 1.2 s, each ring 0.1 s behind the one above; the turning
/// look fades in as the pointer comes and out as it goes, over the strip's own 0.24 s.
struct StripTurn: Equatable {
    static let turn: TimeInterval = 1.2
    static let stagger: TimeInterval = 0.1
    static let fade: TimeInterval = 0.24

    /// When the pointer came over the picture, which the arcs turn from.
    let since: Date
    /// The turning look's last change of course.
    private var fading: Fading

    private struct Fading: Equatable {
        let at: Date
        /// How far turned it was then.
        let from: Double
        /// Toward turning, else toward rest.
        let isIn: Bool
    }

    init(since: Date) {
        self.since = since
        fading = Fading(at: since, from: 0, isIn: true)
    }

    /// The strip's rings as they stand at a time.
    func pose(at time: Date) -> PicturePose {
        PicturePose(turning: turning(at: time), arcs: arcs(at: time))
    }

    /// How far the rings are from their rest look to turning: 0 at rest, 1 turning.
    func turning(at time: Date) -> Double {
        let faded = time.timeIntervalSince(fading.at) / Self.fade

        return min(max(fading.isIn ? fading.from + faded : fading.from - faded, 0), 1)
    }

    /// Where each of the strip's rings' turning arcs starts, top to bottom, in degrees clockwise from 12 o'clock: at 12
    /// until its turn starts.
    func arcs(at time: Date) -> [Double] {
        let elapsed = time.timeIntervalSince(since)

        return StripPicture.rings.indices.map { ring in
            (max(elapsed - Self.stagger * Double(ring), 0) / Self.turn * 360).truncatingRemainder(dividingBy: 360)
        }
    }

    /// The pointer back over the picture before the arcs had faded: they fade in again from where they are, still
    /// turning.
    func entered(at time: Date) -> StripTurn {
        changing(at: time, isIn: true)
    }

    func left(at time: Date) -> StripTurn {
        changing(at: time, isIn: false)
    }

    private func changing(at time: Date, isIn: Bool) -> StripTurn {
        var turn = self

        turn.fading = Fading(at: time, from: turning(at: time), isIn: isIn)
        return turn
    }

    /// When the arcs will have faded once the pointer has left; nil while it stays.
    var faded: Date? {
        fading.isIn ? nil : fading.at.addingTimeInterval(fading.from * Self.fade)
    }
}
