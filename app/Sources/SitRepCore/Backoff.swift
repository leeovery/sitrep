/// How long to wait before starting `sitrep watch` again: a second after
/// its first end, doubling at each end after, to half a minute at most, so
/// a CLI that cannot start is not started ten times a second. A run that
/// lived a while starts the count again.
struct Backoff {
    static let first: Duration = .seconds(1)
    static let most: Duration = .seconds(30)
    /// A run this long was a working one, not one more failure in a row.
    static let settled: Duration = .seconds(60)

    private var next = first

    /// The wait after a run that lived as long as given.
    mutating func wait(after lived: Duration) -> Duration {
        if lived >= Self.settled {
            next = Self.first
        }

        defer { next = min(next * 2, Self.most) }

        return next
    }
}
