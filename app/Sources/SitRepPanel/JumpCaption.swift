import Foundation

/// The caption a jump from a row leaves, as the prototypes show it: "Jumped to SitRep's window", 90ms after the panel
/// begins to drain, once the jump has answered that it jumped. It fades in over 160ms as it drops 4 into place, holds,
/// and from 1350 rises as it fades, gone by 1600. Times are the view's clock, ms.
///
/// A jump from anywhere that runs on with no answer says so in the same place and look (4 November 2026): `still`, held
/// until it ends, and `tooBusy` once it gives up at its limit.
public struct JumpCaption: Equatable, Sendable {
    /// A jump with no answer yet, two seconds on: it fades in as a caption does, and holds until the jump ends.
    public static let still = "Still jumping…"
    /// A jump that gave no answer within its limit, played as a caption is.
    public static let tooBusy = "Couldn't jump: the Mac is too busy."

    /// How a jump landed: on the session's window; on a window it opened for the session, no window showing it; or on
    /// one opened for it a moment ago, which does not show it yet.
    public enum Landing: Equatable, Sendable {
        case jumped, opened, opening
    }

    private let project: String
    private var landing = Landing.jumped
    private var drained: Double?
    private var jumped: Double?

    /// For a jump to a session on this project.
    public init(to project: String) {
        self.project = project
    }

    /// What it says, as the jump landed: "Jumped to SitRep's window" until it says otherwise.
    public var text: String {
        switch landing {
        case .jumped: "Jumped to \(project)'s window"
        case .opened: "Opened a window for \(project)"
        case .opening: "A window for \(project) is opening"
        }
    }

    /// The panel began to drain.
    public mutating func drained(at time: Double) {
        drained = drained ?? time
    }

    /// The jump answered that it jumped.
    public mutating func jumped(at time: Double) {
        landed(.jumped, at: time)
    }

    /// The jump answered how it landed.
    public mutating func landed(_ landing: Landing, at time: Double) {
        if jumped == nil {
            self.landing = landing
        }
        jumped = jumped ?? time
    }

    /// When it shows, once the panel drains and the jump has jumped.
    public var showsAt: Double? {
        guard let drained, let jumped else {
            return nil
        }

        return max(drained + Self.after, jumped)
    }

    /// How long from now until it shows: nil until it knows when, and nil once that moment is past by more than
    /// `late`, so it never shows after its time.
    public func showsIn(at now: Double) -> Double? {
        showsAt.flatMap { at in now - at > Self.late ? nil : max(0, at - now) }
    }

    /// How late it may still show: a frame or two.
    static let late = 50.0

    /// How it shows this long after it came: how opaque, and how far above its place.
    public static func look(_ elapsed: Double) -> (alpha: Double, lift: Double) {
        let alpha = elapsed < fadeIn ? easeOut(clamp(elapsed / fadeIn, 0, 1))
            : elapsed < fadesFrom ? 1 : 1 - clamp((elapsed - fadesFrom) / fadeOut, 0, 1)

        return (alpha, (1 - alpha) * 4)
    }

    /// How long it shows, ms.
    public static let length = fadesFrom + fadeOut

    /// The part of its look a caption plays, ms, over a pill already this opaque: from the moment its coming in is that
    /// opaque, so taking the place of a caption coming in, holding or going it never jumps, to its end, or, held until
    /// its jump ends, to its hold.
    public static func part(holding: Bool, from alpha: Double) -> ClosedRange<Double> {
        fadeIn * (1 - pow(1 - clamp(alpha, 0, 1), 1.0 / 3)) ... (holding ? fadeIn : length)
    }

    /// The part of its look a held caption plays as it goes, from the opacity it has: it rises as it fades, as a
    /// caption ends, from wherever its coming in had got to.
    public static func going(from alpha: Double) -> ClosedRange<Double> {
        fadesFrom + (1 - clamp(alpha, 0, 1)) * fadeOut ... length
    }

    static let after = 90.0, fadeIn = 160.0, fadesFrom = 1350.0, fadeOut = 250.0
}
