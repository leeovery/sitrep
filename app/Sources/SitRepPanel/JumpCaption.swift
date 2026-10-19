/// The caption a jump from a row leaves, as the prototypes show it: "Jumped to SitRep's window", 90ms after the panel
/// begins to drain, once the jump has answered that it jumped. It fades in over 160ms as it drops 4 into place, holds,
/// and from 1350 rises as it fades, gone by 1600. Times are the view's clock, ms.
public struct JumpCaption: Equatable, Sendable {
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

    /// How it shows this long after it came: how opaque, and how far above its place.
    public static func look(_ elapsed: Double) -> (alpha: Double, lift: Double) {
        let alpha = elapsed < fadeIn ? easeOut(clamp(elapsed / fadeIn, 0, 1))
            : elapsed < fadesFrom ? 1 : 1 - clamp((elapsed - fadesFrom) / fadeOut, 0, 1)

        return (alpha, (1 - alpha) * 4)
    }

    /// How long it shows, ms.
    public static let length = fadesFrom + fadeOut

    static let after = 90.0, fadeIn = 160.0, fadesFrom = 1350.0, fadeOut = 250.0
}
