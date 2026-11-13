/// The panel's sessions as it shows them: the panel's order while the panel is in; while it is out, each row keeps the
/// place it had in its part of the list, Needs you's asks, its turns, Working or Snoozed, so a changed row moves only
/// once the panel closes (DESIGN, "The rows"), each section stays together under its eyebrow, and Needs you's asks
/// above its turns. Core decides the rows, and the panel their order (`inPanelOrder`); this decides only when a new
/// order shows.
public struct HeldRows: Equatable, Sendable {
    public private(set) var shown: [Session] = []
    /// The board's latest, in core's order, which shows once the panel is in.
    private var latest: [Session] = []
    private var holds = false

    public init() {}

    /// The board's sessions, in core's order: whether what shows changed.
    @discardableResult
    public mutating func take(_ sessions: [Session]) -> Bool {
        latest = sessions
        return show(holds ? kept(sessions) : sessions)
    }

    /// Whether the panel is out: from its coming out the rows keep their places, and as it goes in they take core's
    /// order. Whether what shows changed.
    @discardableResult
    public mutating func hold(_ holds: Bool) -> Bool {
        guard holds != self.holds else {
            return false
        }

        self.holds = holds
        return !holds && show(latest)
    }

    private mutating func show(_ sessions: [Session]) -> Bool {
        guard sessions != shown else {
            return false
        }

        shown = sessions
        return true
    }

    /// Each part on its own, in the parts' order: its rows showing, in their places, each as it now is, those gone from
    /// it left out; a row new to it, new to the board or come from another part, in under the row the panel's order
    /// has above it in the part, or at the part's top where it has none there. Each row is known by its key, so a
    /// session's asks and its turn in Snoozed are two rows.
    private func kept(_ sessions: [Session]) -> [Session] {
        let order = Dictionary(grouping: sessions, by: Part.init)
        let held = Dictionary(grouping: shown, by: Part.init)

        return order.keys.sorted().flatMap { part in
            let rows = order[part] ?? []
            let now = Dictionary(rows.map { (Item.key(of: $0), $0) }) { first, _ in first }

            return (held[part] ?? []).compactMap { now[Item.key(of: $0)] }.merging(rows, by: Item.key(of:))
        }
    }

    /// The part of the list a row's place is held in, in their order: its section, and in Needs you its asks, then its
    /// turns. Snoozed's asks and turns are one part, the soonest to wake first.
    struct Part: Hashable, Comparable {
        let section: BoardSection
        let isTurn: Bool

        init(_ session: Session) {
            section = session.section
            isTurn = section == .needsYou && session.isTurn
        }

        static func < (lhs: Part, rhs: Part) -> Bool {
            (lhs.section, lhs.isTurn ? 1 : 0) < (rhs.section, rhs.isTurn ? 1 : 0)
        }
    }
}

extension Array {
    /// These in their order, with each of `others` not among them put in under the nearest one above it in `others`
    /// that is, or first where none is.
    func merging(_ others: [Element], by key: (Element) -> String) -> [Element] {
        var merged = self
        var placed = Set(map(key))

        for (index, other) in others.enumerated() where !placed.contains(key(other)) {
            let above = others[..<index].last { placed.contains(key($0)) }.map(key)
            let at = above.flatMap { above in merged.firstIndex { key($0) == above } }.map { $0 + 1 } ?? 0

            merged.insert(other, at: at)
            placed.insert(key(other))
        }

        return merged
    }
}
