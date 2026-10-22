import SitRepWindow
import SwiftUI

/// The sidebar's one list (`Sidebar`), whose selection is the row picked, a session's or a project's, drawn by the
/// system, which the pointer and the arrow keys move alike, and which never empties. Each session shows once, so its
/// row is the pick's: one that changes section keeps its selection, its row's tag the same. A session with no row of
/// its own stands at its project's row, which the list selects. ↓ and ↑ from a pick a fold hides, which the list
/// selects no row for, go to the row after the line it is folded under, or before it, and nowhere past the ends. The
/// row picked is scrolled into view whenever the row showing the pick or the order changes: a pick made elsewhere, by
/// a jump, a notification or the menu, a resort or a fold. Drawn as a still, its lines one under another, as the list
/// sets them.
///
/// The system's list sets its first row 10 under its top, so it starts 10 higher, over the accessory's last 10, for
/// its first heading's row to start at the accessory's foot, its words 10 under it as every heading's are. Scrolled,
/// its rows pass under those 10, where the drawing clips them: a mask that would clip them there takes the list's own
/// 10 away (measured offscreen).
struct BoardList: View {
    let sidebar: Sidebar
    let pick: Pick?
    let filter: Filter
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill
    /// The row picked as the list holds it: the pick, put back whenever the list lets go of it, as a click in its blank
    /// space or on the row picked does, so its selection never empties while something on it is picked.
    @State private var selection: Pick?

    var body: some View {
        if isStill {
            VStack(alignment: .leading, spacing: 0) { lines }
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { scroller in
            List(selection: $selection) { lines }
                .sidebarList()
                .padding(.top, -WindowStyle.listInset)
                // The list's own bottom inset, 10, and 2 more: its content margins it ignores (measured offscreen).
                .safeAreaPadding(.bottom, WindowStyle.listBottom - WindowStyle.listInset)
                // keyed on the rows' order alone, so a resort slides them and a fold changes the list at once
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: sidebar.order)
                .onHover { act.pointer($0) }
                .onKeyPress(keys: [.downArrow, .upArrow], action: stepFromHidden)
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = listed
                        return
                    }
                    if selected != listed {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: listed, initial: true) {
                    selection = listed
                    reveal(in: scroller)
                }
                .onChange(of: shown) { reveal(in: scroller) }
        }
    }

    private var lines: some View {
        let ruled = sidebar.ruled

        return ForEach(sidebar.lines) { line in
            SidebarLine(line: line, isRuled: line.id == ruled, pick: listed, filter: filter, now: now)
                .id(line.id)
        }
    }

    /// The pick as the list's selection holds it, the row showing it (`Sidebar.row(showing:)`): a session's, or a
    /// project's, a session with no row of its own standing at its project's; Settings, at the foot, is none of its
    /// rows.
    private var listed: Pick? {
        sidebar.row(showing: pick)
    }

    /// The lines as they show, which moves the row picked when the list resorts or folds.
    private var shown: [Sidebar.Line.ID] {
        sidebar.lines.map(\.id)
    }

    /// ↓ or ↑, bare, where the list holds no selection on the pick, as a fold hides it: to the row after the line it is
    /// folded under, or before it, or, with none, nowhere, so the list picks no row of its own. From a row the list
    /// selects, and with a modifier held, the keys are the list's own.
    private func stepFromHidden(_ press: KeyPress) -> KeyPress.Result {
        // An arrow comes with the numeric pad and function flags set (measured offscreen), so bare is none of these.
        guard press.modifiers.isDisjoint(with: [.command, .option, .control, .shift]) else {
            return .ignored
        }

        switch sidebar.step(from: pick, down: press.key == .downArrow) {
        case .listsOwn:
            return .ignored
        case .stays:
            return .handled
        case let .to(next):
            act.pickInList(next)
            return .handled
        }
    }

    /// The row picked scrolled into view, only as far as it needs.
    private func reveal(in scroller: ScrollViewProxy) {
        if let listed {
            scroller.scrollTo(Sidebar.Line.ID.pick(listed))
        }
    }
}
