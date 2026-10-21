import SitRepWindow
import SwiftUI

/// The sidebar's one list (`Sidebar`), whose selection is the row picked, of a session's two while it has an ask, drawn
/// by the system, which the pointer and the arrow keys move alike, and which never empties. ↓ and ↑ from a heading
/// showing its project's page, which the list selects no row for, go to the row after it or before it, as from a
/// row folded under a heading, and nowhere past the ends. The row picked
/// is scrolled into view whenever the pick or the order changes: a pick made elsewhere, by a jump, a notification or
/// the menu, a resort or a fold. Drawn as a still, its lines one under another, as the list sets them.
///
/// The system's list sets its first row 10 under its top, so it starts 10 higher, over the accessory's last 10, for
/// its first heading to sit 2 under the accessory as drawn. Scrolled, its rows pass under those 10, where the drawing
/// clips them: a mask that would clip them there takes the list's own 10 away (measured offscreen).
struct BoardList: View {
    let sidebar: Sidebar
    let spot: Spot?
    let filter: Filter
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill
    @Environment(\.controlActiveState) private var activeState
    /// The row picked as the list holds it: the spot, put back whenever the list lets go of it, as a click in its
    /// blank space or on the row picked does, so its selection never empties while something on it is picked.
    @State private var selection: Spot?
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
                .sidebarList()
                .focused($isFocused)
                .padding(.top, -WindowStyle.listInset)
                .safeAreaPadding(.bottom, WindowStyle.listBottom - WindowStyle.listInset)
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: order)
                .onHover { act.pointer($0) }
                .onKeyPress(keys: [.downArrow, .upArrow], action: stepFromHeading)
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = spot
                        return
                    }
                    if selected != spot {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: spot, initial: true) { _, spot in
                    selection = spot
                    reveal(spot, in: scroller)
                }
                .onChange(of: order) { reveal(spot, in: scroller) }
        }
    }

    private var lines: some View {
        ForEach(Array(sidebar.lines.enumerated()), id: \.element.id) { place, line in
            SidebarLine(
                line: line, isFirst: place == 0, spot: spot, isEmphasized: isFocused && activeState == .key,
                filter: filter, now: now
            )
            .id(line.id)
        }
    }

    /// The lines in the order they show, which moves the row picked when the list resorts or folds.
    private var order: [Sidebar.Line.ID] {
        sidebar.lines.map(\.id)
    }

    /// ↓ or ↑, bare, where the list holds no selection on the pick, a heading showing it or a fold hiding it: to the
    /// row after the heading, or before it, or, with none, nowhere, so the list picks no row of its own. From a row the
    /// list selects, and with a modifier held, the keys are the list's own.
    private func stepFromHeading(_ press: KeyPress) -> KeyPress.Result {
        // An arrow comes with the numeric pad and function flags set (measured offscreen), so bare is none of these.
        guard press.modifiers.isDisjoint(with: [.command, .option, .control, .shift]) else {
            return .ignored
        }

        switch sidebar.step(from: spot, down: press.key == .downArrow) {
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
    private func reveal(_ spot: Spot?, in scroller: ScrollViewProxy) {
        if let spot {
            scroller.scrollTo(Sidebar.Line.ID.spot(spot))
        }
    }
}
