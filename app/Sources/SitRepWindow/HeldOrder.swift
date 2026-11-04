import Foundation
import SitRepPanel

/// The order the board's list shows its rows and its projects in: `watch`'s, but held while the pointer is over the
/// list and for a second after it leaves, as the strip holds its marks, so a change shows in place; and held for a
/// second after each pick made in the list, so no row moves between two presses of an arrow key. Each section is held
/// on its own, as the card holds them, so a row changing section leaves its held place and takes its place in its new
/// one, where `watch` has it; a session new to needing Lee moves in at once, to where `watch` has it, the rows below
/// sliding. Projects is held alike.
public struct HeldOrder: Equatable, Sendable {
    private var sections: [BoardSection: [String]] = [:]
    private var projects: [String] = []
    private var hold = Hold()

    public init() {}

    /// When the list takes `watch`'s order, a second after the pointer left it or the last pick made in it.
    public var resortsAt: Date? { hold.endsAt }

    /// The list in the order it shows, after taking this one: `watch`'s, or while held the order it showed, the
    /// sessions moving in at their places in `watch`'s, as anything new to the list does.
    public mutating func take(_ listed: Listed, moving: Set<String>) -> Listed {
        let core = Self.order(of: listed)

        if hold.isHeld {
            sections = core.sections.reduce(into: [:]) { held, section in
                held[section.key] = HeldLists.merge(sections[section.key] ?? [], into: section.value, moving: moving)
            }
            projects = HeldLists.merge(projects, into: core.projects, moving: [])
        } else {
            (sections, projects) = core
        }
        return arranged(listed)
    }

    /// The pointer came over the list, or left it at this time.
    public mutating func pointer(isIn: Bool, at time: Date) {
        hold.pointer(isIn: isIn, at: time)
    }

    /// A pick made in the list at this time, by a click or an arrow key: held until the second after it runs out,
    /// or, with the pointer over the list, for as long as the pointer holds it.
    public mutating func picked(at time: Date) {
        hold.picked(at: time)
    }

    /// The second after the pointer left, or after the last pick, has run out by this time: the list is no longer
    /// held, and the next take gives `watch`'s order. Whether it ran out now.
    public mutating func settle(at time: Date) -> Bool {
        hold.settle(at: time)
    }

    /// The pointer gone with the list, as when the window closes under it, which tells no exit: held no more.
    public mutating func release() {
        hold.release()
    }

    /// The list in the order held.
    func arranged(_ listed: Listed) -> Listed {
        var arranged = listed

        arranged.rows = BoardSection.allCases.flatMap { section in
            listed.rows(in: section).sorted(by: sections[section] ?? [])
        }
        arranged.projects = listed.projects.sorted(by: projects)
        return arranged
    }

    private static func order(of listed: Listed) -> (sections: [BoardSection: [String]], projects: [String]) {
        (
            Dictionary(uniqueKeysWithValues: BoardSection.allCases.map { ($0, listed.rows(in: $0).map(\.id)) }),
            listed.projects.map(\.id)
        )
    }
}

private extension Array where Element: Identifiable, Element.ID == String {
    /// In the order of these ids, which name every element: the order taken from this very list.
    func sorted(by order: [String]) -> [Element] {
        let byID = Dictionary(map { ($0.id, $0) }) { first, _ in first }

        return order.compactMap { byID[$0] }
    }
}
