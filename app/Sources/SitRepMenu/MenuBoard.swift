import Foundation
import SitRepCore
import SitRepEdge
import SitRepPanel

/// What the menu shows of the board `watch` last printed (DESIGN, "The menu bar item"): first what it speaks up with,
/// then the panel's sessions in its order with its marks, every one of them, and the glyph. Core and the panel
/// decided the rows and their order; this decides only what the menu makes of them.
public struct MenuBoard: Equatable, Sendable {
    /// Windows on an old sitrep, each a jump to the window to run `/reload-plugins` in, under "Needs /reload-plugins".
    public let reloads: [Reload]
    /// The trouble SitRep met seeing to its plugin, which it speaks up with first; nil with none.
    public let trouble: PluginTrouble?
    /// Why the board is not current, for "SitRep can't read the board"; nil while it is.
    public let unread: String?
    /// The sessions' heading, in the panel head's words, with when the board was last current while it is stale:
    /// "4 need you · as of 12:04". Nil with no board to list, while the menu speaks up instead.
    public let heading: String?
    /// The sessions, with the panel's hairline under Needs you, which leads them.
    public let items: [Item]
    public let glyph: Glyph
    private let panel: PanelBoard

    /// The menu bar's glyph: the light in its housing, lit as the notch's light is, orange while an ask waits, else
    /// blue while Lee's turn does, the board's last word kept while it is stale.
    public enum Glyph: Equatable, Sendable {
        case rest, lit, turn
    }

    /// A window that needs `/reload-plugins`: its session's project and name, and the session a click jumps to.
    public struct Reload: Equatable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let session: String

        init(_ window: Board.Window) {
            id = window.writer
            label = "\(window.project) · \(window.name)"
            session = window.session
        }

        /// The windows of the board that run an old sitrep (`WindowsBehind`).
        static func windows(of board: Board?) -> [Reload] {
            WindowsBehind(board).windows.map(Reload.init)
        }
    }

    public static let unreadTitle = "SitRep can't read the board"
    public static let reloadTitle = "Needs /reload-plugins"
    /// The command that opens the welcome window at its first step: it opens a window and asks nothing, so it has no
    /// ellipsis.
    public static let welcomeTitle = "Show Welcome Window"

    /// The board as last heard, the sessions a window holds that this Mac does not show drawn as away ones are, and
    /// any trouble with the plugin.
    public init(
        _ last: LastBoard, trouble: PluginTrouble? = nil, notHere: Set<String> = [],
        clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)
    ) {
        let panel = PanelBoard(last, notHere: notHere, clock: clock)
        let heading: String? = switch (last.board, last.stale) {
        case (nil, nil): panel.head.title
        case (nil, _): nil
        default: panel.asOf.map { "\(panel.head.title) · \($0)" } ?? panel.head.title
        }

        self.init(
            panel, trouble: trouble, reloads: Reload.windows(of: last.board), unread: last.stale?.description, heading: heading
        )
    }

    /// With no plugin to run, it speaks up with the trouble that left it none.
    public init(unrun trouble: PluginTrouble) {
        self.init(PanelBoard(unrun: trouble.line), trouble: trouble, reloads: [], unread: nil, heading: nil)
    }

    private init(_ panel: PanelBoard, trouble: PluginTrouble?, reloads: [Reload], unread: String?, heading: String?) {
        self.panel = panel
        self.trouble = trouble
        self.reloads = reloads
        self.unread = unread
        self.heading = heading
        items = Item.list(panel.sessions)
        glyph = switch panel.need {
        case .ask: .lit
        case .turn: .turn
        case nil: .rest
        }
    }

}

extension Session {
    /// The row's first line as one line of a menu item's title at this time on the wall clock, ms: its words, its
    /// subject after them, and its count.
    public func menuTitle(at now: Double) -> String {
        menuLine(at: now).plain
    }
}
