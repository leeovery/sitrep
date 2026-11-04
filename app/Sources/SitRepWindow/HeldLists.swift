import Foundation

/// The order the middle list shows its rows in, and the sidebar its projects: `watch`'s, but each held while the
/// pointer is over its column and for a second after it leaves, as the strip holds its marks, so a change shows in
/// place; and held for a second after each pick made in it, so no row moves between two presses of an arrow key. The
/// two columns are held apart, so the pointer over the projects never holds the list, nor the other way. Each place's
/// list is held on its own, Needs you's by its lines, so a line leaving its place leaves the rest where they were. A
/// line new on the board has a key new to the list, so it moves in at once to where `watch` has it, held or not, the
/// rows below sliding.
public struct HeldLists: Equatable, Sendable {
    /// One of the two columns held: the middle list, or the sidebar's projects.
    public enum Column: Sendable {
        case list, projects
    }

    private var lists: [Place: [ListPick]] = [:]
    private var projects: [String] = []
    private var listHold = Hold()
    private var projectsHold = Hold()

    public init() {}

    /// When a column takes `watch`'s order next, a second after the pointer left it or the last pick made in it.
    public var resortsAt: Date? {
        [listHold.endsAt, projectsHold.endsAt].compactMap { $0 }.min()
    }

    /// The board in `watch`'s order, taken: as it is, or, in a column held, into the order it shows, anything new to
    /// it put in at its place in `watch`'s.
    public mutating func take(_ listed: Listed) {
        let core = Self.order(of: listed)

        lists = listHold.isHeld
            ? core.lists.reduce(into: [:]) { held, list in
                held[list.key] = Hold.merge(lists[list.key] ?? [], into: list.value, moving: [])
            }
            : core.lists
        projects = projectsHold.isHeld ? Hold.merge(projects, into: core.projects, moving: []) : core.projects
    }

    /// The pointer came over the column, or left it at this time.
    public mutating func pointer(over column: Column, isIn: Bool, at time: Date) {
        change(column) { $0.pointer(isIn: isIn, at: time) }
    }

    /// A pick made in the column at this time, by a click or an arrow key: held until the second after it runs out,
    /// or, with the pointer over it, for as long as the pointer holds it.
    public mutating func picked(in column: Column, at time: Date) {
        change(column) { $0.picked(at: time) }
    }

    /// The second after the pointer left a column, or after the last pick in it, has run out by this time: it is no
    /// longer held, and the next take gives it `watch`'s order. Whether either ran out now.
    public mutating func settle(at time: Date) -> Bool {
        let list = listHold.settle(at: time)
        let projects = projectsHold.settle(at: time)

        return list || projects
    }

    /// The pointer gone with the columns, as when the window closes under them, which tells no exit: held no more.
    public mutating func release() {
        listHold.release()
        projectsHold.release()
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

    private mutating func change(_ column: Column, _ change: (inout Hold) -> Void) {
        switch column {
        case .list: change(&listHold)
        case .projects: change(&projectsHold)
        }
    }

    /// Each place's rows, its fold's among them, and the projects, in `watch`'s order.
    private static func order(of listed: Listed) -> (lists: [Place: [ListPick]], projects: [String]) {
        let lists = Place.allCases.map { place in (place, PlaceList(place, in: listed, isFoldOpen: true).picks) }

        return (Dictionary(uniqueKeysWithValues: lists), listed.projects.map(\.id))
    }
}

private extension Array {
    /// In the order given, by each element's key; any the order lacks after those it has, as they were.
    func held<Key: Hashable>(by order: [Key], _ key: (Element) -> Key) -> [Element] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }) { first, _ in first }

        return sorted { (rank[key($0)] ?? order.count) < (rank[key($1)] ?? order.count) }
    }
}
