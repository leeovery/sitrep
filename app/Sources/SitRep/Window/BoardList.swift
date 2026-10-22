import SitRepWindow
import SwiftUI

/// The sidebar's one list (`Sidebar`), whose selection is the row picked, a session's or a project's, drawn by the
/// system, which the pointer and the arrow keys move alike, and which never empties. Each session shows once, so its
/// row is the pick's: one that changes section keeps its selection, its row's tag the same. A session with no row of
/// its own stands at its project's row, drawn picked by SitRep as the system would, the list holding no selection,
/// so a click on that row picks the project. ↓ and ↑ from a pick the list holds no selection on go to the row after
/// the line it stands at, or before it, and nowhere past the ends: a fold's heading or "N earlier", for one a fold
/// hides; its project's row, or Projects' heading folded, for a session with no row. The row showing the pick is
/// scrolled into view whenever it or the order changes: a pick made elsewhere, by a jump, a notification or the menu,
/// a resort or a fold. Drawn as a still, its lines one under another, as the list sets them.
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
    @Environment(\.controlActiveState) private var activeState
    /// The row picked as the list holds it (`Sidebar.selection(for:)`), put back whenever the list lets go of it, as a
    /// click in its blank space or on the row picked does, so its selection never empties while a row of it is picked.
    @State private var selection: Pick?
    @FocusState private var isFocused: Bool

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
                .focused($isFocused)
                .sidebarList()
                .padding(.top, -WindowStyle.listInset)
                // The list's own bottom inset, 10, and 2 more: its content margins it ignores (measured offscreen).
                .safeAreaPadding(.bottom, WindowStyle.listBottom - WindowStyle.listInset)
                // keyed on the rows' order alone, so a resort slides them and a fold changes the list at once
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: sidebar.order)
                .onHover { act.pointer($0) }
                .onKeyPress(keys: [.downArrow, .upArrow], action: stepFromUnselected)
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = selectable
                        return
                    }
                    if selected != pick {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: selectable, initial: true) { selection = selectable }
                .onChange(of: showing, initial: true) { reveal(in: scroller) }
                .onChange(of: shown) { reveal(in: scroller) }
        }
    }

    private var lines: some View {
        let ruled = sidebar.ruled

        return ForEach(sidebar.lines) { line in
            SidebarLine(line: line, isRuled: line.id == ruled, picked: picked, filter: filter, now: now)
                .id(line.id)
        }
    }

    /// The pick as the list's selection holds it: a session's row or a project's; none for a session a project's row
    /// stands in for, nor for Settings, at the foot.
    private var selectable: Pick? {
        sidebar.selection(for: pick)
    }

    /// The row showing the pick (`Sidebar.row(showing:)`).
    private var showing: Pick? {
        sidebar.row(showing: pick)
    }

    /// The row showing the pick, drawn picked: by the list's selection, or standing in, by SitRep, in the accent while
    /// the list has focus in the key window.
    private var picked: PickedRow? {
        showing.map { row in
            row == selectable ? .selected(row) : .standIn(row, isEmphasized: isFocused && activeState == .key)
        }
    }

    /// The lines as they show, which moves the row picked when the list resorts or folds.
    private var shown: [Sidebar.Line.ID] {
        sidebar.lines.map(\.id)
    }

    /// ↓ or ↑, bare, where the list holds no selection on the pick, as a fold hides it or a project's row stands in
    /// for it: to the row after the line it stands at, or before it, or, with none, nowhere, so the list picks no row
    /// of its own. From a row the list selects, and with a modifier held, the keys are the list's own.
    private func stepFromUnselected(_ press: KeyPress) -> KeyPress.Result {
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

    /// The row showing the pick scrolled into view, only as far as it needs.
    private func reveal(in scroller: ScrollViewProxy) {
        if let showing {
            scroller.scrollTo(Sidebar.Line.ID.pick(showing))
        }
    }
}
