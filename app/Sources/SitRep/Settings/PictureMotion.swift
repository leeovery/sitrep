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

/// A picture's motion under the pointer: whether the pointer is over it, where the notch's tongue heads and its tip,
/// and the strip's turn. Each change says how it is eased.
struct HoverMotion: Equatable {
    enum Ease {
        /// As it comes, the tip following the pointer.
        case follow
        /// On the attract spring.
        case out
        /// On the relax spring.
        case home
        /// At once, anything moving stopped where it stands.
        case snap
    }

    let show: EdgeSettings.Show
    private(set) var isOver = false
    /// The reach the tongue heads for.
    private(set) var reach: CGFloat = 0
    private(set) var tip = NotchPicture.drawnTip
    private(set) var turn: StripTurn?
    /// The pointer's height, in units, over the notch's picture, which its tip reaches toward.
    private var pointer: CGFloat?

    init(show: EdgeSettings.Show) {
        self.show = show
    }

    /// The picture as it stands at a time.
    func pose(at time: Date) -> PicturePose {
        var pose = turn?.pose(at: time) ?? .rest

        pose.reach = reach
        pose.tip = tip
        return pose
    }

    /// The pointer over the picture at a height, in units, or gone from it: the motion starts as it comes, the tip
    /// follows it while it stays, and the picture goes home as it leaves.
    mutating func pointer(at height: CGFloat?, time: Date, reducesMotion: Bool) -> Ease {
        guard let height else {
            isOver = false
            reach = 0
            turn = turn?.left(at: time)
            return .home
        }

        if show == .notch {
            pointer = height
        }
        guard isOver else {
            isOver = true
            return enter(at: time, reducesMotion: reducesMotion)
        }
        if show == .notch, PictureHover.moves(show, reducesMotion: reducesMotion) {
            tip = height
        }
        return .follow
    }

    /// Reduce motion turned on, the picture at rest at once; turned off with the pointer over it, the motion starts.
    mutating func motion(reduced reducesMotion: Bool, at time: Date) -> Ease {
        guard !reducesMotion else {
            reach = 0
            turn = nil
            return .snap
        }

        return isOver ? enter(at: time, reducesMotion: false) : .follow
    }

    /// The picture at rest at once, the pointer taken as gone: its window closed, minimised or out of sight, which
    /// may send it no leave.
    mutating func rest() -> Ease {
        self = HoverMotion(show: show)
        return .snap
    }

    /// The arcs faded after the pointer left: the strip at rest, unless the pointer came back as they faded.
    mutating func faded(_ turn: StripTurn) {
        if self.turn == turn {
            self.turn = nil
        }
    }

    /// The tip eases to the pointer with the tongue, which may be still on its way home.
    private mutating func enter(at time: Date, reducesMotion: Bool) -> Ease {
        guard PictureHover.moves(show, reducesMotion: reducesMotion) else {
            return .follow
        }

        switch show {
        case .notch:
            reach = 1
            tip = pointer ?? tip
            return .out
        case .strip:
            turn = turn?.entered(at: time) ?? StripTurn(since: time)
            return .follow
        case .nothing:
            return .follow
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
