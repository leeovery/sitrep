/// What a place's list has picked: the row's pick, and the session it shows, kept as the row leaves the list, so the
/// page beside it stays on the session, as when the picked ask is answered; and where the row last stood in the list,
/// so ↑ and ↓ go on from there, Back returning to it as it was. One comes only from a list
/// (`PlaceList.selection(of:)`, `step(from:down:)`), so it always stands somewhere.
public struct Selection: Hashable, Codable, Sendable {
    public let pick: ListPick
    public let session: String
    /// The rows above the pick as the list last showed it, the nearest last. Where it stands, not what it is: no part
    /// of what it equals, and not kept across launches, as the list it stood in is gone by then.
    private var above: [ListPick] = []

    init(pick: ListPick, session: String) {
        self.pick = pick
        self.session = session
    }

    /// Standing where the list shows its pick; where the list shows it nowhere, where it last stood.
    public func standing(in list: PlaceList) -> Selection {
        let picks = list.picks
        var standing = self

        if let at = picks.firstIndex(of: pick) {
            standing.above = Array(picks[..<at])
        }
        return standing
    }

    /// Where among these picks, which hold none of it, it stands: the place after the nearest of those above it.
    func standing(among picks: [ListPick]) -> Int {
        above.last(where: picks.contains).flatMap(picks.firstIndex(of:)).map { $0 + 1 } ?? 0
    }

    public static func == (lhs: Selection, rhs: Selection) -> Bool {
        lhs.pick == rhs.pick && lhs.session == rhs.session
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pick)
        hasher.combine(session)
    }

    private enum CodingKeys: String, CodingKey {
        case pick, session
    }
}

/// What Parked's list narrows to: every item, a project's, or a session's.
public enum ParkedScope: Hashable, Codable, Sendable {
    case all
    case project(String)
    case session(String)
}

/// What the sidebar shows picked: a place, or a project.
public enum Root: Hashable, Codable, Sendable {
    case place(Place)
    case project(String)
}

/// Where the window is: a place, with its list and what the list has picked, Parked's narrowed to a scope, which means
/// nothing on another place and falls away there (`kept(on:)`); a project's page; or a session's page, pushed from a
/// place or a project, which stays picked in the sidebar.
public enum Location: Hashable, Codable, Sendable {
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

