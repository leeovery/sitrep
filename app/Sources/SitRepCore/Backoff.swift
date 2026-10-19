/// How long to wait before starting `sitrep watch` again: a second after
/// its first end, doubling at each end after, to half a minute at most, so
/// a CLI that cannot start is not started ten times a second. A run that
/// lived a while starts the count again; one that made way for a new
/// version is followed at once.
struct Backoff {
    static let first: Duration = .seconds(1)
    static let most: Duration = .seconds(30)
    /// A run this long was a working one, not one more failure in a row.
    static let settled: Duration = .seconds(60)
    /// A run that exits 0 sooner was failing, not making way for a new version.
    static let renewing: Duration = .seconds(1)

    private var next = first

    /// Whether a run that ended so made way for a new version of itself:
    /// `watch` exits 0, unasked, once its plugin's version moves under it, so
    /// the app runs the new code. One exiting 0 at once counts as a failure,
    /// so a `watch` that keeps exiting cannot spin.
    static func renews(status: Int32, lived: Duration) -> Bool {
        status == 0 && lived >= renewing
    }

    /// A run made way for a new version: the next starts at once, and the count starts again.
    mutating func renew() {
        next = Self.first
    }

    /// The wait after a run that lived as long as given.
    mutating func wait(after lived: Duration) -> Duration {
        if lived >= Self.settled {
            next = Self.first
        }

        defer { next = min(next * 2, Self.most) }

        return next
    }
}
