import Foundation

/// The order the middle list shows its rows in, and the sidebar its projects: `watch`'s, but held while the pointer is
/// over them and for a second after it leaves, as the strip holds its marks, so a change shows in place; and held for a
/// second after each pick made in the list, so no row moves between two presses of an arrow key. Each place's list is
/// held on its own, Needs you's by its lines, so a line leaving its place leaves the rest where they were; a line new
/// to needing Lee moves in at once, to where `watch` has it, the rows below sliding. The projects are held alike.
public struct HeldLists: Equatable, Sendable {
    private var lists: [Place: [ListPick]] = [:]
    private var projects: [String] = []
    private var hold = Hold()

    public init() {}

    /// When the lists take `watch`'s order, a second after the pointer left them or the last pick made in them.
    public var resortsAt: Date? { hold.endsAt }

    /// The board in `watch`'s order, taken: as it is, or while held into the order shown, the lines moving, by their
    /// keys, put in at their places in `watch`'s, as anything new to a list is.
    public mutating func take(_ listed: Listed, moving: Set<String>) {
        let core = Self.order(of: listed)

        if hold.isHeld {
            let moving = Set(moving.map(ListPick.line))

            lists = core.lists.reduce(into: [:]) { held, list in
                held[list.key] = Self.merge(lists[list.key] ?? [], into: list.value, moving: moving)
            }
            projects = Self.merge(projects, into: core.projects, moving: [])
        } else {
            (lists, projects) = core
        }
    }

    /// The pointer came over the lists, or left them at this time.
    public mutating func pointer(isIn: Bool, at time: Date) {
        hold.pointer(isIn: isIn, at: time)
    }

    /// A pick made in the list at this time, by a click or an arrow key: held until the second after it runs out, or,
    /// with the pointer over the lists, for as long as the pointer holds them.
    public mutating func picked(at time: Date) {
        hold.picked(at: time)
    }

    /// The second after the pointer left, or after the last pick, has run out by this time: the lists are no longer
    /// held, and the next take gives `watch`'s order. Whether it ran out now.
    public mutating func settle(at time: Date) -> Bool {
        hold.settle(at: time)
    }

    /// The pointer gone with the lists, as when the window closes under them, which tells no exit: held no more.
    public mutating func release() {
        hold.release()
    }

    /// The place's list in the order held, its fold's rows too.
    public func arranged(_ list: PlaceList) -> PlaceList {
        let order = lists[list.place] ?? []
        var arranged = list

        arranged.rows = list.rows.held(by: order, \.pick)
        if let folded = list.fold?.rows {
            arranged.fold?.rows = folded.held(by: order, \.pick)
        }
        return arranged
    }

    /// The sidebar with its projects in the order held.
    public func arranged(_ places: Places) -> Places {
        var arranged = places

        arranged.projects = places.projects.held(by: projects, \.id)
        return arranged
    }

    /// Each place's rows, its fold's among them, and the projects, in `watch`'s order.
    private static func order(of listed: Listed) -> (lists: [Place: [ListPick]], projects: [String]) {
        let lists = Place.allCases.map { place in (place, PlaceList(place, in: listed, isFoldOpen: true).picks) }

        return (Dictionary(uniqueKeysWithValues: lists), listed.projects.map(\.id))
    }

    /// The held order with what `watch` no longer has gone, and what is moving or new to it put where `watch` has
    /// it: after the nearest of those `watch` has before it that the list already holds.
    static func merge<Key: Hashable>(_ held: [Key], into core: [Key], moving: Set<Key>) -> [Key] {
        let kept = Set(core)
        var merged = held.filter { kept.contains($0) && !moving.contains($0) }

        for (place, key) in core.enumerated() where !merged.contains(key) {
            let after = core[..<place].last(where: merged.contains).flatMap(merged.firstIndex(of:))

            merged.insert(key, at: after.map { $0 + 1 } ?? 0)
        }
        return merged
    }
}

private extension Array {
    /// In the order given, by each element's key; any the order lacks after those it has, as they were.
    func held<Key: Hashable>(by order: [Key], _ key: (Element) -> Key) -> [Element] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }) { first, _ in first }

        return sorted { (rank[key($0)] ?? order.count) < (rank[key($1)] ?? order.count) }
    }
}
