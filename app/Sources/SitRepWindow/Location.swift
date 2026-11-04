/// What a place's list has picked: the row's pick, and the session it shows, kept as the row leaves the list, so the
/// page beside it stays on the session, as when the picked ask is answered.
public struct Selection: Hashable, Sendable {
    public let pick: ListPick
    public let session: String

    public init(pick: ListPick, session: String) {
        self.pick = pick
        self.session = session
    }
}

/// What Parked's list narrows to: every item, a project's, or a session's.
public enum ParkedScope: Hashable, Sendable {
    case all
    case project(String)
    case session(String)
}

/// What the sidebar shows picked: a place, or a project.
public enum Root: Hashable, Sendable {
    case place(Place)
    case project(String)
}

/// Where the window is: a place, with its list and what the list has picked, Parked's narrowed to a scope; a project's
/// page; or a session's page, pushed from a place or a project, which stays picked in the sidebar.
public enum Location: Hashable, Sendable {
    case place(Place, picked: Selection? = nil, scope: ParkedScope = .all)
    case project(String)
    case session(String, from: Root)

    /// What the sidebar shows picked.
    public var root: Root {
        switch self {
        case let .place(place, _, _): .place(place)
        case let .project(key): .project(key)
        case let .session(_, root): root
        }
    }

    /// The place whose list shows beside the page; none for a project's page or a session's, which fill the window.
    public var place: Place? {
        if case let .place(place, _, _) = self {
            return place
        }
        return nil
    }

    /// What the place's list has picked.
    public var picked: Selection? {
        if case let .place(_, picked, _) = self {
            return picked
        }
        return nil
    }

    /// The same place with the list's selection changed: what a change within the list makes it, replacing it in the
    /// history. A page with no list stays as it is.
    public func picking(_ selection: Selection?) -> Location {
        if case let .place(place, _, scope) = self {
            return .place(place, picked: selection, scope: scope)
        }
        return self
    }

    /// The sessions the window follows here: the picked row's, whether a line, a session's row or a parked item, and
    /// still as the row leaves the list; every session of a project; a session pushed.
    public func following(on listed: Listed) -> Set<String> {
        switch self {
        case let .place(_, picked, _): Set(picked.map { [$0.session] } ?? [])
        case let .project(key): Set(listed.homes.filter { $0.value == key }.keys)
        case let .session(id, _): [id]
        }
    }

    /// Where the window stays on this board, the location as it is wherever it stands on it, as a place does whatever
    /// leaves its list: a selection whose session left the board drops, as does a scope whose project or session did;
    /// a session's page whose session left gives way to where it was pushed from. None where the project left: the
    /// window opens afresh (`opening(on:remembered:)`).
    public func kept(on listed: Listed) -> Location? {
        switch self {
        case let .place(place, picked, scope):
            let picked = picked.flatMap { listed.has($0.session) ? $0 : nil }

            return .place(place, picked: picked, scope: scope.kept(on: listed))
        case let .project(key):
            return listed.projects.contains { $0.id == key } ? self : nil
        case let .session(id, root):
            return listed.has(id) ? self : root.location.kept(on: listed)
        }
    }

    /// Where the window opens on this board: Needs you, its first line picked; with none, where it was left, as it
    /// stands on the board now; else Needs you, nothing picked.
    public static func opening(on listed: Listed, remembered: Location?) -> Location {
        if let first = PlaceList(.needsYou, in: listed).rows.first {
            return .place(.needsYou, picked: first.selection)
        }
        return remembered?.kept(on: listed) ?? .place(.needsYou)
    }

    /// Where an open of a session from outside the window lands, as "Open in SitRep" on its card or the menu: Needs
    /// you, its oldest line picked, where it needs Lee; else Working or Your turn, its row picked; else its project's
    /// page, the session's pushed over it. None for a session the board does not have.
    public static func opening(session id: String, on listed: Listed) -> Location? {
        guard let project = listed.homes[id] else {
            return nil
        }

        let row = listed.rows.first { $0.id == id && $0.section != .snoozed }
        guard let row, let place = Place.allCases.first(where: { $0.section == row.section }) else {
            return .session(id, from: .project(project))
        }

        let pick: ListPick = place == .needsYou ? .line(row.lines[0].id) : .session(id)

        return .place(place, picked: Selection(pick: pick, session: id))
    }
}

extension Root {
    /// The location it opens on its own: the place with nothing picked, or the project's page.
    var location: Location {
        switch self {
        case let .place(place): .place(place)
        case let .project(key): .project(key)
        }
    }
}

private extension ParkedScope {
    /// As it stands on this board: all, where its project or its session left it.
    func kept(on listed: Listed) -> ParkedScope {
        switch self {
        case .all: .all
        case let .project(key): listed.projects.contains { $0.id == key } ? self : .all
        case let .session(id): listed.has(id) ? self : .all
        }
    }
}

extension Listed {
    /// The board has the session.
    func has(_ session: String) -> Bool {
        homes[session] != nil
    }
}
