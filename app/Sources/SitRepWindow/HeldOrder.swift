import Foundation

/// The order the board's list shows its projects and sessions in: `watch`'s, but held while the pointer is over the
/// list or the keyboard is in it, and for a second after the last of them leaves, as the strip holds its marks, so a
/// change shows in place and no row moves between two presses of an arrow key. A session new to needing Lee moves in
/// at once, to where `watch` has it, its project with it, the rows below sliding.
public struct HeldOrder: Equatable, Sendable {
    /// What holds the list: the pointer over it, the keyboard's focus in it.
    public enum Holder: Hashable, Sendable {
        case pointer, keyboard
    }

    /// How long after the last holder leaves the list it takes `watch`'s order.
    public static let settle: TimeInterval = 1

    private var projects: [String] = []
    private var sessions: [String: [String]] = [:]
    private var holders: Set<Holder> = []
    /// When the list takes `watch`'s order, a second after the last holder left it.
    public private(set) var resortsAt: Date?

    public init() {}

    /// Held, while anything holds the list and until the second after the last leaves runs out.
    var isHeld: Bool { !holders.isEmpty || resortsAt != nil }

    /// The list in the order it shows, after taking this one: `watch`'s, or while held the order it showed, the
    /// sessions moving in at their places in `watch`'s, as anything new to the list does.
    public mutating func take(_ listed: Listed, moving: Set<String>) -> Listed {
        let core = Self.order(of: listed)
        let movingProjects = Set(listed.projects.filter { $0.sessions.contains { moving.contains($0.id) } }.map(\.id))

        if isHeld {
            projects = Self.merge(projects, into: core.projects, moving: movingProjects)
            sessions = core.sessions.reduce(into: [:]) { held, project in
                held[project.key] = Self.merge(sessions[project.key] ?? [], into: project.value, moving: moving)
            }
        } else {
            (projects, sessions) = core
        }
        return arranged(listed)
    }

    /// The pointer came over the list, or left it at this time.
    public mutating func pointer(isIn: Bool, at time: Date) {
        hold(.pointer, isIn: isIn, at: time)
    }

    /// The keyboard's focus came into the list, or left it at this time.
    public mutating func keyboard(isIn: Bool, at time: Date) {
        hold(.keyboard, isIn: isIn, at: time)
    }

    private mutating func hold(_ holder: Holder, isIn: Bool, at time: Date) {
        guard isIn != holders.contains(holder) else {
            return
        }

        if isIn {
            holders.insert(holder)
            resortsAt = nil
        } else {
            holders.remove(holder)
            resortsAt = holders.isEmpty ? time.addingTimeInterval(Self.settle) : nil
        }
    }

    /// The second after the last holder left has run out by this time: the list is no longer held, and the next
    /// take gives `watch`'s order. Whether it ran out now.
    public mutating func settle(at time: Date) -> Bool {
        guard let due = resortsAt, time >= due, holders.isEmpty else {
            return false
        }

        resortsAt = nil
        return true
    }

    /// The pointer and the keyboard gone with the list, as when the window closes under them, which tells no exit:
    /// held no more.
    public mutating func release() {
        holders = []
        resortsAt = nil
    }

    /// The list in the order held.
    func arranged(_ listed: Listed) -> Listed {
        var arranged = listed

        arranged.projects = listed.projects.sorted(by: projects).map { project in
            var project = project

            project.sessions = project.sessions.sorted(by: sessions[project.id] ?? [])
            return project
        }
        return arranged
    }

    private static func order(of listed: Listed) -> (projects: [String], sessions: [String: [String]]) {
        (
            listed.projects.map(\.id),
            Dictionary(listed.projects.map { ($0.id, $0.sessions.map(\.id)) }) { first, _ in first }
        )
    }

    /// The held order with what `watch` no longer has gone, and what is moving or new to it put where `watch` has
    /// it: after the nearest of those `watch` has before it that the list already holds.
    static func merge(_ held: [String], into core: [String], moving: Set<String>) -> [String] {
        let kept = Set(core)
        var merged = held.filter { kept.contains($0) && !moving.contains($0) }

        for (place, key) in core.enumerated() where !merged.contains(key) {
            let after = core[..<place].last(where: merged.contains).flatMap(merged.firstIndex(of:))

            merged.insert(key, at: after.map { $0 + 1 } ?? 0)
        }
        return merged
    }
}

private extension Array where Element: Identifiable, Element.ID == String {
    /// In the order of these ids, which name every element: the order taken from this very list.
    func sorted(by order: [String]) -> [Element] {
        let byID = Dictionary(map { ($0.id, $0) }) { first, _ in first }

        return order.compactMap { byID[$0] }
    }
}
