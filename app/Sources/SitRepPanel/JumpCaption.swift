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
    public static let tooBusy = "Couldn't jump: the Mac is too busy to reach Ghostty."

    public let text: String
    private var drained: Double?
    private var jumped: Double?

    /// For a jump to a session on this project.
    public init(to project: String) {
        text = "Jumped to \(project)'s window"
    }

    /// The panel began to drain.
    public mutating func drained(at time: Double) {
        drained = drained ?? time
    }

    /// The jump answered that it jumped.
    public mutating func jumped(at time: Double) {
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

    /// The part of its look a caption plays, ms: all of it, or, held until its jump ends, only its coming in; from its
    /// hold where it takes the place of one showing, so the pill never blinks out between them.
    public static func part(holding: Bool, inPlaceOfOne isShowing: Bool) -> ClosedRange<Double> {
        (isShowing ? fadeIn : 0) ... (holding ? fadeIn : length)
    }

    /// The part of its look a held caption plays as it goes: it rises as it fades, as a caption ends.
    public static let going = fadesFrom ... length

    static let after = 90.0, fadeIn = 160.0, fadesFrom = 1350.0, fadeOut = 250.0
}
