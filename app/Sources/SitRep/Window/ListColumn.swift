import SitRepPanel
import SitRepWindow
import SwiftUI

/// The list beside the page, in the window's content list, 300 wide on the page's black, as A1 revised draws it: the
/// place's rows (`PlaceList`), Needs you a row per line, then its fold. With nothing listed, one line says why: that the
/// filter keeps nothing, or, on Needs you, how the board stands. Parked's items sit under their projects' headings.
struct ListColumn: View {
    let list: PlaceList
    /// The row the list picked, which it shows picked while it lists it.
    let picked: ListPick?
    let head: Head
    let filter: Filter
    let now: Date

    @Environment(\.isStill) private var isStill
    @Environment(\.windowActions) private var act

    var body: some View {
        Group {
            if let note {
                ListNote(words: note)
            } else if isStill {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: WindowStyle.barHeight)
                    PlaceListRows(list: list, picked: picked, filter: filter, now: now)
                    Spacer(minLength: 0)
                }
            } else {
                PlaceListView(list: list, picked: picked, filter: filter, now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WindowStyle.black.ignoresSafeArea())
        // on the column, not the list, so the pointer leaving is heard as the list empties to its one line under it
        .onHover { act.pointer(.list, $0) }
    }

    /// The one line in the list's place where it lists nothing.
    private var note: String? {
        guard list.isEmpty else {
            return nil
        }
        if !filter.isEmpty {
            return Words.noMatch(filter, on: list.place)
        }
        return list.place == .needsYou ? head.title : nil
    }
}

/// A place's list as a list with a selection, in the sidebar's style, whose selection is the row picked, drawn by the
/// system, and which never empties while a row of it is picked. A click picks a row as a step replacing the last; ↓
/// and ↑, bare, step through the rows as the window's run says (`WindowRun.step(down:at:)`), from where the pick stood
/// where the list no longer shows it, and nowhere past either end; with a modifier held they are the list's own. The
/// row picked is scrolled into view whenever it or the order changes, only as far as it needs. The pointer over its
/// column holds its order (`ListColumn`).
private struct PlaceListView: View {
    let list: PlaceList
    let picked: ListPick?
    let filter: Filter
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    /// The row picked as the list holds it, put back whenever the list lets go of it, as a click in its blank space
    /// or on the row picked does.
    @State private var selection: ListPick?

    var body: some View {
        ScrollViewReader { scroller in
            List(selection: $selection) {
                PlaceListRows(list: list, picked: picked, filter: filter, now: now)
            }
            .sidebarList()
            .scrollContentBackground(.hidden)
            // keyed on the rows' order alone, so a resort slides them and a fold changes the list at once
            .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: order)
            .onKeyPress(keys: [.downArrow, .upArrow], action: step)
            .onChange(of: selection) { _, selected in
                guard let selected else {
                    selection = shown
                    return
                }
                // a row a board has just dropped picks nothing: the selection goes back to the page's
                if selected != shown, !act.pickInList(selected) {
                    selection = shown
                }
            }
            .onChange(of: shown, initial: true) {
                selection = shown
                reveal(in: scroller)
            }
            .onChange(of: order) { reveal(in: scroller) }
        }
    }

    /// The pick, while the list shows its row.
    private var shown: ListPick? {
        list.row(picked)?.pick
    }

    private var order: [PlaceList.Item.ID] {
        list.items.map(\.id)
    }

    /// ↓ or ↑, bare: the run's step, so the list moves no selection of its own.
    private func step(_ press: KeyPress) -> KeyPress.Result {
        // An arrow comes with the numeric pad and function flags set (measured offscreen), so bare is none of these.
        guard press.modifiers.isDisjoint(with: [.command, .option, .control, .shift]) else {
            return .ignored
        }

        act.step(press.key == .downArrow)
        return .handled
    }

    /// The row picked scrolled into view, only as far as it needs.
    private func reveal(in scroller: ScrollViewProxy) {
        if let shown {
            scroller.scrollTo(PlaceList.Item.ID.pick(shown))
        }
    }
}

/// A place's list, item by item, each by its id.
private struct PlaceListRows: View {
    let list: PlaceList
    let picked: ListPick?
    let filter: Filter
    let now: Date

    var body: some View {
        let items = list.items

        ForEach(items) { item in
            ListLine(
                item: item, place: list.place, picked: picked, filter: filter, now: now, isFirst: item.id == items.first?.id
            )
            .id(item.id)
        }
    }
}
