import SitRepCore

/// The Claude Code windows that run an older sitrep than the CLI's, or say none, and need `/reload-plugins`: the one
/// reading of them that the menu's Needs /reload-plugins, Settings' plugin row, its Claude Code pane and that pane's
/// count in the sidebar all share. The longest attached first, as `watch` lists them; none before any board.
public struct WindowsBehind: Equatable, Sendable {
    public let windows: [Board.Window]

    public init(_ board: Board?) {
        windows = (board?.windows ?? []).filter(\.needsReload)
    }

    public var count: Int { windows.count }
    public var isEmpty: Bool { windows.isEmpty }
}
