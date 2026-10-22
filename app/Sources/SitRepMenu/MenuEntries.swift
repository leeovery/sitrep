import SitRepCore
import SitRepPanel

/// One item of the menu, as data: what it shows, keyed by what it is, so an open menu is patched in place, each item
/// kept by its key, rather than built again under the pointer.
public enum MenuEntry: Equatable, Sendable {
    /// SitRep's icon, name and version.
    case header
    case separator(String)
    /// The trouble SitRep met seeing to its plugin, and what to do.
    case trouble(PluginTrouble)
    case heading(String, title: String)
    case reload(MenuBoard.Reload)
    /// "SitRep can't read the board", and why.
    case unread(why: String)
    /// A session's row, and the session a click jumps to; nil for an away one, disabled.
    case row(Session, jump: String?)
    /// "4 more…", opening the SitRep window.
    case more(String)
    case openWindow
    case show(EdgeSettings.Show, isTicked: Bool)
    case settings
    case quit

    /// What the item is, the same for as long as it shows.
    public var key: String {
        switch self {
        case .header: "header"
        case let .separator(id): "separator:\(id)"
        case let .heading(id, _): "heading:\(id)"
        case let .reload(reload): "reload:\(reload.id)"
        case .trouble: "trouble"
        case .unread: "unread"
        case let .row(session, _): "row:\(session.id)"
        case .more: "more"
        case .openWindow: "openWindow"
        case let .show(show, _): "show:\(show.rawValue)"
        case .settings: "settings"
        case .quit: "quit"
        }
    }
}

extension MenuBoard {
    /// The whole menu, top to bottom, with this shown at the edge: the header; what it speaks up with; the sessions
    /// under their heading, the hairline among them and "N more…" past twelve; the SitRep window; Show; Settings and
    /// Quit.
    public func entries(showing shown: EdgeSettings.Show) -> [MenuEntry] {
        let commands: [MenuEntry] = [.openWindow, .separator("window"), .heading("show", title: "Show")]
            + EdgeSettings.Show.allCases.map { .show($0, isTicked: $0 == shown) }
            + [.separator("show"), .settings, .separator("settings"), .quit]

        return [.header, .separator("header")] + speakingUp + sessionEntries + commands
    }

    private var speakingUp: [MenuEntry] {
        let reloads: [MenuEntry] = self.reloads.isEmpty ? [] :
            [.heading("reloads", title: Self.reloadTitle)] + self.reloads.map(MenuEntry.reload) + [.separator("reloads")]
        let trouble: [MenuEntry] = trouble.map { [.trouble($0), .separator("trouble")] } ?? []
        let unread: [MenuEntry] = unread.map { [.unread(why: $0), .separator("unread")] } ?? []

        return trouble + reloads + unread
    }

    private var sessionEntries: [MenuEntry] {
        guard let heading else {
            return []
        }

        let rows = items.map { item in item.session.map { MenuEntry.row($0, jump: jump($0)) } ?? .separator("hairline") }
        let more = moreTitle.map { [MenuEntry.more($0)] } ?? []

        return [.heading("sessions", title: heading)] + rows + more + [.separator("sessions")]
    }

    /// When on the wall clock, ms, a row's time or a wake's countdown next reads differently, for an open menu; nil with
    /// no rows.
    public func nextTick(after now: Double) -> Double? {
        items.compactMap(\.session).map { $0.changes(after: now) }.min()
    }
}

/// What changed between the menu as it shows and as it should: the items to take out, those to put in, and those to
/// set again in place, so the item under the pointer stays where it is, highlighted.
public struct MenuChanges: Equatable, Sendable {
    /// An entry at its offset in the new menu.
    public struct Placed: Equatable, Sendable {
        public let offset: Int
        public let entry: MenuEntry

        public init(_ offset: Int, _ entry: MenuEntry) {
            self.offset = offset
            self.entry = entry
        }
    }

    /// Offsets in the old menu of the items gone, the last first, so each removal leaves those before it in place.
    public let removals: [Int]
    /// The items come, the first first, each at its offset once the removals are made.
    public let insertions: [Placed]
    /// The items kept whose words, marks or jumps changed, at their offsets once the insertions are made.
    public let changes: [Placed]

    public init(from old: [MenuEntry], to new: [MenuEntry]) {
        let difference = new.map(\.key).difference(from: old.map(\.key))
        var removals: [Int] = [], insertions: [Placed] = []

        for change in difference {
            switch change {
            case let .remove(offset, _, _): removals.append(offset)
            case let .insert(offset, _, _): insertions.append(Placed(offset, new[offset]))
            }
        }

        let was = Dictionary(old.map { ($0.key, $0) }) { first, _ in first }
        let inserted = Set(insertions.map(\.offset))

        self.removals = removals.sorted(by: >)
        self.insertions = insertions.sorted { $0.offset < $1.offset }
        changes = new.enumerated().compactMap { offset, entry in
            !inserted.contains(offset) && was[entry.key].map { $0 != entry } == true ? Placed(offset, entry) : nil
        }
    }

    public var isEmpty: Bool { removals.isEmpty && insertions.isEmpty && changes.isEmpty }
}

/// A row's first line as the menu sets it (`Session.headline`): its words in the menu's font, a plain subject or a
/// wake's countdown among them, its subject in mono after them, and a "+2"; a working row's, or one on its own work,
/// fainter than the rest, since it needs nothing.
public struct MenuTitle: Equatable, Sendable {
    public let words: String
    public let mono: String?
    public let more: String?
    public let isFaint: Bool

    public init(words: String, mono: String?, more: String?, isFaint: Bool) {
        self.words = words
        self.mono = mono
        self.more = more
        self.isFaint = isFaint
    }
}

extension Session {
    /// Its first line as the menu sets it at this time on the wall clock, ms.
    public func menuLine(at now: Double) -> MenuTitle {
        MenuTitle(
            words: title + (subject(at: now) ?? ""), mono: code, more: more.map { " \($0)" },
            isFaint: kind == .working || kind == .onItsWork
        )
    }
}