    /// What Parked's list is narrowed to; all on any other place and on a page that fills the window.
    public var scope: ParkedScope {
        if case let .place(place, _, scope) = self {
            return scope.on(place)
        }
        return .all
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
            return .place(place, picked: selection, scope: scope.on(place))
        }
        return self
    }

    /// Its selection standing where the list, as it now shows, has its pick.
    public func standing(in list: PlaceList) -> Location {
        picking(picked?.standing(in: list))
    }

    /// Where a click on this row of the sidebar goes: nowhere, where it is the place the window is on, Parked
    /// narrowed to nothing, or the project whose page shows, so the pick stays and no step is made, as Mail does for
    /// the mailbox already open; else the place, nothing picked and Parked narrowed to nothing, or the project's page.
    public func clicking(_ root: Root) -> Location? {
        switch (self, root) {
        case let (.place(place, _, scope), .place(clicked)) where place == clicked && scope.on(place) == .all: nil
        case let (.project(key), .project(clicked)) where key == clicked: nil
        default: root.location
        }
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
    /// leaves its list:
    /// - a snoozed ask picked and woken is picked as the line it is again, in Needs you; a line picked and snoozed
    ///   stays picked as it was, gone from the list as an answered one is;
    /// - a selection whose session left the board drops, as does a scope whose project or session did, and a scope
    ///   on a place other than Parked;
    /// - a session's page whose session left gives way to where it was pushed from;
    /// - none where the project left: the window opens afresh (`opening(on:remembered:)`).
    ///
    /// With no board heard, as before `watch` prints its first line or with no `watch` to run, nothing has left it:
    /// the location stays.
    public func kept(on listed: Listed) -> Location? {
        guard listed.hasBoard else {
            return self
        }

        switch self {
        case let .place(place, picked, scope):
            let picked = picked.flatMap { listed.has($0.session) ? $0.waking(on: listed) : nil }

            return .place(place, picked: picked, scope: scope.on(place).kept(on: listed))
        case let .project(key):
            return listed.projects.contains { $0.id == key } ? self : nil
        case let .session(id, root):
            return listed.has(id) ? self : root.location.kept(on: listed)
        }
    }

    /// Where the window opens on this board: Needs you, its first line as shown picked, in the list given, as it
    /// shows, else as `watch` orders it; with none, where it was left, as it stands on the board now, a pick its list
    /// no longer lists dropped, as the list it stood in is gone; else Needs you, nothing picked. With no board heard
    /// yet, where it was left, as it was, until the first board comes (`History.keep(on:arranged:)`).
    public static func opening(on listed: Listed, remembered: Location?, needsYou shown: PlaceList? = nil) -> Location {
        guard listed.hasBoard else {
            return remembered ?? .place(.needsYou)
        }

        let needsYou = shown ?? PlaceList(.needsYou, in: listed)

        if let first = needsYou.rows.first {
            return .place(.needsYou, picked: needsYou.selection(of: first.pick))
        }
        return remembered?.kept(on: listed)?.listing(on: listed) ?? .place(.needsYou)
    }

    /// Where an open of a session from outside the window lands, as "Open in SitRep" on its card or the menu: Needs
    /// you, its newest line picked, where it needs Lee, by the lines' times and not by core's order of them; else Your
    /// turn or Working, its row picked, under "N earlier" as it may be (`PlaceList.folds(_:)`); else, its only lines asleep or none, its session's page pushed over its
    /// project's, which `History.land(_:)` makes two steps, so Back goes to the project's page.
    public static func opening(session id: String, on listed: Listed) -> Landing {
        guard listed.hasBoard else {
            return .awaitingBoard
        }
        guard let project = listed.homes[id] else {
            return .notOnTheBoard
        }

        let row = listed.rows.first { $0.session == id && $0.section != .snoozed }
        guard let row, let place = Place.allCases.first(where: { $0.section == row.section }),
              let newest = row.lines.max(by: { $0.isOlder(than: $1) })
        else {
            return .location(.session(id, from: .project(project)))
        }

        let pick: ListPick = place == .needsYou ? .line(newest.id) : .session(id)

        return .location(.place(place, picked: PlaceList(place, in: listed, isFoldOpen: true).selection(of: pick)))
    }

    /// A place with its pick dropped where its list, folds open and Parked's narrowed to its scope, lists no row for it.
    private func listing(on listed: Listed) -> Location {
        guard case let .place(place, picked?, scope) = self else {
            return self
        }

        let list = PlaceList(place, in: listed, isFoldOpen: true, scope: scope)

        return .place(place, picked: list.selection(of: picked.pick), scope: scope)
    }
}

/// Where an open of a session from outside the window lands.
public enum Landing: Equatable, Sendable {
    case location(Location)
    /// No board heard yet, so nothing says where the session is: it lands once one is.
    case awaitingBoard
    /// The board has no such session.
    case notOnTheBoard
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

private extension Selection {
    /// A snoozed ask picked, picked as its line in Needs you where it is woken there: core gives an ask the same key
    /// in both. Else as it is.
    func waking(on listed: Listed) -> Selection {
        guard case let .snoozed(key) = pick, listed.needsYou.contains(where: { $0.lines.contains { $0.id == key } })
        else {
            return self
        }
        return Selection(pick: .line(key), session: session)
    }
}

private extension Listed.Line {
    /// Older than the other, or as old and after it by key, as Needs you orders its lines newest first.
    func isOlder(than other: Listed.Line) -> Bool {
        (since, other.id) < (other.since, id)
    }
}

private extension ParkedScope {
    /// As it is on this place: itself on Parked, all on any other, where a scope means nothing.
    func on(_ place: Place) -> ParkedScope {
        place == .parked ? self : .all
    }

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
