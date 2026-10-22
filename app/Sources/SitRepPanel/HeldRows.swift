/// The panel's sessions as it shows them: core's order while the panel is in; while it is out, each row keeps the
/// place it had in its section, Needs you, Working or Your turn, so a changed row moves only once the panel closes
/// (DESIGN, "The rows"), and each section stays together under its eyebrow. Core decides the rows and their order;
/// this decides only when a new order shows.
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

    /// Each section on its own, in the sections' order: its rows showing, in their places, each as it now is, those
    /// gone from it left out; a row new to it, new to the board or come from another section, in under the row core
    /// has above it in the section, or at the section's top where core has none there.
    private func kept(_ sessions: [Session]) -> [Session] {
        let core = Dictionary(grouping: sessions, by: Self.section)
        let held = Dictionary(grouping: shown, by: Self.section)

        return core.keys.sorted().flatMap { section in
            let rows = core[section] ?? []
            let now = Dictionary(rows.map { ($0.id, $0) }) { first, _ in first }

            return (held[section] ?? []).compactMap { now[$0.id] }.merging(rows, by: \.id)
        }
    }

    /// The section a row's place is held in, by the sections' order: Needs you, Working, Your turn.
    static func section(_ session: Session) -> BoardSection {
        session.section
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
